import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Between } from 'typeorm';
import { MedicationLog, MedicationLogStatus } from './entities/medication-log.entity';
import { Medication } from '../medication/entities/medication.entity';
import { CheckInDto } from './dto/medication-log.dto';

@Injectable()
export class MedicationLogService {
  constructor(
    @InjectRepository(MedicationLog) private logRepo: Repository<MedicationLog>,
    @InjectRepository(Medication) private medRepo: Repository<Medication>,
  ) {}

  /** 生成某一天的所有用药日志 */
  async generateDailyLogs(recipientId: string, date: Date) {
    const dateStr = date.toISOString().split('T')[0];

    // 获取该照护对象的所有药品
    const medications = await this.medRepo.find({
      where: { recipientId, isActive: true },
    });

    const logs: MedicationLog[] = [];
    for (const med of medications) {
      for (const time of med.times) {
        // 检查是否已存在
        const existing = await this.logRepo.findOne({
          where: {
            recipientId,
            medicationId: med.id,
            scheduledDate: Between(
              new Date(`${dateStr}T00:00:00Z`),
              new Date(`${dateStr}T23:59:59Z`),
            ),
            scheduledTime: time,
          },
        });

        if (!existing) {
          const log = this.logRepo.create({
            recipientId,
            medicationId: med.id,
            scheduledDate: new Date(`${dateStr}T00:00:00Z`),
            scheduledTime: time,
            status: MedicationLogStatus.PENDING,
          });
          logs.push(await this.logRepo.save(log) as MedicationLog);
        }
      }
    }

    return logs;
  }

  /** 获取今日用药汇总 */
  async getTodaySummary(recipientId: string) {
    const today = new Date();
    const dateStr = today.toISOString().split('T')[0];

    // 先生成今日日志（确保当天记录存在）
    await this.generateDailyLogs(recipientId, today);

    const logs = await this.logRepo.find({
      where: {
        recipientId,
        scheduledDate: Between(
          new Date(`${dateStr}T00:00:00Z`),
          new Date(`${dateStr}T23:59:59Z`),
        ),
      },
      relations: ['medication'],
      order: { scheduledTime: 'ASC' },
    });

    const items = logs.map((log) => ({
      id: log.id,
      medicationName: log.medication?.name || '',
      dosage: log.medication?.dosage || '',
      scheduledTime: log.scheduledTime,
      status: log.status,
      canCheckIn: log.status === MedicationLogStatus.PENDING,
    }));

    const completed = items.filter(
      (i) => i.status === MedicationLogStatus.TAKEN || i.status === MedicationLogStatus.SKIPPED,
    ).length;

    return {
      recipientId,
      date: dateStr,
      total: items.length,
      completed,
      items,
    };
  }

  /** 打卡 */
  async checkIn(logId: string, dto: CheckInDto, userId: string) {
    const log = await this.logRepo.findOne({ where: { id: logId } });
    if (!log) throw new NotFoundException('用药记录不存在');

    log.status = dto.status;
    log.takenAt = new Date();
    log.takenBy = userId;
    if (dto.note) log.note = dto.note;

    return this.logRepo.save(log);
  }

  /** 历史记录 */
  async getHistory(recipientId: string, date: string) {
    return this.logRepo.find({
      where: {
        recipientId,
        scheduledDate: Between(
          new Date(`${date}T00:00:00Z`),
          new Date(`${date}T23:59:59Z`),
        ),
      },
      relations: ['medication'],
      order: { scheduledTime: 'ASC' },
    });
  }

  /** 时间线用药记录（taken/skipped） */
  async getTimeline(recipientId?: string, familyId?: string, days = 7): Promise<any[]> {
    const qb = this.logRepo
      .createQueryBuilder('log')
      .leftJoinAndSelect('log.medication', 'medication')
      .where('log.status IN (:...statuses)', {
        statuses: [MedicationLogStatus.TAKEN, MedicationLogStatus.SKIPPED],
      })
      .andWhere('log.takenAt IS NOT NULL')
      .orderBy('log.takenAt', 'DESC')
      .take(50);

    if (recipientId) {
      qb.andWhere('log.recipientId = :recipientId', { recipientId });
    }

    const logs = await qb.getMany();
    return logs.map((log) => ({
      id: log.id,
      type: 'medication',
      content: `${log.medication?.name || ''} 已${log.status === MedicationLogStatus.TAKEN ? '服用' : '跳过'}${log.medication?.dosage ? ' · ' + log.medication.dosage : ''}`,
      authorName: log.takenBy || '家庭成员',
      authorId: log.takenBy,
      recipientId: log.recipientId,
      time: log.takenAt,
      status: log.status,
    }));
  }
}
