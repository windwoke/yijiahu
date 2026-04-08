import { Injectable, Logger, Inject } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull, Between } from 'typeorm';
import {
  MedicationLog,
  MedicationLogStatus,
} from '../medication-log/entities/medication-log.entity';
import { Medication } from '../medication/entities/medication.entity';
import { CareRecipient } from '../care-recipient/entities/care-recipient.entity';
import { CaregiverRecord } from '../caregiver-record/entities/caregiver-record.entity';
import { Appointment } from '../appointment/entities/appointment.entity';
import {
  FamilyTask,
  TaskStatus,
} from '../family-task/entities/family-task.entity';
import { DailyCareCheckin } from '../daily-care-checkin/entities/daily-care-checkin.entity';
import { FamilyMember } from '../family/entities/family-member.entity';
import {
  Notification,
  NotificationType,
  NotificationLevel,
} from './entities/notification.entity';
import { NotificationService } from './notification.service';
import { NotificationChannel } from './entities/notification.entity';
import { NotificationPreferenceService } from './notification-preference.service';

@Injectable()
export class NotificationScheduler {
  private readonly logger = new Logger(NotificationScheduler.name);

  constructor(
    @InjectRepository(MedicationLog)
    private readonly logRepo: Repository<MedicationLog>,
    @InjectRepository(Medication)
    private readonly medRepo: Repository<Medication>,
    @InjectRepository(CareRecipient)
    private readonly recipientRepo: Repository<CareRecipient>,
    @InjectRepository(CaregiverRecord)
    private readonly caregiverRepo: Repository<CaregiverRecord>,
    @InjectRepository(Appointment)
    private readonly apptRepo: Repository<Appointment>,
    @InjectRepository(FamilyTask)
    private readonly taskRepo: Repository<FamilyTask>,
    @InjectRepository(DailyCareCheckin)
    private readonly checkinRepo: Repository<DailyCareCheckin>,
    @InjectRepository(FamilyMember)
    private readonly memberRepo: Repository<FamilyMember>,
    @InjectRepository(Notification)
    private readonly notificationRepo: Repository<Notification>,
    private readonly notificationSvc: NotificationService,
    @Inject(NotificationPreferenceService)
    private readonly prefSvc: NotificationPreferenceService,
  ) {}

  /**
   * 用药提醒：每分钟执行，检查未来 N 分钟内需要服药的记录
   * - N 由用户偏好 medicationLeadMinutes 控制（默认 5 分钟）
   * - 向当前照护人推送提醒
   */
  @Cron(CronExpression.EVERY_MINUTE)
  async handleMedicationReminders() {
    try {
      const now = new Date();
      const nowStr = now.toTimeString().substring(0, 5); // "HH:mm"
      const [nowHour, nowMin] = nowStr.split(':').map(Number);
      const nowMinutes = nowHour * 60 + nowMin;

      // 获取所有照护人偏好（keyed by userId），避免循环查
      const allPrefs = await this.prefSvc.getAllPreferencesMap();
      const leadMinutesMap = new Map<string, number>();
      for (const [uid, pref] of Object.entries(allPrefs)) {
        leadMinutesMap.set(uid, (pref as any)?.medicationLeadMinutes ?? 5);
      }

      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);
      const todayEnd = new Date();
      todayEnd.setHours(23, 59, 59, 999);

      // 只查今日 pending 记录
      const pendingLogs = await this.logRepo.find({
        where: {
          status: MedicationLogStatus.PENDING,
          scheduledDate: Between(todayStart, todayEnd),
        },
        relations: ['medication'],
      });

      // 批量获取照护人和照护对象，减少 N+1 查询
      const recipientIds = [...new Set(pendingLogs.map((l) => l.recipientId))];
      const [caregivers, recipients] = await Promise.all([
        this.caregiverRepo.find({
          where: recipientIds.map((rid) => ({ careRecipientId: rid, periodEnd: IsNull() as any })),
          relations: ['caregiver'],
        }),
        this.recipientRepo.findByIds(recipientIds),
      ]);
      const caregiverMap = new Map(caregivers.map((c) => [c.careRecipientId, c]));
      const recipientMap = new Map(recipients.map((r) => [r.id, r]));

      // 批量检查已发送的提醒（用 sourceId IN [...]）
      const logIds = pendingLogs.map((l) => l.id);
      const sentNotifications = await this.notificationRepo
        .createQueryBuilder('n')
        .where('n.sourceId IN (:...ids)', { ids: logIds })
        .andWhere('n.type = :type', { type: NotificationType.MEDICATION_REMINDER })
        .getMany();
      const sentSet = new Set(sentNotifications.map((n) => n.sourceId));

      for (const log of pendingLogs) {
        if (!log.medication || sentSet.has(log.id)) continue;

        const [schedHour, schedMin] = log.scheduledTime.split(':').map(Number);
        const schedMinutes = schedHour * 60 + schedMin;

        const caregiver = caregiverMap.get(log.recipientId);
        if (!caregiver) continue;
        const leadMinutes = leadMinutesMap.get(caregiver.caregiverId) ?? 5;

        // 提醒窗口：服药时间前 leadMinutes 分钟内
        if (schedMinutes - nowMinutes > leadMinutes || schedMinutes < nowMinutes) continue;

        const recipient = recipientMap.get(log.recipientId);

        await this.notificationSvc.create({
          userId: caregiver.caregiverId,
          familyId: log.medication?.familyId,
          type: NotificationType.MEDICATION_REMINDER,
          title: '用药提醒',
          body: `${caregiver.caregiver?.name || '您'}，${recipient?.name || '照护对象'}该服用${log.medication.name}了（${log.scheduledTime}）`,
          level: NotificationLevel.NORMAL,
          sourceType: 'medication_log',
          sourceId: log.id,
          channel: NotificationChannel.APP,
          dataJson: {
            recipientId: log.recipientId,
            medicationId: log.medicationId,
            scheduledTime: log.scheduledTime,
          },
        });

        this.logger.debug(
          `用药提醒已发送：${log.medication.name} → ${caregiver.caregiverId}（提前${leadMinutes}分钟）`,
        );
      }
    } catch (e) {
      this.logger.error('handleMedicationReminders 出错', e);
    }
  }

  /**
   * 漏服通知：每 30 分钟执行，检查 30 分钟前仍未打卡的记录
   * - 向当前照护人推送漏服提醒
   */
  @Cron('0 */30 * * * *') // 每 30 分钟
  async handleMissedDoses() {
    try {
      const now = new Date();
      const nowStr = now.toTimeString().substring(0, 5);
      const [nowHour, nowMin] = nowStr.split(':').map(Number);
      const nowMinutes = nowHour * 60 + nowMin;

      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);
      const todayEnd = new Date();
      todayEnd.setHours(23, 59, 59, 999);

      const pendingLogs = await this.logRepo.find({
        where: {
          status: MedicationLogStatus.PENDING,
          scheduledDate: Between(todayStart, todayEnd),
        },
        relations: ['medication'],
      });

      for (const log of pendingLogs) {
        if (!log.medication) continue;

        const scheduledTime = log.scheduledTime;
        const [schedHour, schedMin] = scheduledTime.split(':').map(Number);
        const schedMinutes = schedHour * 60 + schedMin;

        // 漏服：服药时间已过 30 分钟
        if (nowMinutes - schedMinutes < 30) continue;

        // 检查是否已发送漏服通知
        const alreadySent = await this.notificationRepo.findOne({
          where: {
            sourceId: log.id,
            type: NotificationType.MISSED_DOSE,
          },
        });
        if (alreadySent) continue;

        const caregiver = await this.getCurrentCaregiver(log.recipientId);
        if (!caregiver) continue;

        const recipient = await this.recipientRepo.findOne({
          where: { id: log.recipientId },
        });

        await this.notificationSvc.create({
          userId: caregiver.caregiverId,
          familyId: log.medication?.familyId,
          type: NotificationType.MISSED_DOSE,
          title: '漏服提醒',
          body: `${caregiver.caregiver?.name || '您'}，${recipient?.name || '照护对象'}的${log.medication.name}超过30分钟未服用，请尽快确认（计划${scheduledTime}）`,
          level: NotificationLevel.HIGH,
          sourceType: 'medication_log',
          sourceId: log.id,
          channel: NotificationChannel.APP,
          dataJson: {
            recipientId: log.recipientId,
            medicationId: log.medicationId,
            scheduledTime,
          },
        });

        this.logger.debug(
          `漏服提醒已发送：${log.medication.name} → ${caregiver.caregiverId}`,
        );
      }
    } catch (e) {
      this.logger.error('handleMissedDoses 出错', e);
    }
  }

  /**
   * 复诊提醒：每小时执行，检查 N 小时内即将到来的复诊
   * - N 由用户偏好 appointmentLeadHours 控制（默认 24 小时）
   */
  @Cron(CronExpression.EVERY_HOUR)
  async handleAppointmentReminders() {
    try {
      const now = new Date();
      const leadHours = 24; // TODO: 可扩展为 per-member 偏好
      const inHours = new Date(now.getTime() + leadHours * 60 * 60 * 1000);

      const upcomingAppts = await this.apptRepo
        .createQueryBuilder('a')
        .leftJoinAndSelect('a.recipient', 'recipient')
        .leftJoinAndSelect('a.assignedDriver', 'driver')
        .where('a.appointmentTime BETWEEN :now AND :inHours', { now, inHours })
        .andWhere('a.status = :status', { status: 'upcoming' })
        .getMany();

      for (const appt of upcomingAppts) {
        // 检查是否已发送 24h 提醒
        const alreadySent = await this.notificationRepo.findOne({
          where: {
            sourceId: appt.id,
            type: NotificationType.APPOINTMENT_REMINDER,
          },
        });
        if (alreadySent) continue;

        if (!appt.recipient) continue;

        await this.notificationSvc.broadcast({
          familyId: appt.recipient.familyId,
          excludeUserId: undefined,
          type: NotificationType.APPOINTMENT_REMINDER,
          title: '🏥 复诊提醒',
          body: (() => {
            const apptTime = appt.appointmentTime instanceof Date
              ? appt.appointmentTime
              : new Date(appt.appointmentTime as any);
            const nowMs = Date.now();
            const diffMs = apptTime.getTime() - nowMs;
            const diffHours = Math.round(diffMs / 3600000);
            let timeLabel = '';
            if (diffHours < 1) timeLabel = '即将开始';
            else if (diffHours < 24) timeLabel = `${diffHours}小时后`;
            else {
              const diffDays = Math.round(diffHours / 24);
              timeLabel = `明天 ${apptTime.getHours().toString().padStart(2,'0')}:${apptTime.getMinutes().toString().padStart(2,'0')}`;
            }
            const deptDoctor = [appt.department, appt.doctorName].filter(Boolean).join(' ');
            return `${appt.recipient.name}将于${timeLabel}前往${appt.hospital}${deptDoctor ? '（' + deptDoctor + '）' : ''}复诊${
              appt.assignedDriver ? `，接送人：${(appt.assignedDriver as any).name || '已分配'}` : ''
            }`;
          })(),
          level: NotificationLevel.HIGH,
          sourceType: 'appointment',
          sourceId: appt.id,
          dataJson: {
            recipientId: appt.recipientId,
            appointmentId: appt.id,
            appointmentTime: appt.appointmentTime,
            hospital: appt.hospital,
            recipientName: appt.recipient?.name,
          },
        });

        this.logger.debug(`复诊提醒已发送：${appt.id}`);
      }
    } catch (e) {
      this.logger.error('handleAppointmentReminders 出错', e);
    }
  }

  /**
   * 任务到期提醒：每分钟执行，检查未来 15 分钟内到期的任务
   * - 仅通知负责人（assignee）
   * - 排除已通知过的任务
   */
  @Cron(CronExpression.EVERY_MINUTE)
  async handleTaskReminders() {
    try {
      const now = new Date();
      const in15min = new Date(now.getTime() + 15 * 60 * 1000);

      // 查找 nextDueAt 在 [now, now+15min) 的待办任务
      const tasks = await this.taskRepo
        .createQueryBuilder('t')
        .leftJoinAndSelect('t.recipient', 'recipient')
        .leftJoinAndSelect('t.assignee', 'assignee')
        .where('t.status = :pending', { pending: TaskStatus.PENDING })
        .andWhere('t.nextDueAt BETWEEN :now AND :in15min', { now, in15min })
        .getMany();

      for (const task of tasks) {
        // 检查是否已发送提醒（15分钟内不重复）
        const recentSent = await this.notificationRepo.findOne({
          where: {
            sourceId: task.id,
            type: NotificationType.TASK_REMINDER,
            createdAt: Between(new Date(now.getTime() - 15 * 60 * 1000), new Date()),
          },
        });
        if (recentSent) continue;

        // 计算距离到期的分钟数
        const dueAt = task.nextDueAt instanceof Date ? task.nextDueAt : new Date(task.nextDueAt as any);
        const minutesLeft = Math.round((dueAt.getTime() - now.getTime()) / 60000);
        const timeLabel = minutesLeft <= 1 ? '即将到期' : `还有${minutesLeft}分钟`;
        const assigneeName = (task as any).assignee?.name || '你';
        const forWho = task.recipient ? `为 ${task.recipient.name}` : '';

        await this.notificationSvc.create({
          userId: task.assigneeId,
          familyId: task.familyId,
          type: NotificationType.TASK_REMINDER,
          title: '📋 任务到期提醒',
          body: `${assigneeName}，${forWho}「${task.title}」${timeLabel}`,
          level: NotificationLevel.NORMAL,
          sourceType: 'family_task',
          sourceId: task.id,
          channel: NotificationChannel.APP,
          dataJson: {
            taskId: task.id,
            recipientId: task.recipientId,
            title: task.title,
          },
        });

        this.logger.debug(`任务提醒已发送：${task.title} → ${task.assigneeId}`);
      }
    } catch (e) {
      this.logger.error('handleTaskReminders 出错', e);
    }
  }

  /**
   * 每日护理打卡提醒：每天 09:00 执行
   * - 查找前一日未打卡的照护对象
   * - 通知该对象的当前照护人
   */
  @Cron('0 0 9 * * *') // 每天 09:00
  async handleDailyCheckinReminders() {
    try {
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      yesterday.setHours(0, 0, 0, 0);
      const yesterdayEnd = new Date(yesterday);
      yesterdayEnd.setHours(23, 59, 59, 999);

      // 查找所有照护对象
      const recipients = await this.recipientRepo.find();

      for (const recipient of recipients) {
        // 检查昨日是否已打卡
        const checkedIn = await this.checkinRepo.findOne({
          where: {
            careRecipientId: recipient.id,
            checkinDate: Between(yesterday, yesterdayEnd),
          },
        });
        if (checkedIn) continue; // 已打卡，跳过

        // 获取当前照护人
        const caregiver = await this.getCurrentCaregiver(recipient.id);
        if (!caregiver) continue;

        // 检查是否已发送打卡提醒（用日期+照护对象+类型去重）
        const alreadySent = await this.notificationRepo.findOne({
          where: {
            sourceId: recipient.id,
            type: NotificationType.DAILY_CHECKIN,
          },
        });
        if (alreadySent) continue;

        await this.notificationSvc.create({
          userId: caregiver.caregiverId,
          familyId: recipient.familyId,
          type: NotificationType.DAILY_CHECKIN,
          title: '每日打卡提醒',
          body: `${caregiver.caregiver?.name || '您'}，${recipient.name}昨日（${yesterday.getMonth() + 1}/${yesterday.getDate()}）尚未提交护理打卡，请及时补录`,
          level: NotificationLevel.NORMAL,
          sourceType: 'daily_care_checkin',
          sourceId: recipient.id,
          channel: NotificationChannel.APP,
          dataJson: {
            recipientId: recipient.id,
            checkinDate: yesterday.toISOString().split('T')[0],
          },
        });

        this.logger.debug(
          `打卡提醒已发送：${recipient.name} → ${caregiver.caregiverId}`,
        );
      }
    } catch (e) {
      this.logger.error('handleDailyCheckinReminders 出错', e);
    }
  }

  /** 获取当前照护人（period_end 为 null） */
  private async getCurrentCaregiver(
    recipientId: string,
  ): Promise<CaregiverRecord | null> {
    return this.caregiverRepo.findOne({
      where: { careRecipientId: recipientId, periodEnd: IsNull() },
      relations: ['caregiver'],
    });
  }
}
