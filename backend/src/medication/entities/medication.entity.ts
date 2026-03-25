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
import { CareRecipient } from '../../care-recipient/entities/care-recipient.entity';

@Entity('medications')
export class Medication {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  recipientId: string;

  @Column()
  name: string;

  @Column({ nullable: true })
  realName: string;

  @Column()
  dosage: string; // 如"1颗"、"5mg"

  @Column({ nullable: true })
  unit: string; // 片/mg/ml

  @Column({ default: 'daily' })
  frequency: string; // daily/weekly/as_needed

  @Column({ type: 'simple-array' })
  times: string[]; // 如 ["08:00", "20:00"]

  @Column({ type: 'text', nullable: true })
  instructions: string; // 如"饭后服用"

  @Column({ type: 'date', default: () => 'CURRENT_DATE' })
  startDate: Date;

  @Column({ type: 'date', nullable: true })
  endDate: Date;

  @Column({ nullable: true })
  prescribedBy: string; // 开药医生

  @Column({ default: true })
  isActive: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @DeleteDateColumn()
  deletedAt: Date;

  @ManyToOne(() => CareRecipient)
  @JoinColumn({ name: 'recipientId' })
  recipient: CareRecipient;
}
