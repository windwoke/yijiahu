import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThanOrEqual, LessThan, IsNull, Between } from 'typeorm';
import { MedicationLog, MedicationLogStatus } from '../medication-log/entities/medication-log.entity';
import { Medication } from '../medication/entities/medication.entity';
import { CareRecipient } from '../care-recipient/entities/care-recipient.entity';
import { CaregiverRecord } from '../caregiver-record/entities/caregiver-record.entity';
import { Appointment } from '../appointment/entities/appointment.entity';
import {
  Notification,
  NotificationType,
  NotificationLevel,
} from './entities/notification.entity';
import { NotificationService } from './notification.service';
import { NotificationChannel } from './entities/notification.entity';

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
    @InjectRepository(Notification)
    private readonly notificationRepo: Repository<Notification>,
    private readonly notificationSvc: NotificationService,
  ) {}

  /**
   * 用药提醒：每分钟执行，检查未来 5 分钟内需要服药的记录
   * - 向当前照护人推送提醒
   * - 排除已打卡或已通知过的记录
   */
  @Cron(CronExpression.EVERY_MINUTE)
  async handleMedicationReminders() {
    try {
      const now = new Date();
      const nowStr = now.toTimeString().substring(0, 5); // "HH:mm"

      // 查找今日所有待服用的用药记录
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

        // 检查是否在提醒窗口（服药时间前 5 分钟内）
        const scheduledTime = log.scheduledTime; // "HH:mm"
        const [schedHour, schedMin] = scheduledTime.split(':').map(Number);
        const [nowHour, nowMin] = nowStr.split(':').map(Number);
        const schedMinutes = schedHour * 60 + schedMin;
        const nowMinutes = nowHour * 60 + nowMin;

        // 提醒窗口：服药时间前 5 分钟到服药时间
        if (schedMinutes - nowMinutes > 5 || schedMinutes < nowMinutes) continue;

        // 检查是否已发送过提醒（通过 sourceId 去重）
        const alreadySent = await this.notificationRepo.findOne({
          where: {
            sourceId: log.id,
            type: NotificationType.MEDICATION_REMINDER,
          },
        });
        if (alreadySent) continue;

        // 获取照护人
        const caregiver = await this.getCurrentCaregiver(log.recipientId);
        if (!caregiver) continue;

        const recipient = await this.recipientRepo.findOne({ where: { id: log.recipientId } });

        await this.notificationSvc.create({
          userId: caregiver.caregiverId,
          familyId: log.medication?.familyId,
          type: NotificationType.MEDICATION_REMINDER,
          title: '用药提醒',
          body: `${recipient?.name || '照护对象'}该服用${log.medication.name}了（${scheduledTime}）`,
          level: NotificationLevel.NORMAL,
          sourceType: 'medication_log',
          sourceId: log.id,
          channel: NotificationChannel.APP,
          dataJson: {
            recipientId: log.recipientId,
            medicationId: log.medicationId,
            scheduledTime,
          },
        });

        this.logger.debug(`用药提醒已发送：${log.medication.name} → ${caregiver.caregiverId}`);
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

        const recipient = await this.recipientRepo.findOne({ where: { id: log.recipientId } });

        await this.notificationSvc.create({
          userId: caregiver.caregiverId,
          familyId: log.medication?.familyId,
          type: NotificationType.MISSED_DOSE,
          title: '漏服提醒',
          body: `${recipient?.name || '照护对象'}的${log.medication.name}尚未服用（计划${scheduledTime}）`,
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

        this.logger.debug(`漏服提醒已发送：${log.medication.name} → ${caregiver.caregiverId}`);
      }
    } catch (e) {
      this.logger.error('handleMissedDoses 出错', e);
    }
  }

  /**
   * 复诊提醒：每小时执行，检查 24 小时内即将到来的复诊
   */
  @Cron(CronExpression.EVERY_HOUR)
  async handleAppointmentReminders() {
    try {
      const now = new Date();
      const in24h = new Date(now.getTime() + 24 * 60 * 60 * 1000);

      const upcomingAppts = await this.apptRepo
        .createQueryBuilder('a')
        .leftJoinAndSelect('a.recipient', 'recipient')
        .leftJoinAndSelect('a.assignedDriver', 'driver')
        .where('a.appointmentTime BETWEEN :now AND :in24h', { now, in24h })
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
          title: '复诊提醒',
          body: `${appt.recipient.name}将于明天前往${appt.hospital}复诊${
            appt.assignedDriver ? `（接送人：${appt.assignedDriver.name || '已分配'}）` : ''
          }`,
          level: NotificationLevel.HIGH,
          sourceType: 'appointment',
          sourceId: appt.id,
          dataJson: {
            recipientId: appt.recipientId,
            appointmentId: appt.id,
            appointmentTime: appt.appointmentTime,
          },
        });

        this.logger.debug(`复诊提醒已发送：${appt.id}`);
      }
    } catch (e) {
      this.logger.error('handleAppointmentReminders 出错', e);
    }
  }

  /** 获取当前照护人（period_end 为 null） */
  private async getCurrentCaregiver(recipientId: string): Promise<CaregiverRecord | null> {
    return this.caregiverRepo.findOne({
      where: { careRecipientId: recipientId, periodEnd: IsNull() },
      relations: ['caregiver'],
    });
  }
}
