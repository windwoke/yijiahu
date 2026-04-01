import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Medication } from './entities/medication.entity';
import { CareRecipient } from '../care-recipient/entities/care-recipient.entity';
import { CreateMedicationDto, UpdateMedicationDto } from './dto/medication.dto';

@Injectable()
export class MedicationService {
  constructor(
    @InjectRepository(Medication) private repo: Repository<Medication>,
    @InjectRepository(CareRecipient)
    private recipientRepo: Repository<CareRecipient>,
  ) {}

  /** 验证照护对象属于指定家庭 */
  private async validateRecipientInFamily(
    recipientId: string,
    familyId: string,
  ): Promise<CareRecipient> {
    const recipient = await this.recipientRepo.findOne({
      where: { id: recipientId },
    });
    if (!recipient) throw new NotFoundException('照护对象不存在');
    if (recipient.familyId !== familyId) {
      throw new ForbiddenException('该照护对象不属于您的家庭');
    }
    return recipient;
  }

  async create(familyId: string, dto: CreateMedicationDto) {
    // 验证 recipient 属于该家庭
    await this.validateRecipientInFamily(dto.recipientId, familyId);
    const medication = this.repo.create({ ...dto, familyId });
    return this.repo.save(medication);
  }

  findByFamily(familyId: string) {
    return this.repo
      .createQueryBuilder('m')
      .leftJoinAndSelect('m.recipient', 'recipient')
      .where('m.familyId = :familyId', { familyId })
      .andWhere('m.deletedAt IS NULL')
      .orderBy('m.createdAt', 'ASC')
      .getMany();
  }

  /** 按 recipientId 查询（同时验证 familyId）；或按 familyId 查询 */
  async findByFamilyOrRecipient(familyId?: string, recipientId?: string) {
    if (recipientId && familyId) {
      // 双参数：先按 familyId 查，再在内存中过滤 recipientId（service 层可JOIN验证）
      const all = await this.repo
        .createQueryBuilder('m')
        .leftJoinAndSelect('m.recipient', 'recipient')
        .where('m.familyId = :familyId', { familyId })
        .andWhere('m.deletedAt IS NULL')
        .getMany();
      return all.filter((m) => m.recipientId === recipientId);
    }
    if (recipientId) {
      // 仅 recipientId：需要先查 recipient 归属哪个 family，再过滤
      const recipient = await this.recipientRepo.findOne({
        where: { id: recipientId },
      });
      if (!recipient) return [];
      return this.repo
        .createQueryBuilder('m')
        .leftJoinAndSelect('m.recipient', 'recipient')
        .where('m.familyId = :familyId', { familyId: recipient.familyId })
        .andWhere('m.deletedAt IS NULL')
        .getMany();
    }
    if (familyId) {
      return this.findByFamily(familyId);
    }
    return [];
  }

  async findOne(id: string, familyId: string) {
    const medication = await this.repo.findOne({
      where: { id, familyId },
    });
    if (!medication) throw new NotFoundException('药品不存在或不属于您的家庭');
    return medication;
  }

  async update(id: string, familyId: string, dto: UpdateMedicationDto) {
    await this.findOne(id, familyId);
    await this.repo.update(id, dto);
    return this.findOne(id, familyId);
  }

  async delete(id: string, familyId: string) {
    await this.findOne(id, familyId);
    await this.repo.update(id, { deletedAt: new Date() } as any);
    return { message: '药品已删除' };
  }
}
