import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { CareRecipient } from '../../care-recipient/entities/care-recipient.entity';

@Entity('health_records')
export class HealthRecord {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  recipientId: string;

  @Column()
  recordType: string; // blood_pressure | blood_glucose | heart_rate | weight | temperature | custom

  @Column({ type: 'jsonb' })
  value: {
    systolic?: number;
    diastolic?: number;
    value?: number;
    type?: string; // fasting | postprandial
    unit?: string;
  };

  @Column({ nullable: true })
  recordedById: string;

  @Column({ type: 'timestamptz', default: () => 'NOW()' })
  recordedAt: Date;

  @Column({ type: 'text', nullable: true })
  note: string;

  @CreateDateColumn()
  createdAt: Date;

  @ManyToOne(() => CareRecipient, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'recipientId' })
  recipient: CareRecipient;
}
