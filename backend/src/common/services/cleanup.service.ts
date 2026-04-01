import { Injectable } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CareLogAttachment } from '../../care-log/entities/care-log-attachment.entity';
import { OssService } from './oss.service';

@Injectable()
export class CleanupService {
  constructor(
    @InjectRepository(CareLogAttachment)
    private readonly attachmentRepo: Repository<CareLogAttachment>,
    private readonly oss: OssService,
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

    await Promise.all(orphans.map((a) =>
      this.oss.delete(a.url).then(() => this.attachmentRepo.delete(a.id)),
    ));
    const deleted = orphans.length;

    if (deleted > 0) {
      console.log(`[Cleanup] 清理了 ${deleted} 个孤立附件`);
    }
  }
}
