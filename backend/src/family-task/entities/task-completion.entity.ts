import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { FamilyTask } from './family-task.entity';
import { User } from '../../user/entities/user.entity';

@Entity('task_completions')
export class TaskCompletion {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  taskId: string;

  @ManyToOne(() => FamilyTask)
  @JoinColumn({ name: 'taskId' })
  task: FamilyTask;

  @Column()
  completedById: string;

  @ManyToOne(() => User, { eager: true })
  @JoinColumn({ name: 'completedById' })
  completedBy: User;

  @CreateDateColumn()
  completedAt: Date;

  @Column({ type: 'date', nullable: true })
  scheduledDate: string | null; // 'YYYY-MM-DD'，标记完成的是哪天的任务实例

  @Column({ nullable: true })
  note: string;
}

