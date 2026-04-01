import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Between } from 'typeorm';
import {
  MedicationLog,
  MedicationLogStatus,
} from './entities/medication-log.entity';
import { Medication } from '../medication/entities/medication.entity';
import { FamilyMember } from '../family/entities/family-member.entity';
import { User } from '../user/entities/user.entity';
import { CareRecipient } from '../care-recipient/entities/care-recipient.entity';
import { CheckInDto } from './dto/medication-log.dto';

@Injectable()
export class MedicationLogService {
  constructor(
    @InjectRepository(MedicationLog) private logRepo: Repository<MedicationLog>,
    @InjectRepository(Medication) private medRepo: Repository<Medication>,
    @InjectRepository(FamilyMember)
    private memberRepo: Repository<FamilyMember>,
    @InjectRepository(User) private userRepo: Repository<User>,
    @InjectRepository(CareRecipient)
    private recipientRepo: Repository<CareRecipient>,
  ) {}

  /** 验证照护对象属于指定家庭 */
  private async validateRecipientInFamily(
    recipientId: string,
    familyId: string,
  ) {
    const recipient = await this.recipientRepo.findOne({
      where: { id: recipientId },
    });
    if (!recipient) throw new NotFoundException('照护对象不存在');
    if (recipient.familyId !== familyId) {
      throw new ForbiddenException('该照护对象不属于您的家庭');
    }
    return recipient;
  }

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
          logs.push(await this.logRepo.save(log));
        }
      }
    }

    return logs;
  }

  /** 获取今日用药汇总 */
  async getTodaySummary(recipientId: string, familyId: string) {
    await this.validateRecipientInFamily(recipientId, familyId);
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

    // 取出打卡人信息（用 FamilyMember.nickname）
    // takenBy 存的是 userId，通过 userId + familyId 匹配 FamilyMember 查 nickname
    const userIds = logs.map((l) => l.takenBy).filter(Boolean);
    const members =
      userIds.length > 0
        ? await this.memberRepo
            .createQueryBuilder('m')
            .leftJoinAndSelect('m.user', 'user')
            .where('m.userId IN (:...userIds)', { userIds })
            .andWhere('m.familyId = :familyId', { familyId })
            .getMany()
        : [];
    const memberMap = new Map(
      members.map((m) => [
        m.userId,
        {
          nickname: m.nickname,
          avatarUrl: m.avatarUrl || (m.user as any)?.avatar || null,
        },
      ]),
    );

    const items = logs.map((log) => ({
      id: log.id,
      medicationName: log.medication?.name || '',
      dosage: log.medication?.dosage || '',
      scheduledTime: log.scheduledTime,
      status: log.status,
      canCheckIn: log.status === MedicationLogStatus.PENDING,
      actualTime: log.takenAt ? formatLocalTime(log.takenAt) : null,
      takenBy: log.takenBy
        ? {
            id: log.takenBy,
            name: memberMap.get(log.takenBy)?.nickname || '家庭成员',
            avatarUrl: memberMap.get(log.takenBy)?.avatarUrl || null,
          }
        : null,
    }));

    const completed = items.filter(
      (i) =>
        i.status === MedicationLogStatus.TAKEN ||
        i.status === MedicationLogStatus.SKIPPED,
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
    const log = await this.logRepo.findOne({
      where: { id: logId },
      relations: ['medication'],
    });
    if (!log) throw new NotFoundException('用药记录不存在');
    // 验证该药品属于请求者的家庭
    if (!log.medication || log.medication.familyId !== dto.familyId) {
      throw new ForbiddenException('该用药记录不属于您的家庭');
    }

    log.status = dto.status;
    log.takenAt = new Date();
    log.takenBy = userId;
    if (dto.note) log.note = dto.note;

    return this.logRepo.save(log);
  }

  /** 历史记录 */
  async getHistory(recipientId: string, familyId: string, date: string) {
    await this.validateRecipientInFamily(recipientId, familyId);
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
  async getTimeline(
    recipientId?: string,
    familyId?: string,
    medicationId?: string,
    _days = 7,
    before?: Date,
  ): Promise<any[]> {
    const qb = this.logRepo
      .createQueryBuilder('log')
      .leftJoinAndSelect('log.medication', 'medication')
      .where('log.status IN (:...statuses)', {
        statuses: [MedicationLogStatus.TAKEN, MedicationLogStatus.SKIPPED],
      })
      .andWhere('log.takenAt IS NOT NULL')
      .orderBy('log.takenAt', 'DESC')
      .take(50);

    if (before) qb.andWhere('log.takenAt < :before', { before });
    if (recipientId)
      qb.andWhere('log.recipientId = :recipientId', { recipientId });
    if (familyId)
      qb.andWhere(
        'log.recipientId IN (SELECT cr.id FROM care_recipients cr WHERE cr."familyId" = :familyId)',
        { familyId },
      );
    if (medicationId)
      qb.andWhere('log.medicationId = :medicationId', { medicationId });

    const logs = await qb.getMany();

    // takenBy 存的是 userId，通过 FamilyMember 表查 nickname（通过 userId 匹配）
    const userIds = logs.map((l) => l.takenBy).filter(Boolean);
    const members =
      userIds.length > 0
        ? await this.memberRepo
            .createQueryBuilder('m')
            .leftJoinAndSelect('m.user', 'user')
            .where('m.userId IN (:...userIds)', { userIds })
            .andWhere(
              familyId ? 'm."familyId" = :familyId' : '1=1',
              familyId ? { familyId } : {},
            )
            .getMany()
        : [];
    const memberMap = new Map<
      string,
      { nickname: string; avatarUrl: string | null }
    >();
    for (const m of members) {
      const info = {
        nickname: m.nickname,
        avatarUrl: m.avatarUrl || (m.user as any)?.avatar || null,
      };
      memberMap.set(m.userId, info); // userId -> info
    }

    return logs.map((log) => ({
      id: log.id,
      type: 'medication',
      content: `${log.medication?.name || ''} 已${log.status === MedicationLogStatus.TAKEN ? '服用' : '跳过'}${log.medication?.dosage ? ' · ' + log.medication.dosage : ''}`,
      authorName: memberMap.get(log.takenBy)?.nickname || '家庭成员',
      authorAvatar: memberMap.get(log.takenBy)?.avatarUrl || null,
      authorId: log.takenBy,
      recipientId: log.recipientId,
      time: formatLocalTime(log.takenAt),
      status: log.status,
    }));
  }
}

/** 格式化日期为本地时间字符串（YYYY-MM-DD HH:mm:ss） */
function formatLocalTime(date: Date): string {
  const pad = (n: number) => n.toString().padStart(2, '0');
  // JS Date 的 toLocaleString 在 UTC 时间下会按服务器本地时区解析
  // DB 存的北京时间 (UTC+8) 传给 TypeORM 后变成 UTC 时间
  // 需要加回 8 小时再取本地 API，转为北京时间
  const local = new Date(date.getTime() + 8 * 60 * 60 * 1000);
  return `${local.getUTCFullYear()}-${pad(local.getUTCMonth() + 1)}-${pad(local.getUTCDate())} ${pad(local.getUTCHours())}:${pad(local.getUTCMinutes())}:${pad(local.getUTCSeconds())}`;
}
