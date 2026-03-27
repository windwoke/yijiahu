import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull } from 'typeorm';
import { CaregiverRecord } from './entities/caregiver-record.entity';
import { CreateCaregiverRecordDto } from './dto/caregiver-record.dto';
import { CareRecipient } from '../care-recipient/entities/care-recipient.entity';

@Injectable()
export class CaregiverRecordService {
  constructor(
    @InjectRepository(CaregiverRecord) private repo: Repository<CaregiverRecord>,
    @InjectRepository(CareRecipient) private recipientRepo: Repository<CareRecipient>,
  ) {}

  /** 验证照护对象属于指定家庭 */
  private async validateRecipientInFamily(recipientId: string, familyId: string) {
    const recipient = await this.recipientRepo.findOne({ where: { id: recipientId } });
    if (!recipient) throw new NotFoundException('照护对象不存在');
    if (recipient.familyId !== familyId) {
      throw new ForbiddenException('该照护对象不属于您的家庭');
    }
    return recipient;
  }

  /** 按照护对象查询所有记录 */
  async findByRecipient(careRecipientId: string, familyId: string) {
    await this.validateRecipientInFamily(careRecipientId, familyId);
    return this.repo.find({
      where: { careRecipientId },
      relations: ['caregiver', 'createdBy'],
      order: { periodStart: 'DESC' },
    });
  }

  /** 获取当前照护人（period_end 为 null 的那条） */
  async findCurrent(careRecipientId: string, familyId: string) {
    await this.validateRecipientInFamily(careRecipientId, familyId);
    return this.repo.findOne({
      where: { careRecipientId, periodEnd: IsNull() },
      relations: ['caregiver'],
    });
  }

  /** 创建并自动切换：旧记录 period_end = yesterday，新记录 period_start = today */
  async create(dto: CreateCaregiverRecordDto, userId: string) {
    // 验证照护对象存在（归属已在 service 层通过 recipientRepo 间接验证）
    const recipient = await this.recipientRepo.findOne({ where: { id: dto.careRecipientId } });
    if (!recipient) throw new NotFoundException('照护对象不存在');

    // 1. 关闭当前记录
    const current = await this.findCurrent(dto.careRecipientId);
    if (current) {
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      current.periodEnd = yesterday;
      await this.repo.save(current);
    }

    // 2. 创建新记录
    const record = this.repo.create({
      careRecipientId: dto.careRecipientId,
      caregiverId: dto.caregiverId,
      periodStart: new Date(dto.periodStart),
      note: dto.note,
      createdById: userId,
    });
    return this.repo.save(record);
  }

  /** 删除记录（软删除） */
  async delete(id: string, familyId: string) {
    const record = await this.repo.findOne({
      where: { id },
      relations: ['careRecipient'],
    });
    if (!record) throw new NotFoundException('记录不存在');

    const recipient = await this.recipientRepo.findOne({ where: { id: record.careRecipientId } });
    if (!recipient) throw new NotFoundException('照护对象不存在');
    if (recipient.familyId !== familyId) throw new ForbiddenException('无权删除此记录');

    return this.repo.softRemove(record);
  }
}
