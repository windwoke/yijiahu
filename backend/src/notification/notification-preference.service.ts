import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { NotificationPreference } from './entities/notification-preference.entity';
import { UpdatePreferenceDto } from './dto/notification-preference.dto';

@Injectable()
export class NotificationPreferenceService {
  constructor(
    @InjectRepository(NotificationPreference)
    private readonly repo: Repository<NotificationPreference>,
  ) {}

  /** 获取用户偏好，不存在则返回默认值 */
  async getByUserId(userId: string): Promise<NotificationPreference> {
    let pref = await this.repo.findOne({ where: { userId } });
    if (!pref) {
      pref = ((await this.repo.save(this.repo.create({ userId } as any))) as unknown) as NotificationPreference;
    }
    return pref;
  }

  /** 更新用户偏好（upsert）*/
  async update(userId: string, dto: UpdatePreferenceDto): Promise<NotificationPreference> {
    let pref = await this.repo.findOne({ where: { userId } });
    if (!pref) {
      pref = ((this.repo.create({ userId } as any)) as unknown) as NotificationPreference;
    }
    const allowedFields: (keyof UpdatePreferenceDto)[] = [
      'medicationReminder', 'missedDose', 'appointmentReminder',
      'taskReminder', 'taskAssigned', 'dailyCheckin', 'dailyCheckinCompleted', 'healthAlert', 'sosEnabled',
      'memberJoined', 'careLog',
      'medicationLeadMinutes', 'appointmentLeadHours',
      'dndEnabled', 'dndStart', 'dndEnd',
      'soundEnabled', 'vibrationEnabled',
    ];
    for (const field of allowedFields) {
      if ((dto as any)[field] !== undefined) {
        (pref as any)[field] = (dto as any)[field];
      }
    }
    return ((await this.repo.save(pref as any)) as unknown) as NotificationPreference;
  }

  /** 检查某个通知类型是否开启 */
  async isTypeEnabled(userId: string, type: string): Promise<boolean> {
    const pref = await this.getByUserId(userId);
    const typeMap: Record<string, keyof NotificationPreference> = {
      medication_reminder: 'medicationReminder',
      missed_dose: 'missedDose',
      appointment_reminder: 'appointmentReminder',
      task_reminder: 'taskReminder',
      task_assigned: 'taskAssigned',
      daily_checkin: 'dailyCheckin',
      daily_checkin_completed: 'dailyCheckinCompleted',
      health_alert: 'healthAlert',
      sos: 'sosEnabled',
      member_joined: 'memberJoined',
      care_log: 'careLog',
    };
    const field = typeMap[type];
    if (!field) return true;
    return (pref as any)[field] === true;
  }

  /** 获取提醒提前时间 */
  async getMedicationLeadMinutes(userId: string): Promise<number> {
    const pref = await this.getByUserId(userId);
    return pref.medicationLeadMinutes ?? 5;
  }

  async getAppointmentLeadHours(userId: string): Promise<number> {
    const pref = await this.getByUserId(userId);
    return pref.appointmentLeadHours ?? 24;
  }

  /** 检查当前是否在免打扰时段（不包含 SOS）*/
  async isInDndPeriod(userId: string): Promise<boolean> {
    const pref = await this.getByUserId(userId);
    if (!pref.dndEnabled) return false;

    const now = new Date();
    const currentMinutes = now.getHours() * 60 + now.getMinutes();

    const parseTime = (t: string) => {
      const [h, m] = t.split(':').map(Number);
      return h * 60 + m;
    };
    const start = parseTime(pref.dndStart);
    const end = parseTime(pref.dndEnd);

    // 跨天情况（如 22:00 ~ 07:00）
    if (start > end) {
      return currentMinutes >= start || currentMinutes < end;
    }
    return currentMinutes >= start && currentMinutes < end;
  }
}
