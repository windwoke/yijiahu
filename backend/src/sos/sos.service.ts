import {
  Injectable,
  NotFoundException,
  Inject,
  forwardRef,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { SosRecord, SosStatus } from './entities/sos-record.entity';
import { CreateSosDto } from './dto/create-sos.dto';
import { NotificationService } from '../notification/notification.service';
import { User } from '../user/entities/user.entity';

@Injectable()
export class SosService {
  constructor(
    @InjectRepository(SosRecord)
    private readonly repo: Repository<SosRecord>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @Inject(forwardRef(() => NotificationService))
    private readonly notificationSvc: NotificationService,
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

    // 发送 SOS 通知给同家庭成员（除触发者）
    await this.notificationSvc.notifySOS(
      dto.familyId,
      userId,
      saved.id,
      result.recipient?.name || '照护对象',
      dto.address || '未知位置',
    );

    return result;
  }

  async findActive(familyId: string): Promise<SosRecord | null> {
    return this.repo.findOne({
      where: { familyId, status: SosStatus.ACTIVE },
      relations: ['recipient', 'triggeredBy'],
    });
  }

  async updateStatus(
    id: string,
    familyId: string,
    status: SosStatus,
    userId?: string,
  ): Promise<SosRecord> {
    const record = await this.repo.findOne({ where: { id, familyId } });
    if (!record) throw new NotFoundException('SOS记录不存在');

    record.status = status;
    if (status === SosStatus.ACKNOWLEDGED && userId) {
      record.acknowledgedById = userId;
      record.acknowledgedAt = new Date();
      // 发送 SOS 已确认通知给同家庭成员（除确认者）
      const acknowledger = await this.userRepo.findOne({
        where: { id: userId },
      });
      if (acknowledger && record.familyId) {
        await this.notificationSvc.notifySOSAcknowledged(
          record.familyId,
          userId,
          id,
          acknowledger.name || acknowledger.phone || '家庭成员',
        );
      }
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
