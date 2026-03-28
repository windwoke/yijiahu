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
    const tasks = await this.taskRepo.find({
      where: { familyId },
      relations: ['assignee', 'assignee.user', 'recipient', 'createdBy'],
      order: { nextDueAt: 'ASC', createdAt: 'DESC' },
    });
    // 附加 assignee 的真实姓名
    return tasks.map((t) => ({
      ...t,
      assignee: t.assignee
        ? { ...t.assignee, userName: (t.assignee as any).user?.name || null }
        : null,
    }));
  }

  /** 即将到期的任务（未来7天，排除今天已完成的周期任务实例） */
  async findUpcoming(familyId: string) {
    const now = new Date();
    const future = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

    // 查询所有 pending 且未来7天到期的任务
    const tasks = await this.taskRepo.find({
      where: {
        familyId,
        status: TaskStatus.PENDING,
        nextDueAt: LessThanOrEqual(future),
      },
      relations: ['assignee', 'assignee.user', 'recipient', 'createdBy'],
      order: { nextDueAt: 'ASC' },
    });

    if (tasks.length === 0) return [];

    // 获取今天的北京时区日期（YYYY-MM-DD）
    const todayStr = this.toLocalDateStr(now);

    // 查询这些任务中今天已完成的记录
    const taskIds = tasks.map(t => t.id);
    const todayCompletions = await this.completionRepo
      .createQueryBuilder('tc')
      .select('tc.taskId', 'taskId')
      .where('tc.taskId IN (:...taskIds)', { taskIds })
      .andWhere('tc.scheduledDate = :today', { today: todayStr })
      .getRawMany();

    const completedTodaySet = new Set(todayCompletions.map(c => c.taskId));

    // 周期任务如果今天已完成，nextDueAt 已在 complete() 时更新为下一个到期，
    // 直接返回即可（不用再调用 calculateNextDue，避免重复推进）
    return tasks
      .filter(task => !completedTodaySet.has(task.id))
      .map((t) => ({
        ...t,
        assignee: t.assignee
          ? { ...t.assignee, userName: (t.assignee as any).user?.name || null }
          : null,
      }));
  }

  /** 将 Date 转换为北京时区 YYYY-MM-DD 字符串 */
  private toLocalDateStr(date: Date): string {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  /** 按月查询（按原始周期频率展开，不依赖 nextDueAt 过滤，因为 nextDueAt 会随完成而推进） */
  async findByMonth(familyId: string, year: number, month: number) {
    const startDate = new Date(year, month - 1, 1);
    const endDate = new Date(year, month, 0, 23, 59, 59);

    // 查询所有非取消状态的任务（取消后不显示在日历中）
    const tasks = await this.taskRepo.find({
      where: { familyId },
      relations: ['assignee', 'assignee.user', 'recipient', 'createdBy'],
      order: { nextDueAt: 'ASC' },
    }).then(ts => ts
      .filter(t => t.status !== TaskStatus.CANCELLED)
      .map((t) => ({
        ...t,
        assignee: t.assignee
          ? { ...t.assignee, userName: (t.assignee as any).user?.name || null }
          : null,
      })) as any[]);

    if (tasks.length === 0) return [];

    // 预加载当月所有任务的完成记录（按scheduledDate精确匹配）
    const taskIds = tasks.map(t => t.id);
    const monthStart = `${year}-${String(month).padStart(2, '0')}-01`;
    const lastDay = new Date(year, month, 0).getDate();
    const monthEnd = `${year}-${String(month).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`;

    const completions = await this.completionRepo
      .createQueryBuilder('tc')
      .where('tc.taskId IN (:...taskIds)', { taskIds })
      .andWhere('tc.scheduledDate >= :start AND tc.scheduledDate <= :end', {
        start: monthStart,
        end: monthEnd,
      })
      .getMany();

    // 建立 taskId -> [scheduledDates] 映射（直接用字符串，精确无歧义）
    const completionMap = new Map<string, Set<string>>();
    for (const c of completions) {
      if (c.scheduledDate) {
        if (!completionMap.has(c.taskId)) completionMap.set(c.taskId, new Set());
        completionMap.get(c.taskId)!.add(c.scheduledDate);
      }
    }

    // 展开 recurring 任务
    const result: any[] = [];

    for (const task of tasks) {
      if (task.frequency === TaskFrequency.ONCE) {
        // 单次任务：nextDueAt 在当月内则显示
        if (task.nextDueAt >= startDate && task.nextDueAt <= endDate) {
          const instance = { ...task } as FamilyTask;
          // 用 completionMap 标记完成状态（完成后 status 变了但我们仍然显示）
          const dateKey = this.toLocalDateStr(task.nextDueAt);
          if (completionMap.get(task.id)?.has(dateKey)) {
            instance.status = TaskStatus.COMPLETED;
          }
          result.push(instance);
        }
      } else {
        const expanded = this.expandRecurringTask(
          task, year, month, startDate, endDate,
          completionMap.get(task.id) ?? new Set(),
        );
        result.push(...expanded);
      }
    }

    return result;
  }

  /** 展开周期任务到月视图（标记已完成的实例） */
  private expandRecurringTask(
    task: FamilyTask,
    year: number,
    month: number,
    startDate: Date,
    endDate: Date,
    completedDates: Set<string>,
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
        // 检查当天是否已完成
        const dateKey = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
        if (completedDates.has(dateKey)) {
          instance.status = TaskStatus.COMPLETED;
        }
        // 设置 nextDueAt：使用 UTC 12:00 避免时区跨越导致日期偏移
        if (task.scheduledTime) {
          const [h, m] = task.scheduledTime.split(':');
          instance.nextDueAt = new Date(Date.UTC(year, month - 1, day, parseInt(h), parseInt(m)));
        } else {
          instance.nextDueAt = new Date(Date.UTC(year, month - 1, day, 12, 0));
        }
        results.push(instance);
      }
    }

    return results;
  }

  /** 获取任务的 assigneeId（用于权限校验） */
  async getAssigneeId(taskId: string): Promise<string | null> {
    const task = await this.taskRepo.findOne({ where: { id: taskId } });
    return task?.assigneeId ?? null;
  }

  /** 创建任务 */
  async create(dto: CreateFamilyTaskDto, userId: string) {
    // 计算 nextDueAt
    let nextDueAt: Date;
    if (dto.scheduledDate) {
      // 单次任务：用户输入的时间是北京时间，转为 UTC 存储
      const [y, m, d] = dto.scheduledDate.split('-').map(Number);
      if (dto.scheduledTime) {
        const [h, min] = dto.scheduledTime.split(':').map(Number);
        // 北京时间 10:00 = UTC 02:00（UTC+8）
        const utcH = (h - 8 + 24) % 24;
        nextDueAt = new Date(Date.UTC(y, m - 1, d, utcH, min));
      } else {
        // 无时间则用 UTC 12:00（北京时间 20:00）
        nextDueAt = new Date(Date.UTC(y, m - 1, d, 12, 0));
      }
    } else {
      // 周期任务
      nextDueAt = new Date();
      if (dto.scheduledTime) {
        const [h, min] = dto.scheduledTime.split(':').map(Number);
        nextDueAt.setHours(h, min, 0, 0);
      } else {
        nextDueAt.setHours(12, 0, 0, 0);
      }
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

    // scheduledDate: 优先用前端传递的日期（来自日历实例的 nextDueAt），否则从任务 nextDueAt 推导
    const scheduledDate = dto.scheduledDate ?? this.toLocalDateStr(task.nextDueAt!);

    // 记录完成（明确标记完成的哪天实例）
    const completion = this.completionRepo.create({
      taskId: id,
      completedById: userId,
      scheduledDate,
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

  /** 计算下次到期时间（无 scheduledTime 时用 UTC 12:00 避免时区日期偏移） */
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
    } else {
      // 无具体时间 → 用 UTC 12:00，跨时区日期不变
      next.setHours(12, 0, 0, 0);
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
