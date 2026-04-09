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

@Entity('care_recipients')
export class CareRecipient {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  familyId: string;

  @Column()
  name: string;

  @Column({ nullable: true })
  avatarEmoji: string;

  @Column({ nullable: true })
  avatarUrl: string;

  @Column({ nullable: true })
  phone: string; // 照护对象本人的手机号

  @Column({ nullable: true })
  gender: 'male' | 'female';

  @Column({ nullable: true })
  birthDate: Date;

  @Column({ nullable: true })
  bloodType: string;

  @Column({ type: 'simple-array', nullable: true })
  allergies: string[];

  @Column({ type: 'simple-array', nullable: true })
  chronicConditions: string[];

  @Column({ type: 'text', nullable: true })
  medicalHistory: string;

  @Column({ nullable: true })
  hospital: string;

  @Column({ nullable: true })
  department: string;

  @Column({ nullable: true })
  doctorName: string;

  @Column({ nullable: true })
  doctorPhone: string;

  @Column({ nullable: true })
  emergencyContact: string;

  @Column({ nullable: true })
  emergencyPhone: string;

  @Column({ nullable: true })
  currentAddress: string;

  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true })
  latitude: number;

  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true })
  longitude: number;

  @Column({ default: true })
  isActive: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @DeleteDateColumn()
  deletedAt: Date;

  @ManyToOne(() => Family, (f) => f.careRecipients)
  @JoinColumn({ name: 'familyId' })
  family: Family;
}
