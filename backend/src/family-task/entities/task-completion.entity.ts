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

  @Column({ nullable: true })
  note: string;
}
