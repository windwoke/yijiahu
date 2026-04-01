import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CareLog } from './entities/care-log.entity';
import { CareLogAttachment } from './entities/care-log-attachment.entity';
import { CareLogAttachmentService } from './care-log-attachment.service';
import { CreateCareLogDto } from './dto/care-log.dto';
import { User } from '../user/entities/user.entity';
import { FamilyMember } from '../family/entities/family-member.entity';

@Injectable()
export class CareLogService {
  constructor(
    @InjectRepository(CareLog)
    private readonly repo: Repository<CareLog>,
    @InjectRepository(CareLogAttachment)
    private readonly attachmentRepo: Repository<CareLogAttachment>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(FamilyMember)
    private readonly memberRepo: Repository<FamilyMember>,
    private readonly attachmentService: CareLogAttachmentService,
  ) {}

  async create(
    familyId: string,
    userId: string,
    dto: CreateCareLogDto,
  ): Promise<CareLog> {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    const authorName = user?.name || user?.phone || '家庭成员';

    const log = this.repo.create({
      familyId,
      recipientId: dto.recipientId,
      authorId: userId,
      authorName,
      type: dto.type,
      content: dto.content,
    });
    const saved = await this.repo.save(log);

    // 绑定附件（attachmentIds 为上传后返回的 UUID 列表）
    if (dto.attachmentIds && dto.attachmentIds.length > 0) {
      await this.attachmentService.updateCareLogId(dto.attachmentIds, saved.id);
    }

    return saved;
  }

  async findByFamily(
    familyId: string,
    options: {
      recipientId?: string;
      type?: string;
      limit?: number;
      before?: Date; // 分页游标：只取 createdAt < before 的记录
    } = {},
  ): Promise<any[]> {
    const qb = this.repo
      .createQueryBuilder('log')
      .leftJoinAndSelect('log.attachments', 'attachment')
      .where('log.familyId = :familyId', { familyId })
      .orderBy('log.createdAt', 'DESC');

    if (options.recipientId) {
      qb.andWhere('log.recipientId = :recipientId', {
        recipientId: options.recipientId,
      });
    }
    if (options.type) {
      qb.andWhere('log.type = :type', { type: options.type });
    }
    if (options.before) {
      qb.andWhere('log.createdAt < :before', { before: options.before });
    }
    if (options.limit) {
      qb.take(options.limit);
    }

    const logs = await qb.getMany();

    // 通过 FamilyMember 查 nickname 和头像
    const authorIds = logs.map((l) => l.authorId).filter(Boolean);
    const members =
      authorIds.length > 0
        ? await this.memberRepo
            .createQueryBuilder('m')
            .leftJoinAndSelect('m.user', 'user')
            .where('m.familyId = :familyId', { familyId })
            .andWhere('m.userId IN (:...authorIds)', { authorIds })
            .getMany()
        : [];
    const memberMap = new Map<
      string,
      { nickname: string; avatarUrl: string | null }
    >();
    for (const m of members) {
      memberMap.set(m.userId, {
        nickname: m.nickname,
        avatarUrl: m.avatarUrl || (m.user as any)?.avatar || null,
      });
    }

    return logs.map((log) => ({
      id: log.id,
      recipientId: log.recipientId,
      authorId: log.authorId,
      authorName:
        memberMap.get(log.authorId)?.nickname || log.authorName || '家庭成员',
      authorAvatar: memberMap.get(log.authorId)?.avatarUrl || null,
      type: log.type,
      content: log.content,
      createdAt: formatLocalTime(log.createdAt),
      attachments: ((log as any).attachments || []).map(
        (a: CareLogAttachment) => ({
          id: a.id,
          type: a.type,
          url: a.url,
          thumbnailUrl: a.thumbnailUrl,
          size: a.size,
          duration: a.duration,
          width: a.width,
          height: a.height,
          filename: a.filename,
        }),
      ),
    }));
  }

  async findByRecipient(recipientId: string, limit = 50): Promise<CareLog[]> {
    return this.repo.find({
      where: { recipientId },
      order: { createdAt: 'DESC' },
      take: limit,
    });
  }
}

/** 格式化日期为本地时间字符串（YYYY-MM-DD HH:mm:ss） */
function formatLocalTime(date: Date): string {
  const pad = (n: number) => n.toString().padStart(2, '0');
  // DB 存的北京时间传给 TypeORM 后变成 UTC 时间
  // 加回 8 小时再用 UTC API 取值，得出北京时间
  const local = new Date(date.getTime() + 8 * 60 * 60 * 1000);
  return `${local.getUTCFullYear()}-${pad(local.getUTCMonth() + 1)}-${pad(local.getUTCDate())} ${pad(local.getUTCHours())}:${pad(local.getUTCMinutes())}:${pad(local.getUTCSeconds())}`;
}
