import {
  Injectable,
  NotFoundException,
  Inject,
  forwardRef,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull } from 'typeorm';
import { ConfigService } from '@nestjs/config';
import {
  Notification,
  NotificationType,
  NotificationLevel,
  NotificationStatus,
  NotificationChannel,
} from './entities/notification.entity';
import {
  CreateNotificationDto,
  BroadcastNotificationDto,
} from './dto/notification.dto';
import { FamilyMember } from '../family/entities/family-member.entity';
import { User } from '../user/entities/user.entity';
import { NotificationPreferenceService } from './notification-preference.service';
import { JPushService } from './jpush.service';
import { WechatService } from '../wechat/wechat.service';

@Injectable()
export class NotificationService {
  // 微信订阅消息模板 ID 映射（从环境变量读取）
  private readonly wechatTemplateIds: Record<string, string>;

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
    private readonly wechatSvc: WechatService,
    private readonly config: ConfigService,
  ) {
    // 从环境变量读取各通知类型的订阅消息模板 ID（仅低频场景使用一次性订阅）
    // 模板字段名必须与微信后台配置完全一致
    this.wechatTemplateIds = {
      [NotificationType.SOS]: this.config.get<string>('wechat.tmpl.sos') || '',
      [NotificationType.APPOINTMENT_REMINDER]: this.config.get<string>('wechat.tmpl.appointmentReminder') || '',
    };
  }

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
    const isUrgent =
      dto.level === NotificationLevel.URGENT ||
      dto.type === NotificationType.SOS;

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
    const saved = (await this.repo.save(n)) as unknown as Notification;

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
      const saved = (await this.repo.save(n)) as unknown as Notification;
      results.push(saved);

      // 触发极光推送
      this.pushToUser(member.userId, saved).catch(() => {});
    }

    return results;
  }

  /** 标记单条已读 */
  async markAsRead(
    id: string,
    userId: string,
    familyId?: string,
  ): Promise<Notification> {
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
  async pushViaWebSocket(
    userId: string,
    notification: Notification,
  ): Promise<void> {
    // WebSocket 推送逻辑由 NotificationGateway 处理
    // 此处仅记录 sent_at
    notification.status = NotificationStatus.SENT;
    notification.sentAt = new Date();
    await this.repo.save(notification);
  }

  /** 极光推送 */
  private async pushToUser(
    userId: string,
    notification: Notification,
  ): Promise<void> {
    const user = await this.userRepo.findOne({ where: { id: userId } });

    // 1. 极光推送（App 内推送）
    if (user?.pushToken) {
      await this.jpushSvc.pushToRegistration(
        user.pushToken,
        notification.title,
        notification.body,
        notification.dataJson || {},
      );
    }

    // 2. 微信小程序订阅消息（仅低频关键场景：SOS、复诊提醒）
    const wechatEnabled = await this.prefSvc.isWechatEnabled(userId);
    if (wechatEnabled && user?.openId) {
      const templateId = this.wechatTemplateIds[notification.type];
      if (templateId) {
        const dataJson = notification.dataJson || {};
        let data: Record<string, string> = {};

        if (notification.type === NotificationType.SOS) {
          // 模板字段: thing1(姓名) thing3(地址) thing5(紧急联系人) phone_number6(电话) thing7(备注)
          data = {
            thing1: dataJson.recipientName || '家人',
            thing3: dataJson.address || '未知地址',
            thing5: dataJson.emergencyContact || '未知联系人',
            phone_number6: dataJson.emergencyPhone || '',
            thing7: notification.body.replace(/[^\u4e00-\u9fa5a-zA-Z0-9\s，,。.]/g, '').slice(0, 20),
          };
        } else if (notification.type === NotificationType.APPOINTMENT_REMINDER) {
          // 模板字段: time1(复诊日期) time2(复诊时间) thing3(复诊医院) thing4(温馨提示) thing6(复诊人)
          const apptTime = dataJson.appointmentTime ? new Date(dataJson.appointmentTime) : null;
          const dateStr = apptTime ? `${apptTime.getMonth() + 1}月${apptTime.getDate()}日` : '';
          const timeStr = apptTime ? `${apptTime.getHours().toString().padStart(2, '0')}:${apptTime.getMinutes().toString().padStart(2, '0')}` : '';
          data = {
            time1: dateStr,
            time2: timeStr,
            thing3: dataJson.hospital || '未知医院',
            thing4: '请携带相关证件和病历按时就诊',
            thing6: dataJson.recipientName || '家人',
          };
        }

        const result = await this.wechatSvc.sendSubscribeMessage({
          openId: user.openId,
          templateId,
          page: 'pages/home/index',
          data,
        });

        if (result.errcode === 0) {
          notification.channel = NotificationChannel.WECHAT;
        }
      }
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
    // 将 SOS 关键信息注入 dataJson，供微信订阅消息模板使用
    const sosDataJson = {
      recipientName,
      address,
      ...(dataJson || {}),
    };

    return this.broadcast({
      familyId,
      excludeUserId,
      type: NotificationType.SOS,
      title: '🔔 紧急求助',
      body: `${recipientName} 触发了紧急求助，请立即响应！${address ? '位置：' + address : ''}`,
      level: NotificationLevel.URGENT,
      sourceType: 'sos',
      sourceId: sosId,
      dataJson: sosDataJson,
    });
  }

  /** 每日打卡完成：通知全员（除打卡人） */
  async notifyDailyCheckinCompleted(
    familyId: string,
    excludeUserId: string,
    recipientName: string,
    caregiverName: string,
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
    const medDesc =
      medicationTotal > 0
        ? `用药 ${medicationCompleted}/${medicationTotal} 已完成`
        : '今日无用药记录';
    let body = `${caregiverName} 刚为 ${recipientName} 完成护理打卡（${label}）${medDesc}`;
    if (specialNote) {
      body += `。备注：${specialNote}`;
    }
    return this.broadcast({
      familyId,
      excludeUserId,
      type: NotificationType.DAILY_CHECKIN_COMPLETED,
      title: `${recipientName} 护理打卡`,
      body,
      level:
        checkinStatus === 'critical' || checkinStatus === 'poor'
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
    recipientName: string | null,
    dueTime: string | null,
    assignedByName: string,
    dataJson?: Record<string, any>,
  ) {
    const timeLabel = dueTime ? `，请在 ${dueTime} 前完成` : '';
    const forWho = recipientName ? `为${recipientName}` : '';
    return this.create({
      userId: assigneeId,
      type: NotificationType.TASK_ASSIGNED,
      title: '📋 新任务',
      body: `${assignedByName} 给你指派了任务${forWho}「${taskTitle}」${timeLabel}`,
      level: NotificationLevel.NORMAL,
      sourceType: 'family_task',
      sourceId: taskId,
      channel: NotificationChannel.APP,
      dataJson,
    });
  }

  /** 任务完成：通知任务创建人 */
  async notifyTaskCompleted(
    creatorId: string,
    taskId: string,
    taskTitle: string,
    recipientName: string | null,
    completedByName: string,
    dataJson?: Record<string, any>,
  ) {
    if (!creatorId) return null;
    const forWho = recipientName ? `为${recipientName}` : '';
    return this.create({
      userId: creatorId,
      type: NotificationType.TASK_COMPLETED,
      title: '✅ 任务已完成',
      body: `${completedByName} 已完成${forWho}「${taskTitle}」`,
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
      title: '👋 新成员加入',
      body: `${newMemberName} 加入了您的照护团队（${roleLabel[role] || role}）`,
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
      title: '👤 家庭变更',
      body: `${removedByName} 已将你从「${familyName}」中移除，如有问题请联系管理员`,
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
    recipientName: string,
    acknowledgerName: string,
    dataJson?: Record<string, any>,
  ) {
    return this.broadcast({
      familyId,
      excludeUserId,
      type: NotificationType.SOS_ACKNOWLEDGED,
      title: '🔔 求助已确认',
      body: `${acknowledgerName} 已响应紧急求助，${recipientName}的情况已确认，请保持关注`,
      level: NotificationLevel.URGENT,
      sourceType: 'sos',
      sourceId: sosId,
      dataJson,
    });
  }

  /** 健康预警：记录异常健康数据时通知照护人和家属 */
  async notifyHealthAlert(
    familyId: string,
    recipientName: string,
    recordType: string,
    value: string,
    alertLevel: 'warning' | 'danger',
    recordedByName: string | null,
    sourceId: string,
    dataJson?: Record<string, any>,
  ) {
    const level = alertLevel === 'danger' ? NotificationLevel.HIGH : NotificationLevel.NORMAL;
    const label = alertLevel === 'danger' ? '⚠️' : '⚡';
    return this.broadcast({
      familyId,
      excludeUserId: undefined,
      type: NotificationType.HEALTH_ALERT,
      title: `${label} 健康预警`,
      body: `${recipientName}的${recordType}记录为${value}${alertLevel === 'danger' ? '，已超出正常范围，请关注！' : '，建议留意观察'}${
        recordedByName ? `（${recordedByName}记录）` : ''
      }`,
      level,
      sourceType: 'health_record',
      sourceId,
      dataJson,
    });
  }

  /** 照护人变更：通知旧照护人和新照护人 */
  async notifyCaregiverChanged(
    familyId: string,
    recipientName: string,
    oldCaregiverName: string,
    newCaregiverName: string,
    changedByName: string,
    sourceId: string,
    dataJson?: Record<string, any>,
  ) {
    const results: Promise<any>[] = [];

    // 通知旧照护人
    if (oldCaregiverName) {
      const oldMember = await this.memberRepo.findOne({
        where: { familyId, nickname: oldCaregiverName },
      });
      if (oldMember) {
        results.push(
          this.create({
            userId: oldMember.userId,
            familyId,
            type: NotificationType.CAREGIVER_CHANGED,
            title: '🔄 照护对象已变更',
            body: `${changedByName}已将${recipientName}的照护任务转交给${newCaregiverName}，感谢您的付出`,
            level: NotificationLevel.NORMAL,
            sourceType: 'caregiver_record',
            sourceId,
            channel: NotificationChannel.APP,
            dataJson,
          }),
        );
      }
    }

    // 通知新照护人
    const newMember = await this.memberRepo.findOne({
      where: { familyId, nickname: newCaregiverName },
    });
    if (newMember) {
      results.push(
        this.create({
          userId: newMember.userId,
          familyId,
          type: NotificationType.CAREGIVER_CHANGED,
          title: '📋 新照护对象',
          body: `${changedByName}已将${recipientName}的照护任务转交给您，请留意照护安排`,
          level: NotificationLevel.NORMAL,
          sourceType: 'caregiver_record',
          sourceId,
          channel: NotificationChannel.APP,
          dataJson,
        }),
      );
    }

    await Promise.all(results);
  }
}
