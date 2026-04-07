/**
 * 家庭模型
 * 对应后端 Family 实体
 */

/** 家庭成员角色 */
export enum FamilyMemberRole {
  OWNER = 'owner',
  COORDINATOR = 'coordinator',
  CAREGIVER = 'caregiver',
  GUEST = 'guest',
}

export const FAMILY_ROLE_LABELS: Record<FamilyMemberRole, string> = {
  [FamilyMemberRole.OWNER]: '管理员',
  [FamilyMemberRole.COORDINATOR]: '协调管理员',
  [FamilyMemberRole.CAREGIVER]: '照护人',
  [FamilyMemberRole.GUEST]: '访客',
};

export interface FamilyMember {
  id: string;
  userId: string;
  familyId: string;
  nickname: string;
  role: FamilyMemberRole;
  avatarUrl?: string | null;
}

export interface SubscriptionFeatures {
  maxMembers: number;
  maxRecipients: number;
  sosEnabled: boolean;
  healthTrendEnabled: boolean;
  advanceCarePlanEnabled: boolean;
}

export interface SubscriptionStatus {
  plan: 'free' | 'premium' | 'annual';
  features: SubscriptionFeatures;
  expiresAt: string | null;
}

export interface Family {
  id: string;
  name: string;
  avatarUrl: string | null;
  description: string | null;
  inviteCode: string;
  /** 当前用户在家庭中的角色（后端返回 myRole） */
  myRole: FamilyMemberRole;
  subscriptionPlan: string;
  subscriptionExpiresAt: string | null;
  memberCount: number;
  recipientCount: number;
  createdAt: string;
}

export interface FamilyMemberDetail extends FamilyMember {
  joinedAt: string;
  /** 真实姓名（来自 User.name，与 nickname 不同时显示） */
  userName?: string | null;
  /** 手机号（来自 User.phone） */
  phone?: string | null;
  /** 头像（优先 FamilyMember.avatarUrl，否则 User.avatar） */
  avatarUrl?: string | null;
  /** 成员是否在线（最近活跃） */
  isOnline?: boolean;
}
