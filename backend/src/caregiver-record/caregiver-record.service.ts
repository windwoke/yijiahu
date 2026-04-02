import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  Inject,
  forwardRef,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull } from 'typeorm';
import { CaregiverRecord } from './entities/caregiver-record.entity';
import { CreateCaregiverRecordDto } from './dto/caregiver-record.dto';
import { CareRecipient } from '../care-recipient/entities/care-recipient.entity';
import { FamilyMember } from '../family/entities/family-member.entity';
import { NotificationService } from '../notification/notification.service';

@Injectable()
export class CaregiverRecordService {
  constructor(
    @InjectRepository(CaregiverRecord)
    private repo: Repository<CaregiverRecord>,
    @InjectRepository(CareRecipient)
    private recipientRepo: Repository<CareRecipient>,
    @InjectRepository(FamilyMember)
    private memberRepo: Repository<FamilyMember>,
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

  /** 批量附加 FamilyMember.nickname */
  private async enrichWithNicknames(
    records: CaregiverRecord[],
    familyId: string,
  ): Promise<any[]> {
    if (records.length === 0) return [];
    const caregiverIds = records.map((r) => r.caregiverId);
    const found = await this.memberRepo
      .createQueryBuilder('m')
      .where('m.familyId = :familyId', { familyId })
      .andWhere('m.userId IN (:...ids)', { ids: caregiverIds })
      .getMany();
    const memberMap = new Map<string, string>();
    for (const m of found) {
      memberMap.set(m.userId, m.nickname);
    }
    return records.map((r) => ({
      ...r,
      caregiverNickname: memberMap.get(r.caregiverId) || null,
    }));
  }

  /** 按照护对象查询所有记录 */
  async findByRecipient(careRecipientId: string, familyId: string) {
    await this.validateRecipientInFamily(careRecipientId, familyId);
    const records = await this.repo.find({
      where: { careRecipientId },
      relations: ['caregiver', 'createdBy'],
      order: { periodStart: 'DESC' },
    });
    return this.enrichWithNicknames(records, familyId);
  }

  /** 获取当前照护人（period_end 为 null 的那条） */
  async findCurrent(careRecipientId: string, familyId: string) {
    await this.validateRecipientInFamily(careRecipientId, familyId);
    const record = await this.repo.findOne({
      where: { careRecipientId, periodEnd: IsNull() },
      relations: ['caregiver'],
    });
    if (!record) return null;
    const enriched = await this.enrichWithNicknames([record], familyId);
    return enriched[0];
  }

  /** 创建并自动切换：旧记录 period_end = yesterday，新记录 period_start = today */
  async create(dto: CreateCaregiverRecordDto, userId: string) {
    const recipient = await this.recipientRepo.findOne({
      where: { id: dto.careRecipientId },
    });
    if (!recipient) throw new NotFoundException('照护对象不存在');

    // 关闭当前记录（用原始 entity，不走 enrich）
    const currentEntity = await this.repo.findOne({
      where: { careRecipientId: dto.careRecipientId, periodEnd: IsNull() },
    });

    // 获取旧照护人名称（用于通知）
    let oldCaregiverName: string | null = null;
    if (currentEntity) {
      const oldMember = await this.memberRepo.findOne({
        where: { userId: currentEntity.caregiverId, familyId: recipient.familyId },
      });
      oldCaregiverName = oldMember?.nickname || null;
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      currentEntity.periodEnd = yesterday;
      await this.repo.save(currentEntity);
    }

    const record = this.repo.create({
      careRecipientId: dto.careRecipientId,
      caregiverId: dto.caregiverId,
      periodStart: new Date(dto.periodStart),
      note: dto.note,
      createdById: userId,
    });
    const saved = await this.repo.save(record);

    // 通知照护人变更
    if (currentEntity && dto.caregiverId !== currentEntity.caregiverId) {
      const newMember = await this.memberRepo.findOne({
        where: { userId: dto.caregiverId, familyId: recipient.familyId },
      });
      const newCaregiverName = newMember?.nickname || null;
      const changerMember = await this.memberRepo.findOne({
        where: { userId, familyId: recipient.familyId },
      });
      const changedByName = changerMember?.nickname || '管理员';
      this.notifSvc
        .notifyCaregiverChanged(
          recipient.familyId,
          recipient.name,
          oldCaregiverName || '',
          newCaregiverName || '新照护人',
          changedByName,
          saved.id,
          { recipientId: dto.careRecipientId },
        )
        .catch(() => {});
    }

    return saved;
  }

  /** 删除记录（软删除） */
  async delete(id: string, familyId: string) {
    const record = await this.repo.findOne({
      where: { id },
      relations: ['careRecipient'],
    });
    if (!record) throw new NotFoundException('记录不存在');
    const recipient = await this.recipientRepo.findOne({
      where: { id: record.careRecipientId },
    });
    if (!recipient) throw new NotFoundException('照护对象不存在');
    if (recipient.familyId !== familyId)
      throw new ForbiddenException('无权删除此记录');
    return this.repo.softRemove(record);
  }
}
