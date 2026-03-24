import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
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
  avatar: string;

  @Column({ nullable: true })
  gender: 'male' | 'female';

  @Column({ nullable: true })
  birthDate: Date;

  @Column({ nullable: true })
  relation: string; // 如"爷爷"、"奶奶"

  @Column({ type: 'text', nullable: true })
  allergies: string; // 过敏药物

  @Column({ type: 'text', nullable: true })
  chronicDiseases: string; // 慢性病

  @Column({ type: 'text', nullable: true })
  medications: string; // 当前用药

  @Column({ type: 'text', nullable: true })
  emergencyContact: string; // 紧急联系人

  @Column({ nullable: true })
  emergencyPhone: string; // 紧急联系电话

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @ManyToOne(() => Family, (f) => f.careRecipients)
  @JoinColumn({ name: 'familyId' })
  family: Family;
}
