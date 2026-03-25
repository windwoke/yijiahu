import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { CareLog } from './care-log.entity';

export enum AttachmentType {
  IMAGE = 'image',
  VIDEO = 'video',
}

@Entity('care_log_attachments')
export class CareLogAttachment {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ nullable: true })
  careLogId: string;

  @ManyToOne(() => CareLog, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'careLogId' })
  careLog: CareLog;

  @Column({ type: 'enum', enum: AttachmentType })
  type: AttachmentType;

  @Column()
  url: string;

  @Column({ nullable: true })
  thumbnailUrl: string;

  @Column({ type: 'int', nullable: true })
  size: number;

  @Column({ nullable: true })
  duration: number; // 视频时长，秒

  @Column({ type: 'int', nullable: true })
  width: number;

  @Column({ type: 'int', nullable: true })
  height: number;

  @Column()
  filename: string;

  @CreateDateColumn()
  createdAt: Date;
}
