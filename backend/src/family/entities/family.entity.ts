import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
} from 'typeorm';
import { FamilyMember } from './family-member.entity';
import { CareRecipient } from '../../care-recipient/entities/care-recipient.entity';

export enum SubscriptionPlan {
  FREE = 'free',
  PREMIUM = 'premium',
  ANNUAL = 'annual',
}

@Entity('families')
export class Family {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column({ unique: true })
  inviteCode: string;

  @Column({
    type: 'enum',
    enum: SubscriptionPlan,
    default: SubscriptionPlan.FREE,
  })
  subscriptionPlan: SubscriptionPlan;

  @Column({ nullable: true })
  subscriptionExpiresAt: Date;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @OneToMany(() => FamilyMember, (fm) => fm.family)
  members: FamilyMember[];

  @OneToMany(() => CareRecipient, (cr) => cr.family)
  careRecipients: CareRecipient[];
}
