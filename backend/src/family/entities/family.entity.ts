import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  DeleteDateColumn,
  OneToMany,
} from 'typeorm';
import { FamilyMember } from './family-member.entity';
import { CareRecipient } from '../../care-recipient/entities/care-recipient.entity';

export enum SubscriptionPlan {
  FREE = 'free',
  PREMIUM = 'premium',
  ANNUAL = 'annual',
}

@Entity('families')
export class Family {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ nullable: true })
  avatarUrl: string;

  @Column()
  name: string;

  @Column({ nullable: true })
  description: string;

  /** 6位邀请码 */
  @Column({ unique: true })
  inviteCode: string;

  /** 订阅方案 */
  @Column({
    type: 'enum',
    enum: SubscriptionPlan,
    default: SubscriptionPlan.FREE,
  })
  subscriptionPlan: SubscriptionPlan;

  /** 订阅过期时间 */
  @Column({ nullable: true })
  subscriptionExpiresAt: Date;

  /** 家庭创建者 */
  @Column({ nullable: true })
  ownerId: string;

  /** 地区，默认 CN */
  @Column({ default: 'CN' })
  region: string;

  /** 免费版可添加照护对象上限 */
  @Column({ default: 1 })
  maxRecipients: number;

  /** 免费版可添加成员上限 */
  @Column({ default: 3 })
  maxMembers: number;

  /** 免费版每月日志上限 */
  @Column({ default: 50 })
  maxLogsPerMonth: number;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  /** 软删除 */
  @DeleteDateColumn()
  deletedAt: Date;

  @OneToMany(() => FamilyMember, (fm) => fm.family)
  members: FamilyMember[];

  @OneToMany(() => CareRecipient, (cr) => cr.family)
  careRecipients: CareRecipient[];
}
