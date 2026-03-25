import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CareLog } from './entities/care-log.entity';
import { CreateCareLogDto } from './dto/care-log.dto';
import { User } from '../user/entities/user.entity';

@Injectable()
export class CareLogService {
  constructor(
    @InjectRepository(CareLog)
    private readonly repo: Repository<CareLog>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
  ) {}

  async create(familyId: string, userId: string, dto: CreateCareLogDto): Promise<CareLog> {
    // 查找用户姓名
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
    return this.repo.save(log);
  }

  async findByFamily(familyId: string, options: {
    recipientId?: string;
    type?: string;
    limit?: number;
  } = {}): Promise<CareLog[]> {
    const qb = this.repo
      .createQueryBuilder('log')
      .where('log.familyId = :familyId', { familyId })
      .orderBy('log.createdAt', 'DESC');

    if (options.recipientId) {
      qb.andWhere('log.recipientId = :recipientId', { recipientId: options.recipientId });
    }
    if (options.type) {
      qb.andWhere('log.type = :type', { type: options.type });
    }
    if (options.limit) {
      qb.take(options.limit);
    }

    return qb.getMany();
  }

  async findByRecipient(recipientId: string, limit = 50): Promise<CareLog[]> {
    return this.repo.find({
      where: { recipientId },
      order: { createdAt: 'DESC' },
      take: limit,
    });
  }
}
