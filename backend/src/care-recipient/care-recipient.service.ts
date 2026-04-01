import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CareRecipient } from './entities/care-recipient.entity';
import { FamilyMember } from '../family/entities/family-member.entity';
import {
  CreateCareRecipientDto,
  UpdateCareRecipientDto,
} from './dto/care-recipient.dto';

@Injectable()
export class CareRecipientService {
  constructor(
    @InjectRepository(CareRecipient) private repo: Repository<CareRecipient>,
    @InjectRepository(FamilyMember)
    private memberRepo: Repository<FamilyMember>,
  ) {}

  async create(familyId: string, dto: CreateCareRecipientDto) {
    const recipient = this.repo.create({ familyId, ...dto });
    return this.repo.save(recipient);
  }

  async findByFamily(familyId: string) {
    if (!familyId) return [];
    return this.repo
      .createQueryBuilder('cr')
      .where('cr.familyId = :familyId', { familyId })
      .andWhere('cr.deletedAt IS NULL')
      .orderBy('cr.createdAt', 'ASC')
      .getMany();
  }

  async findOne(recipientId: string, familyId: string) {
    const recipient = await this.repo.findOne({ where: { id: recipientId } });
    if (!recipient) throw new NotFoundException('照护对象不存在');
    if (recipient.familyId !== familyId) {
      throw new ForbiddenException('无权访问该照护对象');
    }
    return recipient;
  }

  async update(
    recipientId: string,
    familyId: string,
    dto: UpdateCareRecipientDto,
  ) {
    await this.findOne(recipientId, familyId);
    await this.repo.update(recipientId, dto);
    return this.findOne(recipientId, familyId);
  }

  async delete(recipientId: string, familyId: string) {
    await this.findOne(recipientId, familyId);
    await this.repo.softDelete(recipientId);
    return { message: '已删除照护对象' };
  }

  async checkFamilyAccess(
    recipientId: string,
    userId: string,
  ): Promise<CareRecipient> {
    const recipient = await this.repo.findOne({ where: { id: recipientId } });
    if (!recipient) throw new NotFoundException('照护对象不存在');

    const member = await this.memberRepo.findOne({
      where: { familyId: recipient.familyId, userId },
    });
    if (!member) throw new ForbiddenException('无权访问');
    return recipient;
  }
}
