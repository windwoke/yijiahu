import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CareLogAttachment, AttachmentType } from './entities/care-log-attachment.entity';

@Injectable()
export class CareLogAttachmentService {
  constructor(
    @InjectRepository(CareLogAttachment)
    private readonly repo: Repository<CareLogAttachment>,
  ) {}

  async create(data: {
    careLogId?: string;
    type: AttachmentType;
    url: string;
    thumbnailUrl?: string;
    size?: number;
    duration?: number;
    width?: number;
    height?: number;
    filename: string;
  }): Promise<CareLogAttachment> {
    const attachment = this.repo.create(data);
    return this.repo.save(attachment);
  }

  async createBatch(items: Array<{
    careLogId?: string;
    type: AttachmentType;
    url: string;
    thumbnailUrl?: string;
    size?: number;
    duration?: number;
    width?: number;
    height?: number;
    filename: string;
  }>): Promise<CareLogAttachment[]> {
    const attachments = items.map(item => this.repo.create(item));
    return this.repo.save(attachments);
  }

  async findById(id: string): Promise<CareLogAttachment | null> {
    return this.repo.findOne({ where: { id } });
  }

  async findByIds(ids: string[]): Promise<CareLogAttachment[]> {
    return this.repo.findByIds(ids);
  }

  async updateCareLogId(ids: string[], careLogId: string): Promise<void> {
    await this.repo.update(ids, { careLogId });
  }

  async findByCareLogId(careLogId: string): Promise<CareLogAttachment[]> {
    return this.repo.find({
      where: { careLogId },
      order: { createdAt: 'ASC' },
    });
  }

  async deleteByCareLogId(careLogId: string): Promise<void> {
    await this.repo.delete({ careLogId });
  }
}
