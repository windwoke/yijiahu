import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToOne,
  JoinColumn,
} from 'typeorm';
import { User } from '../../user/entities/user.entity';

@Entity('notification_preferences')
export class NotificationPreference {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  userId: string;

  @OneToOne(() => User)
  @JoinColumn({ name: 'userId' })
  user: User;

  // 通知开关
  @Column({ type: 'boolean', default: true })
  medicationReminder: boolean;

  @Column({ type: 'boolean', default: true })
  missedDose: boolean;

  @Column({ type: 'boolean', default: true })
  appointmentReminder: boolean;

  @Column({ type: 'boolean', default: true })
  taskReminder: boolean;

  @Column({ type: 'boolean', default: true })
  dailyCheckin: boolean;

  @Column({ type: 'boolean', default: true })
  healthAlert: boolean;

  @Column({ type: 'boolean', default: true })
  sosEnabled: boolean;

  @Column({ type: 'boolean', default: true })
  memberJoined: boolean;

  @Column({ type: 'boolean', default: true })
  taskAssigned: boolean;

  @Column({ type: 'boolean', default: true })
  careLog: boolean;

  // 提醒提前时间
  @Column({ type: 'int', default: 5 })
  medicationLeadMinutes: number;

  @Column({ type: 'int', default: 24 })
  appointmentLeadHours: number;

  // 免打扰
  @Column({ type: 'boolean', default: false })
  dndEnabled: boolean;

  @Column({ type: 'time', default: '22:00' })
  dndStart: string;

  @Column({ type: 'time', default: '07:00' })
  dndEnd: string;

  // 推送偏好
  @Column({ type: 'boolean', default: true })
  soundEnabled: boolean;

  @Column({ type: 'boolean', default: true })
  vibrationEnabled: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
