import { Controller, Get, Post, Body, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags, ApiOperation } from '@nestjs/swagger';
import { HealthRecordService } from './health-record.service';
import { CreateHealthRecordDto } from './dto/health-record.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { PermissionService } from '../common/services/permission.service';
import { FamilyMemberRole } from '../family/entities/family-member.entity';

@ApiTags('健康记录')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('health-records')
export class HealthRecordController {
  constructor(
    private readonly service: HealthRecordService,
    private readonly permission: PermissionService,
  ) {}

  @Post()
  @ApiOperation({ summary: '添加健康记录' })
  async create(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateHealthRecordDto,
  ) {
    // guest 不能添加健康记录
    await this.permission.requireRole(userId, dto.familyId, [
      FamilyMemberRole.OWNER,
      FamilyMemberRole.COORDINATOR,
      FamilyMemberRole.CAREGIVER,
    ]);
    return this.service.create(dto, userId);
  }

  @Get()
  @ApiOperation({ summary: '获取健康记录列表' })
  findByRecipient(
    @Query('recipientId') recipientId: string,
    @Query('familyId') familyId: string,
    @Query('recordType') recordType?: string,
    @Query('days') days?: string,
  ) {
    return this.service.findByRecipient(
      recipientId,
      familyId,
      recordType,
      days ? parseInt(days, 10) : 7,
    );
  }

  @Get('trends')
  @ApiOperation({ summary: '获取健康趋势（血压+血糖）' })
  getTrends(
    @Query('recipientId') recipientId: string,
    @Query('familyId') familyId: string,
    @Query('days') days?: string,
  ) {
    return this.service.getTrends(
      recipientId,
      familyId,
      days ? parseInt(days, 10) : 7,
    );
  }

  @Get('recent')
  @ApiOperation({ summary: '获取最近健康记录（用于时间线）' })
  getRecent(
    @Query('recipientId') recipientId?: string,
    @Query('days') days?: string,
    @Query('limit') limit?: string,
    @Query('familyId') familyId?: string,
  ) {
    return this.service.findRecent(
      recipientId,
      days ? parseInt(days, 10) : 7,
      limit ? parseInt(limit, 10) : 20,
      familyId,
    );
  }
}
