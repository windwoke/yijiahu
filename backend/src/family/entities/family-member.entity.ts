import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { User } from '../../user/entities/user.entity';
import { Family } from './family.entity';

export enum FamilyMemberRole {
  OWNER = 'owner',
  ADMIN = 'admin',
  MEMBER = 'member',
  VIEWER = 'viewer',
}

@Entity('family_members')
export class FamilyMember {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  familyId: string;

  @Column({ nullable: true })
  userId: string;

  @Column()
  nickname: string;

  @Column({
    type: 'enum',
    enum: FamilyMemberRole,
    default: FamilyMemberRole.MEMBER,
  })
  role: FamilyMemberRole;

  @Column({ nullable: true })
  avatarUrl: string;

  @ManyToOne(() => Family, (f) => f.members)
  @JoinColumn({ name: 'familyId' })
  family: Family;

  @ManyToOne(() => User, (u) => u.familyMembers, { nullable: true })
  @JoinColumn({ name: 'userId' })
  user: User;

  @CreateDateColumn()
  joinedAt: Date;
}
