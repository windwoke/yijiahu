import { Controller, Get, Post, Patch, Delete, Body, Param, Query, UseGuards, BadRequestException } from '@nestjs/common';
import { ApiBearerAuth, ApiTags, ApiOperation } from '@nestjs/swagger';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { PermissionService } from '../common/services/permission.service';
import { CareRecipientService } from './care-recipient.service';
import { SubscriptionService } from '../subscription/subscription.service';
import { FamilyMember, FamilyMemberRole } from '../family/entities/family-member.entity';
import { CreateCareRecipientDto, UpdateCareRecipientDto } from './dto/care-recipient.dto';

@ApiTags('照护对象')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('care-recipients')
export class CareRecipientController {
  constructor(
    private readonly service: CareRecipientService,
    private readonly subscriptionService: SubscriptionService,
    private readonly permission: PermissionService,
    @InjectRepository(FamilyMember) private memberRepo: Repository<FamilyMember>,
  ) {}

  @Post()
  @ApiOperation({ summary: '添加照护对象' })
  async create(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateCareRecipientDto,
    @Query('familyId') familyId?: string,
  ) {
    let resolvedFamilyId: string;
    if (familyId) {
      await this.permission.requireRole(userId, familyId, [
        FamilyMemberRole.OWNER,
        FamilyMemberRole.COORDINATOR,
      ]);
      resolvedFamilyId = familyId;
    } else {
      // 兼容未传 familyId：查用户所在第一个家庭
      const member = await this.memberRepo.findOne({ where: { userId } });
      if (!member) throw new BadRequestException('请先加入一个家庭');
      await this.permission.requireRole(userId, member.familyId, [
        FamilyMemberRole.OWNER,
        FamilyMemberRole.COORDINATOR,
      ]);
      resolvedFamilyId = member.familyId;
    }
    await this.subscriptionService.checkQuota(resolvedFamilyId, 'recipient');
    return this.service.create(resolvedFamilyId, dto);
  }

  @Get()
  @ApiOperation({ summary: '获取家庭照护对象列表' })
  findByFamily(@Query('familyId') familyId: string) {
    return this.service.findByFamily(familyId);
  }

  @Get(':id')
  @ApiOperation({ summary: '获取照护对象详情' })
  findOne(@Param('id') id: string, @Query('familyId') familyId: string) {
    return this.service.findOne(id, familyId);
  }

  @Patch(':id')
  @ApiOperation({ summary: '更新照护对象' })
  async update(
    @Param('id') id: string,
    @Query('familyId') familyId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: UpdateCareRecipientDto,
  ) {
    await this.permission.requireRole(userId, familyId, [
      FamilyMemberRole.OWNER,
      FamilyMemberRole.COORDINATOR,
    ]);
    return this.service.update(id, familyId, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: '删除照护对象' })
  async delete(
    @Param('id') id: string,
    @Query('familyId') familyId: string,
    @CurrentUser('id') userId: string,
  ) {
    await this.permission.requireRole(userId, familyId, [
      FamilyMemberRole.OWNER,
      FamilyMemberRole.COORDINATOR,
    ]);
    return this.service.delete(id, familyId);
  }
}
