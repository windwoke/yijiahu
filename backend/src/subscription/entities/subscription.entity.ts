import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Family } from '../../family/entities/family.entity';

export enum SubscriptionStatus {
  PENDING = 'pending',   // 支付中
  ACTIVE = 'active',     // 生效中
  CANCELLED = 'cancelled', // 已取消（取消但未到期）
  EXPIRED = 'expired',   // 已过期
}

@Entity('subscriptions')
export class Subscription {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  familyId: string;

  @ManyToOne(() => Family)
  @JoinColumn({ name: 'familyId' })
  family: Family;

  /** 订阅方案 */
  @Column()
  plan: string;

  @Column({
    type: 'enum',
    enum: SubscriptionStatus,
    default: SubscriptionStatus.PENDING,
  })
  status: SubscriptionStatus;

  @Column()
  startsAt: Date;

  @Column()
  expiresAt: Date;

  /** 支付平台：wechat / apple / google */
  @Column({ nullable: true })
  paymentPlatform: string;

  /** 平台交易单号 */
  @Column({ nullable: true })
  paymentTradeNo: string;

  /** Apple IAP receipt（验签后存储） */
  @Column({ nullable: true })
  appleReceipt: string;

  /** 微信预支付 id */
  @Column({ nullable: true })
  wechatPrepayId: string;

  /** 取消时间 */
  @Column({ nullable: true })
  cancelAt: Date;

  /** 退款时间 */
  @Column({ nullable: true })
  refundedAt: Date;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
