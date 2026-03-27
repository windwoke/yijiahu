import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { CareRecipient } from '../../care-recipient/entities/care-recipient.entity';
import { User } from '../../user/entities/user.entity';

export enum CheckinStatus {
  NORMAL = 'normal',
  CONCERNING = 'concerning',
  POOR = 'poor',
  CRITICAL = 'critical',
}

@Entity('daily_care_checkins')
export class DailyCareCheckin {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  careRecipientId: string;

  @ManyToOne(() => CareRecipient)
  @JoinColumn({ name: 'careRecipientId' })
  careRecipient: CareRecipient;

  @Column({ type: 'date' })
  checkinDate: Date;

  @Column({ type: 'varchar', default: CheckinStatus.NORMAL })
  status: CheckinStatus;

  @Column({ type: 'int', default: 0 })
  medicationCompleted: number;

  @Column({ type: 'int', default: 0 })
  medicationTotal: number;

  @Column({ nullable: true, length: 500, type: 'varchar' })
  specialNote: string | null;

  @Column({ nullable: true })
  checkedInById: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'checkedInById' })
  checkedInBy: User;

  @CreateDateColumn()
  createdAt: Date;
}
