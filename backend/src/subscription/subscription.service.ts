import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Subscription, SubscriptionStatus } from './entities/subscription.entity';
import { Family, SubscriptionPlan } from '../family/entities/family.entity';
import { FamilyMember } from '../family/entities/family-member.entity';
import { CareRecipient } from '../care-recipient/entities/care-recipient.entity';
import {
  CreateSubscriptionDto,
  SubscriptionStatusDto,
  SubscriptionFeaturesDto,
} from './dto/subscription.dto';

@Injectable()
export class SubscriptionService {
  constructor(
    @InjectRepository(Subscription)
    private subRepo: Repository<Subscription>,
    @InjectRepository(Family)
    private familyRepo: Repository<Family>,
    @InjectRepository(FamilyMember)
    private memberRepo: Repository<FamilyMember>,
    @InjectRepository(CareRecipient)
    private recipientRepo: Repository<CareRecipient>,
  ) {}

  /** 查询家庭订阅状态 */
  async getStatus(familyId: string): Promise<SubscriptionStatusDto> {
    const family = await this.familyRepo.findOne({ where: { id: familyId } });
    if (!family) throw new NotFoundException('家庭不存在');

    const status = this.getEffectiveStatus(family);

    return {
      plan: family.subscriptionPlan,
      status,
      expiresAt: family.subscriptionExpiresAt?.toISOString() ?? null,
      features: this.getFeatures(family.subscriptionPlan),
    };
  }

  /** 创建/激活订阅（支付成功后调用） */
  async activate(dto: CreateSubscriptionDto): Promise<Subscription> {
    const family = await this.familyRepo.findOne({ where: { id: dto.familyId } });
    if (!family) throw new NotFoundException('家庭不存在');

    const now = new Date();
    const expiresAt = this.calcExpiresAt(dto.plan, now);

    // 插入订阅记录
    const sub = this.subRepo.create({
      familyId: dto.familyId,
      plan: dto.plan,
      status: SubscriptionStatus.ACTIVE,
      startsAt: now,
      expiresAt,
      paymentPlatform: dto.paymentPlatform,
      paymentTradeNo: dto.paymentTradeNo,
      appleReceipt: dto.appleReceipt,
      wechatPrepayId: dto.wechatPrepayId,
    });
    await this.subRepo.save(sub);

    // 更新家庭订阅字段
    family.subscriptionPlan = dto.plan as SubscriptionPlan;
    family.subscriptionExpiresAt = expiresAt;
    // 基础版限制升级
    family.maxRecipients = dto.plan === 'premium' ? 5 : 10;
    family.maxMembers = dto.plan === 'premium' ? 10 : 20;
    family.maxLogsPerMonth = dto.plan === 'premium' ? 500 : -1; // -1 表示不限
    await this.familyRepo.save(family);

    return sub;
  }

  /** 微信支付回调 */
  async handleWechatNotify(
    tradeNo: string,
    prepayId: string,
  ): Promise<Subscription> {
    const sub = await this.subRepo.findOne({
      where: { wechatPrepayId: prepayId },
      order: { createdAt: 'DESC' },
    });
    if (!sub) throw new NotFoundException('订阅记录不存在');

    sub.paymentTradeNo = tradeNo;
    sub.status = SubscriptionStatus.ACTIVE;
    await this.subRepo.save(sub);

    // 更新家庭订阅字段
    const family = await this.familyRepo.findOne({ where: { id: sub.familyId } });
    if (family) {
      family.subscriptionPlan = sub.plan as SubscriptionPlan;
      family.subscriptionExpiresAt = sub.expiresAt;
      await this.familyRepo.save(family);
    }

    return sub;
  }

  /** 取消订阅（取消但不过期，到期前仍有效） */
  async cancel(familyId: string): Promise<void> {
    const family = await this.familyRepo.findOne({ where: { id: familyId } });
    if (!family) throw new NotFoundException('家庭不存在');

    // 标记最新记录为 cancelled
    const latest = await this.subRepo.findOne({
      where: { familyId, status: SubscriptionStatus.ACTIVE },
      order: { createdAt: 'DESC' },
    });
    if (latest) {
      latest.status = SubscriptionStatus.CANCELLED;
      latest.cancelAt = new Date();
      await this.subRepo.save(latest);
    }
  }

  /** 检查配额（加成员/照护对象时调用） */
  async checkQuota(familyId: string, type: 'member' | 'recipient'): Promise<boolean> {
    const family = await this.familyRepo.findOne({ where: { id: familyId } });
    if (!family) throw new NotFoundException('家庭不存在');

    const status = this.getEffectiveStatus(family);
    if (status === 'free') {
      if (type === 'member') {
        const memberCount = await this.countMembers(familyId);
        if (memberCount >= family.maxMembers) {
          throw new BadRequestException(
            `基础版最多添加 ${family.maxMembers} 位成员，请升级会员`,
          );
        }
      } else {
        const recipientCount = await this.countRecipients(familyId);
        if (recipientCount >= family.maxRecipients) {
          throw new BadRequestException(
            `基础版最多添加 ${family.maxRecipients} 位照护对象，请升级会员`,
          );
        }
      }
    }
    return true;
  }

  private async countMembers(familyId: string): Promise<number> {
    return this.memberRepo.count({ where: { familyId } });
  }

  private async countRecipients(familyId: string): Promise<number> {
    return this.recipientRepo.count({ where: { familyId } });
  }

  private getEffectiveStatus(family: Family): string {
    const plan = family.subscriptionPlan;
    const expiresAt = family.subscriptionExpiresAt;

    if (plan === SubscriptionPlan.FREE) return 'free';
    if (!expiresAt) return 'active';
    if (new Date() > expiresAt) return 'expired';
    return 'active';
  }

  private getFeatures(plan: SubscriptionPlan): SubscriptionFeaturesDto {
    if (plan === SubscriptionPlan.FREE) {
      return {
        maxRecipients: 1,
        maxMembers: 3,
        maxLogsPerMonth: 200,
        maxStorageMB: 500,
        healthReports: false,
        recurrenceReminders: false,
      };
    }
    // Premium 和 Annual 功能相同，区别仅在时长
    return {
      maxRecipients: plan === SubscriptionPlan.PREMIUM ? 5 : 10,
      maxMembers: plan === SubscriptionPlan.PREMIUM ? 10 : 20,
      maxLogsPerMonth: -1,
      maxStorageMB: 5 * 1024, // 5GB
      healthReports: true,
      recurrenceReminders: true,
    };
  }

  private calcExpiresAt(plan: string, from: Date): Date {
    const days = plan === 'annual' ? 365 : 30;
    const d = new Date(from);
    d.setDate(d.getDate() + days);
    return d;
  }
}
