import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThanOrEqual, LessThanOrEqual, Between } from 'typeorm';
import { FamilyTask, TaskFrequency, TaskStatus } from './entities/family-task.entity';
import { TaskCompletion } from './entities/task-completion.entity';
import { CreateFamilyTaskDto, UpdateFamilyTaskDto, CompleteTaskDto } from './dto/family-task.dto';

@Injectable()
export class FamilyTaskService {
  constructor(
    @InjectRepository(FamilyTask) private taskRepo: Repository<FamilyTask>,
    @InjectRepository(TaskCompletion) private completionRepo: Repository<TaskCompletion>,
  ) {}

  /** 按家庭查询所有任务 */
  async findByFamily(familyId: string) {
    return this.taskRepo.find({
      where: { familyId },
      relations: ['assignee', 'recipient', 'createdBy'],
      order: { nextDueAt: 'ASC', createdAt: 'DESC' },
    });
  }

  /** 即将到期的任务（未来7天） */
  async findUpcoming(familyId: string) {
    const now = new Date();
    const future = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

    return this.taskRepo.find({
      where: {
        familyId,
        status: TaskStatus.PENDING,
        nextDueAt: LessThanOrEqual(future),
      },
      relations: ['assignee', 'recipient', 'createdBy'],
      order: { nextDueAt: 'ASC' },
    });
  }

  /** 按月查询 */
  async findByMonth(familyId: string, year: number, month: number) {
    const startDate = new Date(year, month - 1, 1);
    const endDate = new Date(year, month, 0, 23, 59, 59);

    const tasks = await this.taskRepo.find({
      where: {
        familyId,
        nextDueAt: LessThanOrEqual(endDate),
      },
      relations: ['assignee', 'recipient', 'createdBy'],
      order: { nextDueAt: 'ASC' },
    });

    // 展开 recurring 任务
    const result: any[] = [];

    for (const task of tasks) {
      if (task.frequency === TaskFrequency.ONCE) {
        if (task.nextDueAt >= startDate) {
          result.push(task);
        }
      } else {
        // 展开周期任务到当月
        const expanded = this.expandRecurringTask(task, year, month, startDate, endDate);
        result.push(...expanded);
      }
    }

    return result;
  }

  /** 展开周期任务到月视图 */
  private expandRecurringTask(
    task: FamilyTask,
    year: number,
    month: number,
    startDate: Date,
    endDate: Date,
  ): FamilyTask[] {
    const results: FamilyTask[] = [];
    const daysInMonth = new Date(year, month, 0).getDate();
    const scheduleDays = task.scheduledDay || [];

    for (let day = 1; day <= daysInMonth; day++) {
      const date = new Date(year, month - 1, day);
      const dow = date.getDay() === 0 ? 7 : date.getDay(); // 1=周一

      let matches = false;
      if (task.frequency === TaskFrequency.DAILY) {
        matches = true;
      } else if (task.frequency === TaskFrequency.WEEKLY) {
        matches = scheduleDays.includes(dow);
      } else if (task.frequency === TaskFrequency.MONTHLY) {
        matches = scheduleDays.includes(day);
      }

      if (matches && date >= startDate && date <= endDate) {
        const instance = { ...task } as FamilyTask;
        // 设置为当天的具体时间
        if (task.scheduledTime) {
          const [h, m] = task.scheduledTime.split(':');
          instance.nextDueAt = new Date(year, month - 1, day, parseInt(h), parseInt(m));
        } else {
          instance.nextDueAt = date;
        }
        results.push(instance);
      }
    }

    return results;
  }

  /** 创建任务 */
  async create(dto: CreateFamilyTaskDto, userId: string) {
    // 计算 nextDueAt
    let nextDueAt = new Date();
    if (dto.scheduledTime) {
      const [h, m] = dto.scheduledTime.split(':');
      nextDueAt = new Date();
      nextDueAt.setHours(parseInt(h), parseInt(m), 0, 0);
    }

    const task = this.taskRepo.create({
      ...dto,
      nextDueAt,
      createdById: userId,
      status: TaskStatus.PENDING,
    });

    return this.taskRepo.save(task);
  }

  /** 更新任务 */
  async update(id: string, familyId: string, dto: UpdateFamilyTaskDto) {
    const task = await this.taskRepo.findOne({ where: { id } });
    if (!task) throw new NotFoundException('任务不存在');
    if (task.familyId !== familyId) throw new ForbiddenException('无权修改此任务');

    Object.assign(task, dto);
    return this.taskRepo.save(task);
  }

  /** 完成 */
  async complete(id: string, userId: string, dto: CompleteTaskDto, familyId: string) {
    const task = await this.taskRepo.findOne({ where: { id } });
    if (!task) throw new NotFoundException('任务不存在');
    if (task.familyId !== familyId) throw new ForbiddenException('无权操作此任务');

    // 记录完成
    const completion = this.completionRepo.create({
      taskId: id,
      completedById: userId,
      note: dto.note,
    });
    await this.completionRepo.save(completion);

    // 如果是周期任务，计算下次到期时间
    if (task.frequency !== TaskFrequency.ONCE) {
      task.nextDueAt = this.calculateNextDue(task);
      await this.taskRepo.save(task);
    } else {
      task.status = TaskStatus.COMPLETED;
      await this.taskRepo.save(task);
    }

    return task;
  }

  /** 计算下次到期时间 */
  private calculateNextDue(task: FamilyTask): Date {
    const now = new Date();
    const next = new Date(now);

    if (task.frequency === TaskFrequency.DAILY) {
      next.setDate(next.getDate() + 1);
    } else if (task.frequency === TaskFrequency.WEEKLY) {
      const days = task.scheduledDay || [1];
      const currentDow = now.getDay() === 0 ? 7 : now.getDay();
      let daysToAdd = 7;
      for (const d of days.sort((a, b) => a - b)) {
        if (d > currentDow) {
          daysToAdd = d - currentDow;
          break;
        }
      }
      next.setDate(next.getDate() + daysToAdd);
    } else if (task.frequency === TaskFrequency.MONTHLY) {
      const days = task.scheduledDay || [1];
      const nextDay = days.find(d => d > now.getDate()) || days[0];
      next.setMonth(next.getMonth() + 1);
      next.setDate(nextDay);
    }

    if (task.scheduledTime) {
      const [h, m] = task.scheduledTime.split(':');
      next.setHours(parseInt(h), parseInt(m), 0, 0);
    }

    return next;
  }

  /** 删除 */
  async delete(id: string, familyId: string) {
    const task = await this.taskRepo.findOne({ where: { id } });
    if (!task) throw new NotFoundException('任务不存在');
    if (task.familyId !== familyId) throw new ForbiddenException('无权删除此任务');

    return this.taskRepo.softRemove(task);
  }
}
