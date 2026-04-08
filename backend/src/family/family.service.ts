import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Family, SubscriptionPlan } from './entities/family.entity';
import {
  FamilyMember,
  FamilyMemberRole,
} from './entities/family-member.entity';
import { User } from '../user/entities/user.entity';
import { SubscriptionService } from '../subscription/subscription.service';
import {
  CreateFamilyDto,
  UpdateFamilyDto,
  JoinFamilyDto,
  UpdateMemberDto,
} from './dto/family.dto';
import { NotificationService } from '../notification/notification.service';

@Injectable()
export class FamilyService {
  constructor(
    @InjectRepository(Family) private familyRepo: Repository<Family>,
    @InjectRepository(FamilyMember)
    private memberRepo: Repository<FamilyMember>,
    private subscriptionService: SubscriptionService,
    private readonly notifSvc: NotificationService,
  ) {}

  private generateInviteCode(): string {
    return Math.random().toString(36).slice(2, 8).toUpperCase();
  }

  private getMaxFamilies(family: Family): number {
    switch (family.subscriptionPlan) {
      case SubscriptionPlan.PREMIUM:
        return 5;
      case SubscriptionPlan.ANNUAL:
        return 10;
      default:
        return 1;
    }
  }

  async create(userId: string, dto: CreateFamilyDto) {
    // 检查用户是否已在家庭中（基础版限制 1 个家庭）
    const existingFamilies = await this.memberRepo.find({ where: { userId } });
    if (existingFamilies.length > 0) {
      // 查第一个家庭的配额信息
      const firstFamily = await this.familyRepo.findOne({
        where: { id: existingFamilies[0].familyId },
      });
      const maxFamilies = firstFamily ? this.getMaxFamilies(firstFamily) : 1;
      if (existingFamilies.length >= maxFamilies) {
        throw new BadRequestException(
          '基础版最多 1 个家庭，请升级会员创建更多家庭',
        );
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
    const user = await this.memberRepo.manager
      .getRepository(User)
      .findOne({ where: { id: userId } });
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
    const family = await this.familyRepo.findOne({
      where: { inviteCode: dto.inviteCode },
    });
    if (!family) throw new NotFoundException('邀请码无效');

    const existing = await this.memberRepo.findOne({
      where: { familyId: family.id, userId },
    });
    if (existing) throw new BadRequestException('您已在该家庭中');

    // 检查成员配额
    await this.subscriptionService.checkQuota(family.id, 'member');

    const user = await this.memberRepo.manager
      .getRepository(User)
      .findOne({ where: { id: userId } });
    const member = this.memberRepo.create({
      familyId: family.id,
      userId,
      nickname: user?.name || '家庭成员',
      role: FamilyMemberRole.CAREGIVER,
    });
    await this.memberRepo.save(member);

    // 通知其他成员
    this.notifSvc
      .notifyMemberJoined(family.id, userId, member.nickname, member.role, {
        familyId: family.id,
      })
      .catch(() => {});

    return this.findById(family.id, userId);
  }

  async leave(familyId: string, userId: string) {
    const member = await this.memberRepo.findOne({
      where: { familyId, userId },
    });
    if (!member) throw new NotFoundException('您不是该家庭成员');
    if (member.role === FamilyMemberRole.OWNER) {
      throw new BadRequestException('创建者不能退出家庭，请先转让管理员权限');
    }
    // coordinator 退出保护：不能移除最后一个 owner/coordinator
    if (member.role === FamilyMemberRole.COORDINATOR) {
      const others = await this.memberRepo.find({
        where: { familyId },
      });
      const elevated = others.filter(
        (m) =>
          m.id !== member.id &&
          (m.role === FamilyMemberRole.OWNER ||
            m.role === FamilyMemberRole.COORDINATOR),
      );
      if (elevated.length === 0) {
        throw new BadRequestException(
          '您是当前唯一管理员，无法退出。请先指定其他成员为管理员',
        );
      }
    }
    await this.memberRepo.delete(member.id);
    return { message: '已退出家庭' };
  }

  async removeMember(familyId: string, memberId: string, userId: string) {
    const target = await this.memberRepo.findOne({
      where: { id: memberId, familyId },
    });
    if (!target) throw new NotFoundException('成员不存在');

    // 只有 owner 或 coordinator 可以移除他人
    await this.requireRole(familyId, userId, [
      FamilyMemberRole.OWNER,
      FamilyMemberRole.COORDINATOR,
    ]);

    // 不能移除 owner
    if (target.role === FamilyMemberRole.OWNER) {
      throw new BadRequestException('不能移除管理员');
    }

    // 不能移除自己（移除自己用 leave 接口）
    if (target.userId === userId) {
      throw new BadRequestException('移除自己请使用"退出家庭"');
    }

    // coordinator 移除保护：不能移除最后一个 owner/coordinator
    const myMember = await this.memberRepo.findOne({
      where: { familyId, userId },
    });
    if (
      myMember?.role === FamilyMemberRole.COORDINATOR &&
      target.role === FamilyMemberRole.COORDINATOR
    ) {
      const others = await this.memberRepo.find({ where: { familyId } });
      const elevated = others.filter(
        (m) =>
          m.id !== target.id &&
          (m.role === FamilyMemberRole.OWNER ||
            m.role === FamilyMemberRole.COORDINATOR),
      );
      if (elevated.length === 0) {
        throw new BadRequestException(
          '移除后家庭将没有管理员，请先指定其他成员为管理员',
        );
      }
    }

    await this.memberRepo.delete(target.id);

    // 通知被移除的成员
    if (target.userId) {
      const family = await this.familyRepo.findOne({ where: { id: familyId } });
      const operator = await this.memberRepo.findOne({
        where: { familyId, userId },
      });
      const operatorName = operator?.nickname || '管理员';
      const familyName = family?.name || '家庭';
      this.notifSvc
        .notifyMemberLeft(target.userId, familyName, operatorName, { familyId })
        .catch(() => {});
    }

    return { message: '已移除成员' };
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
    // 成员头像：统一取 User.avatar（用户头像）
    return members.map((m) => ({
      ...m,
      avatarUrl: m.user?.avatar || null,
      userName: m.user?.name || null,
      phone: m.user?.phone || null,
    }));
  }

  async updateMember(
    familyId: string,
    memberId: string,
    userId: string,
    dto: UpdateMemberDto,
  ) {
    const target = await this.memberRepo.findOne({
      where: { id: memberId, familyId },
    });
    if (!target) throw new NotFoundException('成员不存在');

    // 判断操作者身份
    const myMember = await this.memberRepo.findOne({
      where: { familyId, userId },
    });
    const _myRole = myMember?.role;
    const isSelfEdit = target.userId === userId;

    if (isSelfEdit) {
      // 自己只能修改昵称和头像，不能改角色
      if (dto.nickname !== undefined) target.nickname = dto.nickname;
      if (dto.avatarUrl !== undefined) target.avatarUrl = dto.avatarUrl;
    } else {
      // 其他人：需要 owner 或 coordinator 权限
      await this.requireRole(familyId, userId, [
        FamilyMemberRole.OWNER,
        FamilyMemberRole.COORDINATOR,
      ]);
      Object.assign(target, dto);
      // 不能把自己的 owner 角色降级
      if (
        target.role === FamilyMemberRole.OWNER &&
        dto.role &&
        dto.role !== FamilyMemberRole.OWNER
      ) {
        throw new BadRequestException('不能修改管理员的身份');
      }
    }

    return this.memberRepo.save(target);
  }

  private async requireRole(
    familyId: string,
    userId: string,
    roles: FamilyMemberRole[] = [
      FamilyMemberRole.OWNER,
      FamilyMemberRole.COORDINATOR,
    ],
  ) {
    const member = await this.memberRepo.findOne({
      where: { familyId, userId },
    });
    if (!member) throw new NotFoundException('您不是该家庭成员');
    if (!roles.includes(member.role)) {
      throw new BadRequestException('您没有权限执行此操作');
    }
  }
}
