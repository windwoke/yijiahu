import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  Inject,
  forwardRef,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { HealthRecord } from './entities/health-record.entity';
import { User } from '../user/entities/user.entity';
import { CareRecipient } from '../care-recipient/entities/care-recipient.entity';
import { FamilyMember } from '../family/entities/family-member.entity';
import { CaregiverRecord } from '../caregiver-record/entities/caregiver-record.entity';
import { CreateHealthRecordDto } from './dto/health-record.dto';
import { NotificationService } from '../notification/notification.service';
import { NotificationType, NotificationLevel } from '../notification/entities/notification.entity';

@Injectable()
export class HealthRecordService {
  constructor(
    @InjectRepository(HealthRecord) private repo: Repository<HealthRecord>,
    @InjectRepository(User) private userRepo: Repository<User>,
    @InjectRepository(CareRecipient)
    private recipientRepo: Repository<CareRecipient>,
    @InjectRepository(FamilyMember)
    private memberRepo: Repository<FamilyMember>,
    @InjectRepository(CaregiverRecord)
    private caregiverRepo: Repository<CaregiverRecord>,
    @Inject(forwardRef(() => NotificationService))
    private readonly notifSvc: NotificationService,
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

  /** 判断健康数据是否异常并返回预警信息 */
  private checkHealthAlert(
    recordType: string,
    value: any,
  ): { alert: 'none' | 'warning' | 'danger'; label: string; displayValue: string } {
    if (recordType === 'blood_pressure') {
      const sys = value.systolic ?? 0;
      const dia = value.diastolic ?? 0;
      const displayValue = `${sys}/${dia} mmHg`;
      if (sys >= 180 || dia >= 110) return { alert: 'danger', label: '血压', displayValue };
      if (sys >= 140 || dia >= 90) return { alert: 'warning', label: '血压', displayValue };
    }
    if (recordType === 'blood_glucose') {
      const v = value.value ?? 0;
      const displayValue = `${v} mg/dL`;
      if (v > 250 || v < 54) return { alert: 'danger', label: '血糖', displayValue };
      if (v > 180 || v < 70) return { alert: 'warning', label: '血糖', displayValue };
    }
    if (recordType === 'heart_rate') {
      const v = value.value ?? 0;
      const displayValue = `${v} bpm`;
      if (v > 150 || v < 50) return { alert: 'danger', label: '心率', displayValue };
      if (v > 120 || v < 60) return { alert: 'warning', label: '心率', displayValue };
    }
    if (recordType === 'temperature') {
      const v = value.value ?? 0;
      const displayValue = `${v}℃`;
      if (v >= 39.5 || v <= 35.0) return { alert: 'danger', label: '体温', displayValue };
      if (v >= 38.5 || v <= 35.5) return { alert: 'warning', label: '体温', displayValue };
    }
    return { alert: 'none', label: '', displayValue: '' };
  }

  async create(dto: CreateHealthRecordDto, recordedById?: string) {
    const recipient = await this.validateRecipientInFamily(dto.recipientId, dto.familyId);
    const record = this.repo.create({
      ...dto,
      recordedById,
      recordedAt: dto.recordedAt ? new Date(dto.recordedAt) : new Date(),
    });
    const saved = await this.repo.save(record);

    // 检查是否需要发送健康预警
    const alert = this.checkHealthAlert(dto.recordType, dto.value);
    if (alert.alert !== 'none') {
      const recorder = recordedById
        ? await this.memberRepo.findOne({ where: { userId: recordedById, familyId: dto.familyId } })
        : null;
      const recorderName = recorder?.nickname || null;
      this.notifSvc
        .notifyHealthAlert(
          dto.familyId,
          recipient.name,
          alert.label,
          alert.displayValue,
          alert.alert,
          recorderName,
          saved.id,
          { recipientId: dto.recipientId, recordType: dto.recordType },
        )
        .catch(() => {});
    }

    return saved;
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
