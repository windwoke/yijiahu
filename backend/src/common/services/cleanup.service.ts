import { Injectable } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, LessThan } from 'typeorm';
import * as path from 'path';
import * as fs from 'fs';
import { CareLogAttachment } from '../../care-log/entities/care-log-attachment.entity';

@Injectable()
export class CleanupService {
  constructor(
    @InjectRepository(CareLogAttachment)
    private readonly attachmentRepo: Repository<CareLogAttachment>,
  ) {}

  /** 每小时清理：careLogId 为空超过 1 小时的孤立附件 */
  @Cron(CronExpression.EVERY_HOUR)
  async cleanupOrphanedAttachments() {
    const cutoff = new Date(Date.now() - 60 * 60 * 1000);
    const orphans = await this.attachmentRepo
      .createQueryBuilder('a')
      .where('a."careLogId" IS NULL')
      .andWhere('a."createdAt" < :cutoff', { cutoff })
      .getMany();

    let deleted = 0;
    for (const a of orphans) {
      const filePath = path.join(process.cwd(), a.url);
      try { if (fs.existsSync(filePath)) fs.unlinkSync(filePath); } catch (_) {}
      await this.attachmentRepo.delete(a.id);
      deleted++;
    }

    if (deleted > 0) {
      console.log(`[Cleanup] 清理了 ${deleted} 个孤立附件`);
    }
  }
}
