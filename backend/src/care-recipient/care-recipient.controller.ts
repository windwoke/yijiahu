import { Controller, Get, Post, Patch, Delete, Body, Param, Query, UseGuards, BadRequestException } from '@nestjs/common';
import { ApiBearerAuth, ApiTags, ApiOperation } from '@nestjs/swagger';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CareRecipientService } from './care-recipient.service';
import { SubscriptionService } from '../subscription/subscription.service';
import { FamilyMember } from '../family/entities/family-member.entity';
import { CreateCareRecipientDto, UpdateCareRecipientDto } from './dto/care-recipient.dto';

@ApiTags('照护对象')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('care-recipients')
export class CareRecipientController {
  constructor(
    private readonly service: CareRecipientService,
    private readonly subscriptionService: SubscriptionService,
    @InjectRepository(FamilyMember) private memberRepo: Repository<FamilyMember>,
  ) {}

  @Post()
  @ApiOperation({ summary: '添加照护对象' })
  async create(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateCareRecipientDto,
    @Query('familyId') familyId?: string,
  ) {
    if (familyId) {
      // 验证用户是否属于该家庭
      const member = await this.memberRepo.findOne({ where: { userId, familyId } });
      if (!member) throw new BadRequestException('无权操作此家庭');
      // 检查照护对象配额
      await this.subscriptionService.checkQuota(familyId, 'recipient');
      return this.service.create(familyId, dto);
    }
    // 兼容未传 familyId：查用户所在第一个家庭
    const member = await this.memberRepo.findOne({ where: { userId } });
    if (!member) throw new BadRequestException('请先加入一个家庭');
    // 检查照护对象配额
    await this.subscriptionService.checkQuota(member.familyId, 'recipient');
    return this.service.create(member.familyId, dto);
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
  update(
    @Param('id') id: string,
    @Query('familyId') familyId: string,
    @Body() dto: UpdateCareRecipientDto,
  ) {
    return this.service.update(id, familyId, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: '删除照护对象' })
  delete(@Param('id') id: string, @Query('familyId') familyId: string) {
    return this.service.delete(id, familyId);
  }
}
