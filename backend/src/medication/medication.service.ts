import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Medication } from './entities/medication.entity';
import { CreateMedicationDto, UpdateMedicationDto } from './dto/medication.dto';

@Injectable()
export class MedicationService {
  constructor(@InjectRepository(Medication) private repo: Repository<Medication>) {}

  create(recipientId: string, dto: CreateMedicationDto) {
    const medication = this.repo.create({ recipientId, ...dto });
    return this.repo.save(medication);
  }

  findByRecipient(recipientId: string) {
    if (!recipientId) return [];
    return this.repo
        .createQueryBuilder('m')
        .where('m.recipientId = :recipientId', { recipientId })
        .andWhere('m.deletedAt IS NULL')
        .orderBy('m.createdAt', 'ASC')
        .getMany();
  }

  async findOne(id: string) {
    const medication = await this.repo.findOne({ where: { id } });
    if (!medication) throw new NotFoundException('药品不存在');
    return medication;
  }

  async update(id: string, dto: UpdateMedicationDto) {
    await this.findOne(id);
    await this.repo.update(id, dto);
    return this.findOne(id);
  }

  async delete(id: string) {
    await this.findOne(id);
    // 软删除：设置 deletedAt
    await this.repo.update(id, { deletedAt: new Date() } as any);
    return { message: '药品已删除' };
  }
}
