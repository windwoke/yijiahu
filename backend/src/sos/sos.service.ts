import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { SosRecord, SosStatus } from './entities/sos-record.entity';
import { CreateSosDto } from './dto/create-sos.dto';

@Injectable()
export class SosService {
  constructor(
    @InjectRepository(SosRecord)
    private readonly repo: Repository<SosRecord>,
  ) {}

  async create(dto: CreateSosDto, userId: string): Promise<SosRecord> {
    // 如果有活跃的 SOS，先取消
    await this.repo.update(
      { familyId: dto.familyId, status: SosStatus.ACTIVE },
      { status: SosStatus.CANCELLED, cancelledAt: new Date() },
    );

    const record = this.repo.create({
      familyId: dto.familyId,
      recipientId: dto.recipientId,
      triggeredById: userId,
      latitude: dto.latitude,
      longitude: dto.longitude,
      address: dto.address,
      status: SosStatus.ACTIVE,
    });
    const saved = await this.repo.save(record);
    const result = await this.repo.findOne({
      where: { id: saved.id },
      relations: ['recipient', 'triggeredBy'],
    });
    if (!result) throw new NotFoundException('SOS记录创建失败');
    return result;
  }

  async findActive(familyId: string): Promise<SosRecord | null> {
    return this.repo.findOne({
      where: { familyId, status: SosStatus.ACTIVE },
      relations: ['recipient', 'triggeredBy'],
    });
  }

  async updateStatus(id: string, familyId: string, status: SosStatus, userId?: string): Promise<SosRecord> {
    const record = await this.repo.findOne({ where: { id, familyId } });
    if (!record) throw new NotFoundException('SOS记录不存在');

    record.status = status;
    if (status === SosStatus.ACKNOWLEDGED && userId) {
      record.acknowledgedById = userId;
      record.acknowledgedAt = new Date();
    }
    if (status === SosStatus.RESOLVED) {
      record.resolvedAt = new Date();
    }
    if (status === SosStatus.CANCELLED) {
      record.cancelledAt = new Date();
    }

    return this.repo.save(record);
  }

  async findByFamily(familyId: string, limit = 20): Promise<SosRecord[]> {
    return this.repo.find({
      where: { familyId },
      relations: ['recipient', 'triggeredBy'],
      order: { createdAt: 'DESC' },
      take: limit,
    });
  }
}
