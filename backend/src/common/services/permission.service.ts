import { Injectable, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  FamilyMember,
  FamilyMemberRole,
} from '../../family/entities/family-member.entity';

@Injectable()
export class PermissionService {
  constructor(
    @InjectRepository(FamilyMember)
    private memberRepo: Repository<FamilyMember>,
  ) {}

  /** 获取用户在家庭中的角色（null 表示不是成员） */
  async getMemberRole(
    userId: string,
    familyId: string,
  ): Promise<FamilyMemberRole | null> {
    const member = await this.memberRepo.findOne({
      where: { userId, familyId },
    });
    return member?.role ?? null;
  }

  /** 检查用户是否属于家庭 */
  async isMember(userId: string, familyId: string): Promise<boolean> {
    const member = await this.memberRepo.findOne({
      where: { userId, familyId },
    });
    return !!member;
  }

  /** 检查用户是否具有允许的角色之一 */
  async hasRole(
    userId: string,
    familyId: string,
    allowedRoles: FamilyMemberRole[],
  ): Promise<boolean> {
    const role = await this.getMemberRole(userId, familyId);
    return role !== null && allowedRoles.includes(role);
  }

  /** 权限断言：用户必须有允许的角色之一，否则抛出 ForbiddenException */
  async requireRole(
    userId: string,
    familyId: string,
    allowedRoles: FamilyMemberRole[],
  ): Promise<FamilyMemberRole> {
    const role = await this.getMemberRole(userId, familyId);
    if (!role) {
      throw new ForbiddenException('您不是该家庭成员');
    }
    if (!allowedRoles.includes(role)) {
      throw new ForbiddenException('您没有权限执行此操作');
    }
    return role;
  }

  /** 检查用户是否能管理家庭设置（仅 owner） */
  async canManageFamily(userId: string, familyId: string): Promise<boolean> {
    return this.hasRole(userId, familyId, [FamilyMemberRole.OWNER]);
  }

  /** 检查用户是否能管理成员（owner + coordinator） */
  async canManageMembers(userId: string, familyId: string): Promise<boolean> {
    return this.hasRole(userId, familyId, [
      FamilyMemberRole.OWNER,
      FamilyMemberRole.COORDINATOR,
    ]);
  }

  /** 检查用户是否能创建复诊（owner + coordinator） */
  async canCreateAppointment(
    userId: string,
    familyId: string,
  ): Promise<boolean> {
    return this.hasRole(userId, familyId, [
      FamilyMemberRole.OWNER,
      FamilyMemberRole.COORDINATOR,
    ]);
  }

  /** 检查用户是否能管理照护对象（owner + coordinator） */
  async canManageRecipients(
    userId: string,
    familyId: string,
  ): Promise<boolean> {
    return this.hasRole(userId, familyId, [
      FamilyMemberRole.OWNER,
      FamilyMemberRole.COORDINATOR,
    ]);
  }

  /** 检查用户是否能完成任务
   * - owner/coordinator: 可以完成任何任务
   * - caregiver: 只能完成分配给自己的任务
   */
  async canCompleteTask(
    userId: string,
    familyId: string,
    assigneeId: string,
  ): Promise<boolean> {
    const role = await this.getMemberRole(userId, familyId);
    if (!role) return false;
    if ([FamilyMemberRole.OWNER, FamilyMemberRole.COORDINATOR].includes(role))
      return true;
    if (role === FamilyMemberRole.CAREGIVER) return userId === assigneeId;
    return false;
  }

  /** 检查用户是否能添加健康记录（owner + coordinator + caregiver，不含 guest） */
  async canAddHealthRecord(userId: string, familyId: string): Promise<boolean> {
    return this.hasRole(userId, familyId, [
      FamilyMemberRole.OWNER,
      FamilyMemberRole.COORDINATOR,
      FamilyMemberRole.CAREGIVER,
    ]);
  }
}
