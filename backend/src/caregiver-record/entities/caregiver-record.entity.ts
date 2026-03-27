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
import { User } from '../../user/entities/user.entity';

@Entity('caregiver_records')
export class CaregiverRecord {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  careRecipientId: string;

  @ManyToOne(() => CareRecipient)
  @JoinColumn({ name: 'careRecipientId' })
  careRecipient: CareRecipient;

  @Column()
  caregiverId: string;

  @ManyToOne(() => User, { eager: true })
  @JoinColumn({ name: 'caregiverId' })
  caregiver: User;

  @Column({ type: 'date' })
  periodStart: Date;

  @Column({ type: 'date', nullable: true })
  periodEnd: Date;

  @Column({ nullable: true, length: 500 })
  note: string;

  @Column({ nullable: true })
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
