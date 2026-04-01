import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { HealthRecord } from './entities/health-record.entity';
import { User } from '../user/entities/user.entity';
import { CareRecipient } from '../care-recipient/entities/care-recipient.entity';
import { FamilyMember } from '../family/entities/family-member.entity';
import { CreateHealthRecordDto } from './dto/health-record.dto';

@Injectable()
export class HealthRecordService {
  constructor(
    @InjectRepository(HealthRecord) private repo: Repository<HealthRecord>,
    @InjectRepository(User) private userRepo: Repository<User>,
    @InjectRepository(CareRecipient)
    private recipientRepo: Repository<CareRecipient>,
    @InjectRepository(FamilyMember)
    private memberRepo: Repository<FamilyMember>,
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

  async create(dto: CreateHealthRecordDto, recordedById?: string) {
    await this.validateRecipientInFamily(dto.recipientId, dto.familyId);
    const record = this.repo.create({
      ...dto,
      recordedById,
      recordedAt: dto.recordedAt ? new Date(dto.recordedAt) : new Date(),
    });
    return this.repo.save(record);
  }

  /** 获取最近健康记录用于时间线 */
  async findRecent(
    recipientId?: string,
    days = 7,
    limit = 20,
    familyId?: string,
  ): Promise<any[]> {
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

    // 通过 FamilyMember 查 nickname 和头像
    const userIds = records.map((r) => r.recordedById).filter(Boolean);
    const memberMap = new Map<
      string,
      { nickname: string; avatarUrl: string | null }
    >();
    if (userIds.length > 0 && familyId) {
      const members = await this.memberRepo
        .createQueryBuilder('m')
        .leftJoinAndSelect('m.user', 'user')
        .where('m.userId IN (:...userIds)', { userIds })
        .andWhere('m.familyId = :familyId', { familyId })
        .getMany();
      for (const m of members) {
        memberMap.set(m.userId, {
          nickname: m.nickname,
          avatarUrl: m.avatarUrl || (m.user as any)?.avatar || null,
        });
      }
    }

    return records.map((r) => ({
      id: r.id,
      recipientId: r.recipientId,
      recordType: r.recordType,
      value: r.value,
      note: r.note,
      recordedAt: formatLocalTime(r.recordedAt),
      recordedById: r.recordedById,
      authorName: memberMap.get(r.recordedById)?.nickname || '家庭成员',
      authorAvatar: memberMap.get(r.recordedById)?.avatarUrl || null,
    }));
  }

  async findByRecipient(
    recipientId: string,
    familyId: string,
    recordType?: string,
    days = 7,
  ) {
    // 验证归属
    await this.validateRecipientInFamily(recipientId, familyId);

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

  async getTrends(recipientId: string, familyId: string, days = 7) {
    // 验证归属
    await this.validateRecipientInFamily(recipientId, familyId);

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

    const bp = records.filter((r) => r.recordType === 'blood_pressure');
    const glucose = records.filter((r) => r.recordType === 'blood_glucose');

    return { bloodPressure: bp, bloodGlucose: glucose };
  }
}

/** 格式化日期为北京时间字符串 */
function formatLocalTime(date: Date): string {
  const pad = (n: number) => n.toString().padStart(2, '0');
  const local = new Date(date.getTime() + 8 * 60 * 60 * 1000);
  return `${local.getUTCFullYear()}-${pad(local.getUTCMonth() + 1)}-${pad(local.getUTCDate())} ${pad(local.getUTCHours())}:${pad(local.getUTCMinutes())}:${pad(local.getUTCSeconds())}`;
}
