import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Family, SubscriptionPlan } from './entities/family.entity';
import { FamilyMember, FamilyMemberRole } from './entities/family-member.entity';
import { User } from '../user/entities/user.entity';
import { SubscriptionService } from '../subscription/subscription.service';
import { CreateFamilyDto, UpdateFamilyDto, JoinFamilyDto, UpdateMemberDto } from './dto/family.dto';

@Injectable()
export class FamilyService {
  constructor(
    @InjectRepository(Family) private familyRepo: Repository<Family>,
    @InjectRepository(FamilyMember) private memberRepo: Repository<FamilyMember>,
    private subscriptionService: SubscriptionService,
  ) {}

  private generateInviteCode(): string {
    return Math.random().toString(36).slice(2, 8).toUpperCase();
  }

  private getMaxFamilies(family: Family): number {
    switch (family.subscriptionPlan) {
      case SubscriptionPlan.PREMIUM: return 5;
      case SubscriptionPlan.ANNUAL: return 10;
      default: return 1;
    }
  }

  async create(userId: string, dto: CreateFamilyDto) {
    // 检查用户是否已在家庭中（基础版限制 1 个家庭）
    const existingFamilies = await this.memberRepo.find({ where: { userId } });
    if (existingFamilies.length > 0) {
      // 查第一个家庭的配额信息
      const firstFamily = await this.familyRepo.findOne({ where: { id: existingFamilies[0].familyId } });
      const maxFamilies = firstFamily ? this.getMaxFamilies(firstFamily) : 1;
      if (existingFamilies.length >= maxFamilies) {
        throw new BadRequestException('基础版最多 1 个家庭，请升级会员创建更多家庭');
      }
    }

    // 创建家庭
    const family = this.familyRepo.create({
      name: dto.name,
      inviteCode: this.generateInviteCode(),
      subscriptionPlan: SubscriptionPlan.FREE,
    });
    await this.familyRepo.save(family);

    // 创建者自动成为 owner
    const user = await this.memberRepo.manager.getRepository(User).findOne({ where: { id: userId } });
    const member = this.memberRepo.create({
      familyId: family.id,
      userId,
      nickname: user?.name || '家庭成员',
      role: FamilyMemberRole.OWNER,
    });
    await this.memberRepo.save(member);

    return this.findById(family.id, userId);
  }

  async findById(familyId: string, userId: string) {
    const family = await this.familyRepo.findOne({ where: { id: familyId } });
    if (!family) throw new NotFoundException('家庭不存在');

    const members = await this.memberRepo.find({
      where: { familyId },
      relations: ['user'],
    });
    const myMember = members.find((m) => m.userId === userId);

    return {
      ...family,
      myRole: myMember?.role,
      memberCount: members.length,
    };
  }

  async update(familyId: string, userId: string, dto: UpdateFamilyDto) {
    await this.requireRole(familyId, userId, [FamilyMemberRole.OWNER]);
    await this.familyRepo.update(familyId, dto);
    return this.findById(familyId, userId);
  }

  async join(userId: string, dto: JoinFamilyDto) {
    const family = await this.familyRepo.findOne({ where: { inviteCode: dto.inviteCode } });
    if (!family) throw new NotFoundException('邀请码无效');

    const existing = await this.memberRepo.findOne({ where: { familyId: family.id, userId } });
    if (existing) throw new BadRequestException('您已在该家庭中');

    // 检查成员配额
    await this.subscriptionService.checkQuota(family.id, 'member');

    const user = await this.memberRepo.manager.getRepository(User).findOne({ where: { id: userId } });
    const member = this.memberRepo.create({
      familyId: family.id,
      userId,
      nickname: user?.name || '家庭成员',
      role: FamilyMemberRole.CAREGIVER,
    });
    await this.memberRepo.save(member);

    return this.findById(family.id, userId);
  }

  async leave(familyId: string, userId: string) {
    const member = await this.memberRepo.findOne({ where: { familyId, userId } });
    if (!member) throw new NotFoundException('您不是该家庭成员');
    if (member.role === FamilyMemberRole.OWNER) {
      throw new BadRequestException('创建者不能退出家庭，请先转让管理员权限');
    }
    await this.memberRepo.delete(member.id);
    return { message: '已退出家庭' };
  }

  async findMembers(familyId: string, userId: string) {
    await this.requireRole(familyId, userId, [
      FamilyMemberRole.OWNER,
      FamilyMemberRole.COORDINATOR,
      FamilyMemberRole.CAREGIVER,
      FamilyMemberRole.GUEST,
    ]);
    const members = await this.memberRepo.find({
      where: { familyId },
      relations: ['user'],
      order: { joinedAt: 'ASC' },
    });
    // 统一 avatarUrl：优先用 FamilyMember.avatarUrl，否则 fallback 到 User.avatar
    return members.map((m) => ({
      ...m,
      avatarUrl: m.avatarUrl || m.user?.avatar || null,
    }));
  }

  async updateMember(familyId: string, memberId: string, userId: string, dto: UpdateMemberDto) {
    const target = await this.memberRepo.findOne({ where: { id: memberId, familyId } });
    if (!target) throw new NotFoundException('成员不存在');

    // 判断操作者身份
    const myMember = await this.memberRepo.findOne({ where: { familyId, userId } });
    const myRole = myMember?.role as FamilyMemberRole | undefined;
    const isSelfEdit = target.userId === userId;

    if (isSelfEdit) {
      // 自己只能修改昵称和头像，不能改角色
      if (dto.nickname !== undefined) target.nickname = dto.nickname;
      if (dto.avatarUrl !== undefined) target.avatarUrl = dto.avatarUrl;
    } else {
      // 其他人：需要 owner 或 coordinator 权限
      await this.requireRole(familyId, userId, [FamilyMemberRole.OWNER, FamilyMemberRole.COORDINATOR]);
      Object.assign(target, dto);
      // 不能把自己的 owner 角色降级
      if (target.role === FamilyMemberRole.OWNER && dto.role && dto.role !== FamilyMemberRole.OWNER) {
        throw new BadRequestException('不能修改管理员的身份');
      }
    }

    return this.memberRepo.save(target);
  }

  private async requireRole(
    familyId: string,
    userId: string,
    roles: FamilyMemberRole[] = [FamilyMemberRole.OWNER, FamilyMemberRole.COORDINATOR],
  ) {
    const member = await this.memberRepo.findOne({ where: { familyId, userId } });
    if (!member) throw new NotFoundException('您不是该家庭成员');
    if (!roles.includes(member.role)) {
      throw new BadRequestException('您没有权限执行此操作');
    }
  }
}
