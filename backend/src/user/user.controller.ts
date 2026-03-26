import { Controller, Get, Patch, Body, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags, ApiOperation } from '@nestjs/swagger';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { UserService } from './user.service';
import { FamilyMember } from '../family/entities/family-member.entity';
import { Family } from '../family/entities/family.entity';
import { CareRecipient } from '../care-recipient/entities/care-recipient.entity';
import { FamilyService } from '../family/family.service';

@ApiTags('用户')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('users')
export class UserController {
  constructor(
    private readonly userService: UserService,
    @InjectRepository(FamilyMember) private memberRepo: Repository<FamilyMember>,
    @InjectRepository(Family) private familyRepo: Repository<Family>,
    @InjectRepository(CareRecipient) private recipientRepo: Repository<CareRecipient>,
    private readonly familyService: FamilyService,
  ) {}

  @Get('me')
  @ApiOperation({ summary: '获取当前用户信息' })
  getMe(@CurrentUser('id') userId: string) {
    return this.userService.findById(userId);
  }

  @Get('me/family')
  @ApiOperation({ summary: '获取当前用户所在家庭' })
  async getMyFamily(@CurrentUser('id') userId: string) {
    const members = await this.memberRepo.find({ where: { userId } });

    // 优先返回有照护对象的家庭
    for (const member of members) {
      const hasRecipients = await this.recipientRepo.count({
        where: { familyId: member.familyId },
      });
      if (hasRecipients > 0) {
        const family = await this.familyRepo.findOne({ where: { id: member.familyId } });
        if (family) return { family };
      }
    }

    // 没有照护对象则返回第一个
    if (members.length > 0) {
      const firstMember = members[0];
      const family = await this.familyRepo.findOne({ where: { id: firstMember.familyId } });
      if (family) return { family };
    }

    // 新用户：自动创建家庭
    const family = await this.familyService.create(userId, { name: '我的家庭' });
    return { family };
  }

  @Get('me/families')
  @ApiOperation({ summary: '获取当前用户所有家庭列表' })
  async getMyFamilies(@CurrentUser('id') userId: string) {
    const members = await this.memberRepo.find({ where: { userId } });
    if (members.length === 0) return { families: [] };

    const familyIds = members.map((m) => m.familyId);
    const families = await this.familyRepo
      .createQueryBuilder('family')
      .where('family.id IN (:...ids)', { ids: familyIds })
      .getMany();

    const result = families.map((f) => ({
      family: f,
      role: members.find((m) => m.familyId === f.id)?.role,
    }));

    return { families: result };
  }

  @Patch('me')
  @ApiOperation({ summary: '更新当前用户信息' })
  updateMe(@CurrentUser('id') userId: string, @Body() body: Record<string, unknown>) {
    return this.userService.update(userId, body);
  }
}
