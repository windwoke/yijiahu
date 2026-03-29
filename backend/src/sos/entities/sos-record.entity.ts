import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Family } from '../../family/entities/family.entity';
import { CareRecipient } from '../../care-recipient/entities/care-recipient.entity';
import { User } from '../../user/entities/user.entity';

export enum SosStatus {
  ACTIVE = 'active',
  ACKNOWLEDGED = 'acknowledged',
  RESOLVED = 'resolved',
  CANCELLED = 'cancelled',
}

@Entity('sos_records')
export class SosRecord {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  familyId: string;

  @ManyToOne(() => Family)
  @JoinColumn({ name: 'familyId' })
  family: Family;

  @Column({ nullable: true })
  recipientId: string;

  @ManyToOne(() => CareRecipient, { nullable: true })
  @JoinColumn({ name: 'recipientId' })
  recipient: CareRecipient;

  @Column()
  triggeredById: string;

  @ManyToOne(() => User, { eager: true })
  @JoinColumn({ name: 'triggeredById' })
  triggeredBy: User;

  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true })
  latitude: number;

  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true })
  longitude: number;

  @Column({ nullable: true, length: 300 })
  address: string;

  @Column({
    type: 'enum',
    enum: SosStatus,
    default: SosStatus.ACTIVE,
  })
  status: SosStatus;

  @Column({ nullable: true })
  acknowledgedById: string;

  @ManyToOne(() => User, { nullable: true })
  @JoinColumn({ name: 'acknowledgedById' })
  acknowledgedBy: User;

  @Column({ type: 'timestamptz', nullable: true })
  acknowledgedAt: Date;

  @Column({ type: 'timestamptz', nullable: true })
  resolvedAt: Date;

  @Column({ type: 'timestamptz', nullable: true })
  cancelledAt: Date;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt: Date;
}
