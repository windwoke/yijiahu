import { Injectable, NotFoundException, Inject, forwardRef } from '@nestjs/common';
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
import { JPushService } from './jpush.service';

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
    @Inject(forwardRef(() => JPushService))
    private readonly jpushSvc: JPushService,
  ) {}

  /** 查询用户通知列表（分页，可按家庭过滤） */
  async findByUser(
    userId: string,
    page = 1,
    pageSize = 20,
    type?: NotificationType,
    isRead?: boolean,
    familyId?: string,
  ) {
    const where: any = { userId, deletedAt: IsNull() };
    if (type) where.type = type;
    if (isRead !== undefined) where.isRead = isRead;
    if (familyId) where.familyId = familyId;

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

  /** 获取用户未读数（可按家庭过滤） */
  async getUnreadCount(userId: string, familyId?: string): Promise<number> {
    const where: any = { userId, isRead: false, deletedAt: IsNull() };
    if (familyId) where.familyId = familyId;
    return this.repo.count({ where });
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

    // 触发极光推送
    this.pushToUser(userId, saved).catch(() => {});

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

      // 触发极光推送
      this.pushToUser(member.userId, saved).catch(() => {});
    }

    return results;
  }

  /** 标记单条已读 */
  async markAsRead(id: string, userId: string, familyId?: string): Promise<Notification> {
    const where: any = { id, userId };
    if (familyId) where.familyId = familyId;
    const n = await this.repo.findOne({ where });
    if (!n) throw new NotFoundException('通知不存在');
    n.isRead = true;
    n.readAt = new Date();
    n.status = NotificationStatus.OPENED;
    n.openedAt = new Date();
    return this.repo.save(n);
  }

  /** 全部已读（可按家庭过滤） */
  async markAllAsRead(userId: string, familyId?: string): Promise<void> {
    const where: any = { userId, isRead: false, deletedAt: IsNull() };
    if (familyId) where.familyId = familyId;
    await this.repo.update(where, { isRead: true, readAt: new Date() });
  }

  /** 删除通知（可按家庭过滤） */
  async delete(id: string, userId: string, familyId?: string): Promise<void> {
    const where: any = { id, userId };
    if (familyId) where.familyId = familyId;
    const n = await this.repo.findOne({ where });
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

  /** 极光推送 */
  private async pushToUser(userId: string, notification: Notification): Promise<void> {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (user?.pushToken) {
      await this.jpushSvc.pushToRegistration(
        user.pushToken,
        notification.title,
        notification.body,
        notification.dataJson || {},
      );
    }
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

  /** 任务被指派：通知被分配人 */
  async notifyTaskAssigned(
    assigneeId: string,
    taskId: string,
    taskTitle: string,
    dueTime: string | null,
    assignedByName: string,
    dataJson?: Record<string, any>,
  ) {
    const timeLabel = dueTime ? `，请在 ${dueTime} 前完成` : '';
    return this.create({
      userId: assigneeId,
      type: NotificationType.TASK_ASSIGNED,
      title: '新任务已指派',
      body: `${assignedByName} 给你指派了任务「${taskTitle}」${timeLabel}`,
      level: NotificationLevel.NORMAL,
      sourceType: 'family_task',
      sourceId: taskId,
      channel: NotificationChannel.APP,
      dataJson,
    });
  }

  /** 新成员加入：通知其他成员 */
  async notifyMemberJoined(
    familyId: string,
    excludeUserId: string,
    newMemberName: string,
    role: string,
    dataJson?: Record<string, any>,
  ) {
    const roleLabel: Record<string, string> = {
      owner: '管理员',
      coordinator: '协调人',
      caregiver: '照护人',
      guest: '访客',
    };
    return this.broadcast({
      familyId,
      excludeUserId,
      type: NotificationType.MEMBER_JOINED,
      title: '新成员加入',
      body: `${newMemberName} 加入了家庭（${roleLabel[role] || role}）`,
      level: NotificationLevel.NORMAL,
      sourceType: 'family',
      dataJson,
    });
  }

  /** 成员离开/被移除：通知被移除人 */
  async notifyMemberLeft(
    removedUserId: string,
    familyName: string,
    removedByName: string,
    dataJson?: Record<string, any>,
  ) {
    return this.create({
      userId: removedUserId,
      type: NotificationType.MEMBER_LEFT,
      title: '已退出家庭',
      body: `你已被 ${removedByName} 从「${familyName}」中移除`,
      level: NotificationLevel.NORMAL,
      sourceType: 'family',
      channel: NotificationChannel.APP,
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
