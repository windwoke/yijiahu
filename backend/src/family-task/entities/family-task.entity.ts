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
import { Family } from '../../family/entities/family.entity';
import { CareRecipient } from '../../care-recipient/entities/care-recipient.entity';
import { User } from '../../user/entities/user.entity';

export enum TaskFrequency {
  ONCE = 'once',
  DAILY = 'daily',
  WEEKLY = 'weekly',
  MONTHLY = 'monthly',
}

export enum TaskStatus {
  PENDING = 'pending',
  COMPLETED = 'completed',
  CANCELLED = 'cancelled',
}

@Entity('family_tasks')
export class FamilyTask {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  familyId: string;

  @ManyToOne(() => Family)
  @JoinColumn({ name: 'familyId' })
  family: Family;

  @Column({ nullable: true })
  recipientId: string;

  @ManyToOne(() => CareRecipient, { eager: true, nullable: true })
  @JoinColumn({ name: 'recipientId' })
  recipient: CareRecipient;

  @Column()
  title: string;

  @Column({ nullable: true })
  description: string;

  @Column({ type: 'varchar', default: TaskFrequency.ONCE })
  frequency: TaskFrequency;

  @Column({ nullable: true })
  scheduledTime: string; // HH:mm

  @Column({ type: 'int', array: true, nullable: true })
  scheduledDay: number[]; // 周几(1-7) 或 日期(1-31)

  @Column()
  assigneeId: string;

  @ManyToOne(() => User, { eager: true })
  @JoinColumn({ name: 'assigneeId' })
  assignee: User;

  @Column({ type: 'varchar', default: TaskStatus.PENDING })
  status: TaskStatus;

  @Column({ type: 'timestamptz', nullable: true })
  nextDueAt: Date;

  @Column({ nullable: true })
  note: string;

  @Column()
  createdById: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'createdById' })
  createdBy: User;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @DeleteDateColumn()
  deletedAt: Date;
}
