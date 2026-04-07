/**
 * 通知模型
 * 对应后端 AppNotification 实体
 */

/** 通知类型 */
export enum NotificationType {
  MEDICATION_REMINDER = 'medication_reminder',
  MEDICATION_MISSED = 'medication_missed',
  APPOINTMENT_REMINDER = 'appointment_reminder',
  TASK_REMINDER = 'task_reminder',
  MEMBER_JOINED = 'member_joined',
  MEMBER_LEFT = 'member_left',
  SOS_TRIGGERED = 'sos_triggered',
  SOS_RESOLVED = 'sos_resolved',
  CARE_RECIPIENT_ALERT = 'care_recipient_alert',
  CAREGIVER_CHANGED = 'caregiver_changed',
  DAILY_CHECKIN_REMINDER = 'daily_checkin_reminder',
  FAMILY_INVITE = 'family_invite',
  SYSTEM_NOTICE = 'system_notice',
  SUBSCRIPTION_EXPIRED = 'subscription_expired',
  HEALTH_ALERT = 'health_alert',
}

/** 通知渠道 */
export enum NotificationChannel {
  APP = 'app',
  WECHAT = 'wechat',
  SMS = 'sms',
}

/** 通知级别 */
export enum NotificationLevel {
  NORMAL = 'normal',
  HIGH = 'high',
  URGENT = 'urgent',
}

export interface AppNotification {
  id: string;
  userId: string;
  familyId: string | null;
  type: NotificationType;
  title: string;
  body: string;
  level: NotificationLevel;
  sourceType: string | null;
  sourceId: string | null;
  sourceUserId: string | null;
  isRead: boolean;
  createdAt: string;
  dataJson: Record<string, unknown> | null;
}

/** 通知偏好设置 */
export interface NotificationPreference {
  medicationReminder: boolean;
  medicationMissed: boolean;
  appointmentReminder: boolean;
  taskReminder: boolean;
  sosNotifications: boolean;
  memberNotifications: boolean;
  healthAlerts: boolean;
  quietHoursStart: string | null; // "22:00"
  quietHoursEnd: string | null;   // "08:00"
  advanceMinutes: number; // 提前多少分钟提醒
  channels: NotificationChannel[];
}
