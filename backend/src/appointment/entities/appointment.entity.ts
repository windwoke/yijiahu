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
import { Family } from '../../family/entities/family.entity';

export enum AppointmentStatus {
  UPCOMING = 'upcoming',
  COMPLETED = 'completed',
  CANCELLED = 'cancelled',
}

@Entity('appointments')
export class Appointment {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  recipientId: string;

  @ManyToOne(() => CareRecipient, { eager: true })
  @JoinColumn({ name: 'recipientId' })
  recipient: CareRecipient;

  @Column({ nullable: true })
  familyId: string;

  @ManyToOne(() => Family)
  @JoinColumn({ name: 'familyId' })
  family: Family;

  @Column()
  hospital: string;

  @Column({ nullable: true })
  department: string;

  @Column({ nullable: true })
  doctorName: string;

  @Column({ nullable: true })
  doctorPhone: string;

  @Column({ type: 'timestamptz' })
  appointmentTime: Date;

  @Column({ nullable: true })
  appointmentNo: string;

  @Column({ nullable: true })
  address: string;

  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true })
  latitude: number;

  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true })
  longitude: number;

  @Column({ type: 'decimal', precision: 10, scale: 2, nullable: true })
  fee: number;

  @Column({ nullable: true })
  purpose: string;

  @Column({ type: 'varchar', default: AppointmentStatus.UPCOMING })
  status: AppointmentStatus;

  @Column({ nullable: true })
  assignedDriverId: string;

  @ManyToOne(() => User, { eager: true, nullable: true })
  @JoinColumn({ name: 'assignedDriverId' })
  assignedDriver: User;

  @Column({ default: true })
  reminder48h: boolean;

  @Column({ default: true })
  reminder24h: boolean;

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
