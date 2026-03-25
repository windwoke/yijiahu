import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { HealthRecord } from './entities/health-record.entity';
import { CreateHealthRecordDto } from './dto/health-record.dto';

@Injectable()
export class HealthRecordService {
  constructor(
    @InjectRepository(HealthRecord) private repo: Repository<HealthRecord>,
  ) {}

  async create(dto: CreateHealthRecordDto, recordedById?: string) {
    const record = this.repo.create({
      ...dto,
      recordedById,
      recordedAt: dto.recordedAt ? new Date(dto.recordedAt) : new Date(),
    });
    return this.repo.save(record);
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
