/**
 * 家庭模型
 * 对应后端 Family 实体
 */

/** 家庭成员角色 */
export enum FamilyMemberRole {
  OWNER = 'owner',       // 所有者
  COORDINATOR = 'coordinator', // 协调者
  CAREGIVER = 'caregiver',     // 照护者
  GUEST = 'guest',           // 访客
}

export const FAMILY_ROLE_LABELS: Record<FamilyMemberRole, string> = {
  [FamilyMemberRole.OWNER]: '所有者',
  [FamilyMemberRole.COORDINATOR]: '协调者',
  [FamilyMemberRole.CAREGIVER]: '照护者',
  [FamilyMemberRole.GUEST]: '访客',
};

export interface FamilyMember {
  id: string;
  userId: string;
  familyId: string;
  role: FamilyMemberRole;
  user: {
    id: string;
    name: string | null;
    phone: string;
    avatar: string | null;
  };
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
  role: FamilyMemberRole;
  subscriptionPlan: string;
  subscriptionExpiresAt: string | null;
  memberCount: number;
  recipientCount: number;
  createdAt: string;
}

export interface FamilyMemberDetail extends FamilyMember {
  joinedAt: string;
  user: {
    id: string;
    name: string | null;
    phone: string;
    avatar: string | null;
  };
}
