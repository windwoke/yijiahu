import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { HealthRecord } from './entities/health-record.entity';
import { User } from '../user/entities/user.entity';
import { CreateHealthRecordDto } from './dto/health-record.dto';

@Injectable()
export class HealthRecordService {
  constructor(
    @InjectRepository(HealthRecord) private repo: Repository<HealthRecord>,
    @InjectRepository(User) private userRepo: Repository<User>,
  ) {}

  async create(dto: CreateHealthRecordDto, recordedById?: string) {
    const record = this.repo.create({
      ...dto,
      recordedById,
      recordedAt: dto.recordedAt ? new Date(dto.recordedAt) : new Date(),
    });
    return this.repo.save(record);
  }

  /** 获取最近健康记录用于时间线 */
  async findRecent(recipientId?: string, days = 7, limit = 20, familyId?: string): Promise<any[]> {
    const qb = this.repo
      .createQueryBuilder('hr')
      .leftJoin('hr.recipient', 'cr')
      .where('hr.recordedAt >= :since', {
        since: new Date(Date.now() - days * 24 * 60 * 60 * 1000),
      })
      .orderBy('hr.recordedAt', 'DESC')
      .take(limit);

    if (recipientId) {
      qb.andWhere('hr.recipientId = :recipientId', { recipientId });
    }

    if (familyId) {
      qb.andWhere('cr.familyId = :familyId', { familyId });
    }

    const records = await qb.getMany();

    // 查记录人姓名
    const userIds = records.map(r => r.recordedById).filter(Boolean);
    const users = userIds.length > 0
      ? await this.userRepo.findBy(userIds.map(id => ({ id } as any)))
      : [];
    const userMap = new Map(users.map(u => [u.id, u.name || u.phone]));

    return records.map(r => ({
      id: r.id,
      recipientId: r.recipientId,
      recordType: r.recordType,
      value: r.value,
      note: r.note,
      recordedAt: formatLocalTime(r.recordedAt),
      recordedById: r.recordedById,
      authorName: userMap.get(r.recordedById!) || '家庭成员',
    }));
  }

  async findByRecipient(recipientId: string, recordType?: string, days = 7) {
    const qb = this.repo
        .createQueryBuilder('hr')
        .where('hr.recipientId = :recipientId', { recipientId })
        .andWhere('hr.recordedAt >= :since', {
          since: new Date(Date.now() - days * 24 * 60 * 60 * 1000),
        })
        .orderBy('hr.recordedAt', 'DESC');

    if (recordType) {
      qb.andWhere('hr.recordType = :recordType', { recordType });
    }

    return qb.getMany();
  }

  async getTrends(recipientId: string, days = 7) {
    // 获取血压和血糖的最近数据用于趋势展示
    const records = await this.repo
        .createQueryBuilder('hr')
        .where('hr.recipientId = :recipientId', { recipientId })
        .andWhere('hr.recordedAt >= :since', {
          since: new Date(Date.now() - days * 24 * 60 * 60 * 1000),
        })
        .andWhere('hr.recordType IN (:...types)', {
          types: ['blood_pressure', 'blood_glucose'],
        })
        .orderBy('hr.recordedAt', 'DESC')
        .getMany();

    // 按类型分组
    const bp = records.filter(r => r.recordType === 'blood_pressure');
    const glucose = records.filter(r => r.recordType === 'blood_glucose');

    return { bloodPressure: bp, bloodGlucose: glucose };
  }
}

/** 格式化日期为北京时间字符串 */
function formatLocalTime(date: Date): string {
  const pad = (n: number) => n.toString().padStart(2, '0');
  const local = new Date(date.getTime() + 8 * 60 * 60 * 1000);
  return `${local.getUTCFullYear()}-${pad(local.getUTCMonth() + 1)}-${pad(local.getUTCDate())} ${pad(local.getUTCHours())}:${pad(local.getUTCMinutes())}:${pad(local.getUTCSeconds())}`;
}
