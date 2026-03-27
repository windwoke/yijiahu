import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Between } from 'typeorm';
import { DailyCareCheckin } from './entities/daily-care-checkin.entity';
import { CreateDailyCareCheckinDto } from './dto/daily-care-checkin.dto';
import { MedicationLog } from '../medication-log/entities/medication-log.entity';
import { CareRecipient } from '../care-recipient/entities/care-recipient.entity';

@Injectable()
export class DailyCareCheckinService {
  constructor(
    @InjectRepository(DailyCareCheckin) private repo: Repository<DailyCareCheckin>,
    @InjectRepository(MedicationLog) private medLogRepo: Repository<MedicationLog>,
    @InjectRepository(CareRecipient) private recipientRepo: Repository<CareRecipient>,
  ) {}

  /** 验证照护对象属于指定家庭 */
  private async validateRecipientInFamily(recipientId: string, familyId: string): Promise<CareRecipient> {
    const recipient = await this.recipientRepo.findOne({ where: { id: recipientId } });
    if (!recipient) throw new NotFoundException('照护对象不存在');
    if (recipient.familyId !== familyId) {
      throw new ForbiddenException('该照护对象不属于您的家庭');
    }
    return recipient;
  }

  /** 获取指定日期的打卡记录 */
  async findByDate(careRecipientId: string, checkinDate: string) {
    return this.repo
      .createQueryBuilder('c')
      .leftJoinAndSelect('c.checkedInBy', 'checkedInBy')
      .where('c.careRecipientId = :careRecipientId', { careRecipientId })
      .andWhere('TO_CHAR(c.checkinDate, \'YYYY-MM-DD\') = :checkinDate', { checkinDate })
      .getOne();
  }

  /** 批量获取今日打卡（用于首页横幅）—— 传入家庭所有照护对象ID */
  async findTodayByRecipients(recipientIds: string[], todayDate: string, familyId: string) {
    if (recipientIds.length === 0) return [];
    // 验证所有recipientId都属于该家庭
    const recipients = await this.recipientRepo.findBy(
      recipientIds.map(id => ({ id } as any)),
    );
    for (const r of recipients) {
      if (r.familyId !== familyId) {
        throw new ForbiddenException('该照护对象不属于您的家庭');
      }
    }
    // 使用日期字符串直接比较（避免 new Date() 的 UTC 解释导致时区偏移一天）
    return this.repo
      .createQueryBuilder('c')
      .leftJoinAndSelect('c.checkedInBy', 'checkedInBy')
      .leftJoinAndSelect('c.careRecipient', 'recipient')
      .where('c.careRecipientId IN (:...ids)', { ids: recipientIds })
      .andWhere('TO_CHAR(c.checkinDate, \'YYYY-MM-DD\') = :date', { date: todayDate })
      .getMany();
  }

  /** 创建或更新打卡（upsert）*/
  async upsert(dto: CreateDailyCareCheckinDto, userId: string) {
    // 验证照护对象归属
    await this.validateRecipientInFamily(dto.careRecipientId, dto.familyId);
    const existing = await this.repo
      .createQueryBuilder('c')
      .where('c.careRecipientId = :careRecipientId', { careRecipientId: dto.careRecipientId })
      .andWhere('TO_CHAR(c.checkinDate, \'YYYY-MM-DD\') = :checkinDate', { checkinDate: dto.checkinDate })
      .getOne();

    // 自动计算今日用药完成情况（使用本地时区的日期范围）
    const todayStr = dto.checkinDate;
    const todayStart = new Date(`${todayStr}T00:00:00`);
    const todayEnd = new Date(`${todayStr}T23:59:59.999`);
    const medLogs = await this.medLogRepo.find({
      where: {
        recipientId: dto.careRecipientId,
        takenAt: Between(todayStart, todayEnd),
      },
    });
    const completedCount = medLogs.filter((m) => m.status === 'taken').length;

    if (existing) {
      existing.status = dto.status;
      existing.medicationCompleted = dto.medicationCompleted ?? completedCount;
      existing.medicationTotal = dto.medicationTotal ?? 0;
      existing.specialNote = dto.specialNote ?? null;
      existing.checkedInById = userId;
      return this.repo.save(existing);
    } else {
      // 直接用字符串创建 date，避免 new Date() 的 UTC 解释导致时区偏移
      const checkin = this.repo.create({
        careRecipientId: dto.careRecipientId,
        checkinDate: todayStr, // TypeORM 自动转换为 PostgreSQL date
        status: dto.status,
        medicationCompleted: dto.medicationCompleted ?? completedCount,
        medicationTotal: dto.medicationTotal ?? 0,
        specialNote: dto.specialNote ?? null,
        checkedInById: userId,
      });
      return this.repo.save(checkin);
    }
  }

  /** 获取照护对象的打卡历史（用于时间线）
   * @param careRecipientId - 可选，指定照护对象ID
   * @param familyId - 可选，按家庭筛选（返回该家庭所有照护对象的打卡记录）
   * @param limit - 返回条数上限
   */
  async findByRecipient(careRecipientId?: string, familyId?: string, limit = 30) {
    const qb = this.repo
      .createQueryBuilder('c')
      .leftJoinAndSelect('c.checkedInBy', 'checkedInBy')
      .leftJoinAndSelect('c.careRecipient', 'careRecipient')
      .orderBy('c.checkinDate', 'DESC')
      .take(limit);

    if (careRecipientId) {
      qb.where('c.careRecipientId = :careRecipientId', { careRecipientId });
    } else if (familyId) {
      qb.where('careRecipient.familyId = :familyId', { familyId });
    }

    return qb.getMany();
  }
}
