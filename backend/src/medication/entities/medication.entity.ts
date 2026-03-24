import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
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

  @Column()
  dosage: string; // 如"1颗"、"5mg"

  @Column({ type: 'simple-array' })
  times: string[]; // 如 ["08:00", "20:00"]

  @Column({ type: 'text', nullable: true })
  instructions: string; // 如"饭后服用"

  @Column({ default: true })
  isActive: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @ManyToOne(() => CareRecipient)
  @JoinColumn({ name: 'recipientId' })
  recipient: CareRecipient;
}
