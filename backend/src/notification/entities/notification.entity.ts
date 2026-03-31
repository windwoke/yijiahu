import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  DeleteDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { User } from '../../user/entities/user.entity';
import { Family } from '../../family/entities/family.entity';

// L0+L1 已实现
export enum NotificationType {
  MEDICATION_REMINDER = 'medication_reminder',
  MISSED_DOSE = 'missed_dose',
  APPOINTMENT_REMINDER = 'appointment_reminder',
  SOS = 'sos',
  SOS_ACKNOWLEDGED = 'sos_acknowledged',
  // L2 后续实现
  MEMBER_JOINED = 'member_joined',
  MEMBER_LEFT = 'member_left',
  TASK_REMINDER = 'task_reminder',
  TASK_ASSIGNED = 'task_assigned',
  TASK_COMPLETED = 'task_completed',
  DAILY_CHECKIN = 'daily_checkin',
  DAILY_CHECKIN_COMPLETED = 'daily_checkin_completed',
  HEALTH_ALERT = 'health_alert',
  CAREGIVER_CHANGED = 'caregiver_changed',
}

export enum NotificationLevel {
  NORMAL = 'normal',
  HIGH = 'high',
  URGENT = 'urgent',
}

export enum NotificationStatus {
  PENDING = 'pending',
  SENT = 'sent',
  DELIVERED = 'delivered',
  OPENED = 'opened',
  FAILED = 'failed',
}

export enum NotificationChannel {
  APP = 'app',
  WECHAT = 'wechat',
  SMS = 'sms',
}

@Entity('notifications')
export class Notification {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  userId: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'userId' })
  user: User;

  @Column({ nullable: true })
  familyId: string;

  @ManyToOne(() => Family)
  @JoinColumn({ name: 'familyId' })
  family: Family;

  @Column({ type: 'enum', enum: NotificationType })
  type: NotificationType;

  @Column()
  title: string;

  @Column({ type: 'text' })
  body: string;

  @Column({ type: 'enum', enum: NotificationLevel, default: NotificationLevel.NORMAL })
  level: NotificationLevel;

  @Column({ nullable: true })
  sourceType: string;

  @Column({ nullable: true })
  sourceId: string;

  @Column({ nullable: true })
  sourceUserId: string;

  @Column({ type: 'enum', enum: NotificationChannel, default: NotificationChannel.APP })
  channel: NotificationChannel;

  @Column({ type: 'enum', enum: NotificationStatus, default: NotificationStatus.PENDING })
  status: NotificationStatus;

  @Column({ default: false })
  isRead: boolean;

  @Column({ nullable: true })
  readAt: Date;

  @Column({ nullable: true })
  sentAt: Date;

  @Column({ nullable: true })
  deliveredAt: Date;

  @Column({ nullable: true })
  openedAt: Date;

  @Column({ type: 'jsonb', nullable: true })
  dataJson: Record<string, any>;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @DeleteDateColumn()
  deletedAt: Date;
}
