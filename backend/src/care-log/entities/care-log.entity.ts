import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  OneToMany,
} from 'typeorm';
import { CareLogAttachment } from './care-log-attachment.entity';

export enum CareLogType {
  MEDICATION = 'medication',
  HEALTH = 'health',
  EMOTION = 'emotion',
  ACTIVITY = 'activity',
  MEAL = 'meal',
  OTHER = 'other',
}

@Entity('care_logs')
export class CareLog {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  familyId: string;

  @Column()
  recipientId: string;

  @Column({ nullable: true })
  authorId: string;

  @Column()
  authorName: string;

  @Column({
    type: 'enum',
    enum: CareLogType,
    default: CareLogType.OTHER,
  })
  type: CareLogType;

  @Column({ type: 'text' })
  content: string;

  @CreateDateColumn()
  createdAt: Date;

  @OneToMany(() => CareLogAttachment, a => a.careLog)
  attachments: CareLogAttachment[];
}
