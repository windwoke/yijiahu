import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull, Not } from 'typeorm';
import {
  Notification,
  NotificationType,
  NotificationLevel,
  NotificationStatus,
  NotificationChannel,
} from './entities/notification.entity';
import { CreateNotificationDto, BroadcastNotificationDto } from './dto/notification.dto';
import { FamilyMember } from '../family/entities/family-member.entity';
import { User } from '../user/entities/user.entity';
import { NotificationPreferenceService } from './notification-preference.service';

@Injectable()
export class NotificationService {
  constructor(
    @InjectRepository(Notification)
    private readonly repo: Repository<Notification>,
    @InjectRepository(FamilyMember)
    private readonly memberRepo: Repository<FamilyMember>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    private readonly prefSvc: NotificationPreferenceService,
  ) {}

  /** 查询用户通知列表（分页） */
  async findByUser(
    userId: string,
    page = 1,
    pageSize = 20,
    type?: NotificationType,
    isRead?: boolean,
  ) {
    const where: any = { userId, deletedAt: IsNull() };
    if (type) where.type = type;
    if (isRead !== undefined) where.isRead = isRead;

    const [list, total] = await this.repo.findAndCount({
      where,
      order: { createdAt: 'DESC' },
      skip: (page - 1) * pageSize,
      take: pageSize,
    });

    return {
      list,
      pagination: {
        page,
        page_size: pageSize,
        total,
        total_pages: Math.ceil(total / pageSize),
      },
    };
  }

  /** 获取用户未读数 */
  async getUnreadCount(userId: string): Promise<number> {
    return this.repo.count({
      where: { userId, isRead: false, deletedAt: IsNull() },
    });
  }

  /** 创建单条通知并推送 */
  async create(dto: CreateNotificationDto): Promise<Notification | null> {
    const userId = dto.userId;

    // SOS 强制推送，绕过所有限制
    const isUrgent = dto.level === NotificationLevel.URGENT || dto.type === NotificationType.SOS;

    if (!isUrgent) {
      // 检查通知类型开关
      const enabled = await this.prefSvc.isTypeEnabled(userId, dto.type);
      if (!enabled) return null;

      // 检查免打扰时段（非 SOS 通知）
      const inDnd = await this.prefSvc.isInDndPeriod(userId);
      if (inDnd) return null;
    }

    const n = this.repo.create({
      userId,
      familyId: dto.familyId,
      type: dto.type,
      title: dto.title,
      body: dto.body,
      level: dto.level || NotificationLevel.NORMAL,
      sourceType: dto.sourceType,
      sourceId: dto.sourceId,
      sourceUserId: dto.sourceUserId,
      channel: dto.channel || NotificationChannel.APP,
      dataJson: dto.dataJson,
      status: NotificationStatus.SENT,
      sentAt: new Date(),
    } as any);
    const saved = (await this.repo.save(n) as unknown) as Notification;

    // TODO: 触发极光推送（生产环境）
    // await this.pushToUser(userId, saved);

    return saved;
  }

  /** 批量通知家庭成员（排除某人） */
  async broadcast(dto: BroadcastNotificationDto): Promise<Notification[]> {
    const members = await this.memberRepo.find({
      where: { familyId: dto.familyId },
    });

    const results: Notification[] = [];
    for (const member of members) {
      // 排除触发者和无效用户
      if (!member.userId || member.userId === dto.excludeUserId) continue;

      const n = this.repo.create({
        userId: member.userId,
        familyId: dto.familyId,
        type: dto.type,
        title: dto.title,
        body: dto.body,
        level: dto.level || NotificationLevel.NORMAL,
        sourceType: dto.sourceType,
        sourceId: dto.sourceId,
        sourceUserId: dto.sourceUserId,
        channel: NotificationChannel.APP,
        dataJson: dto.dataJson,
        status: NotificationStatus.SENT,
        sentAt: new Date(),
      } as any);
      const saved = (await this.repo.save(n) as unknown) as Notification;
      results.push(saved);

      // TODO: 触发极光推送
      // await this.pushToUser(member.userId, n);
    }

    return results;
  }

  /** 标记单条已读 */
  async markAsRead(id: string, userId: string): Promise<Notification> {
    const n = await this.repo.findOne({ where: { id, userId } });
    if (!n) throw new NotFoundException('通知不存在');
    n.isRead = true;
    n.readAt = new Date();
    n.status = NotificationStatus.OPENED;
    n.openedAt = new Date();
    return this.repo.save(n);
  }

  /** 全部已读 */
  async markAllAsRead(userId: string): Promise<void> {
    await this.repo.update(
      { userId, isRead: false, deletedAt: IsNull() },
      { isRead: true, readAt: new Date() },
    );
  }

  /** 删除通知 */
  async delete(id: string, userId: string): Promise<void> {
    const n = await this.repo.findOne({ where: { id, userId } });
    if (!n) throw new NotFoundException('通知不存在');
    await this.repo.softRemove(n);
  }

  /** 推送通知给指定用户（WebSocket 实时推送占位） */
  async pushViaWebSocket(userId: string, notification: Notification): Promise<void> {
    // WebSocket 推送逻辑由 NotificationGateway 处理
    // 此处仅记录 sent_at
    notification.status = NotificationStatus.SENT;
    notification.sentAt = new Date();
    await this.repo.save(notification);
  }

  /** 极光推送（占位，生产环境接入） */
  private async pushToUser(userId: string, notification: Notification): Promise<void> {
    // TODO: 接入极光 SDK
    // const user = await this.userRepo.findOne({ where: { id: userId } });
    // if (user?.pushToken) {
    //   await jpushService.send({
    //     registrationId: user.pushToken,
    //     title: notification.title,
    //     content: notification.body,
    //     extras: notification.dataJson,
    //   });
    // }
    notification.status = NotificationStatus.SENT;
    notification.sentAt = new Date();
    await this.repo.save(notification);
  }

  /** 通知照护人（用药提醒/漏服通知专用） */
  async notifyCaregiver(
    careRecipientId: string,
    caregiverId: string,
    type: NotificationType,
    title: string,
    body: string,
    level: NotificationLevel = NotificationLevel.NORMAL,
    sourceType?: string,
    sourceId?: string,
    sourceUserId?: string,
    dataJson?: Record<string, any>,
  ): Promise<Notification | null> {
    if (!caregiverId) return null;

    return this.create({
      userId: caregiverId,
      familyId: undefined,
      type,
      title,
      body,
      level,
      sourceType,
      sourceId,
      sourceUserId,
      channel: NotificationChannel.APP,
      dataJson,
    });
  }

  /** SOS 通知：全员推送（除触发者） */
  async notifySOS(
    familyId: string,
    excludeUserId: string,
    sosId: string,
    recipientName: string,
    address: string,
    dataJson?: Record<string, any>,
  ) {
    return this.broadcast({
      familyId,
      excludeUserId,
      type: NotificationType.SOS,
      title: '紧急求助',
      body: `${recipientName} 触发了紧急求助！位置：${address || '未知'}`,
      level: NotificationLevel.URGENT,
      sourceType: 'sos',
      sourceId: sosId,
      dataJson,
    });
  }

  /** 每日打卡完成：通知全员（除打卡人） */
  async notifyDailyCheckinCompleted(
    familyId: string,
    excludeUserId: string,
    recipientName: string,
    checkinStatus: string,
    medicationCompleted: number,
    medicationTotal: number,
    specialNote: string | null,
    sourceId: string,
    dataJson?: Record<string, any>,
  ) {
    const statusLabel: Record<string, string> = {
      normal: '正常',
      concerning: '需关注',
      poor: '较差',
      critical: '危急',
    };
    const label = statusLabel[checkinStatus] || checkinStatus;
    const medDesc = medicationTotal > 0
      ? `用药 ${medicationCompleted}/${medicationTotal}`
      : '今日无用药记录';
    let body = `${recipientName} 护理打卡完成（${label}）${medDesc}`;
    if (specialNote) {
      body += `。备注：${specialNote}`;
    }
    return this.broadcast({
      familyId,
      excludeUserId,
      type: NotificationType.DAILY_CHECKIN_COMPLETED,
      title: `${recipientName} 护理打卡`,
      body,
      level: checkinStatus === 'critical' || checkinStatus === 'poor'
        ? NotificationLevel.HIGH
        : NotificationLevel.NORMAL,
      sourceType: 'daily_care_checkin',
      sourceId,
      dataJson,
    });
  }

  /** SOS 被确认：通知全员（除确认者） */
  async notifySOSAcknowledged(
    familyId: string,
    excludeUserId: string,
    sosId: string,
    acknowledgerName: string,
    dataJson?: Record<string, any>,
  ) {
    return this.broadcast({
      familyId,
      excludeUserId,
      type: NotificationType.SOS_ACKNOWLEDGED,
      title: '求助已确认',
      body: `${acknowledgerName} 已响应紧急求助，请保持联系`,
      level: NotificationLevel.URGENT,
      sourceType: 'sos',
      sourceId: sosId,
      dataJson,
    });
  }
}
