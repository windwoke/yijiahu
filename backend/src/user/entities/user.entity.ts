import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
} from 'typeorm';
import { FamilyMember } from '../../family/entities/family-member.entity';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true, nullable: true })
  phone: string;

  @Column({ nullable: true })
  name: string;

  @Column({ nullable: true })
  avatar: string;

  @Column({ nullable: true })
  hashedPassword: string;

  @Column({ nullable: true })
  lastLoginAt: Date;

  @Column({ nullable: true })
  pushToken: string;

  // ─── 微信绑定字段 ───────────────────────────────────────────────
  /** 微信小程序 OpenId（唯一） */
  @Column({ nullable: true, unique: true })
  openId: string;

  /** 微信 UnionId（需绑定微信开放平台） */
  @Column({ nullable: true })
  wechatUnionId: string;

  /** 微信昵称（微信用户默认展示名） */
  @Column({ nullable: true })
  wechatNickname: string;

  /** 微信头像 URL */
  @Column({ nullable: true })
  wechatAvatar: string;
  // ───────────────────────────────────────────────────────────────

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @OneToMany(() => FamilyMember, (fm) => fm.user)
  familyMembers: FamilyMember[];
}
