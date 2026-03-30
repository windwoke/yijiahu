import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Medication } from '../../medication/entities/medication.entity';
import { CareRecipient } from '../../care-recipient/entities/care-recipient.entity';

export enum MedicationLogStatus {
  PENDING = 'pending',
  TAKEN = 'taken',
  SKIPPED = 'skipped',
  MISSED = 'missed',
}

@Entity('medication_logs')
export class MedicationLog {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  recipientId: string;

  @Column()
  medicationId: string;

  @Column()
  scheduledDate: Date;

  @Column()
  scheduledTime: string; // "08:00"

  @Column({
    type: 'enum',
    enum: MedicationLogStatus,
    default: MedicationLogStatus.PENDING,
  })
  status: MedicationLogStatus;

  @Column({ nullable: true })
  takenAt: Date;

  @Column({ nullable: true })
  takenBy: string; // userId，记录打卡人的用户ID

  @Column({ nullable: true })
  note: string;

  @CreateDateColumn()
  createdAt: Date;

  @ManyToOne(() => Medication)
  @JoinColumn({ name: 'medicationId' })
  medication: Medication;

  @ManyToOne(() => CareRecipient)
  @JoinColumn({ name: 'recipientId' })
  recipient: CareRecipient;
}
