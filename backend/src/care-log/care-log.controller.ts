import { Controller, Get, Post, Query, Body, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { PermissionService } from '../common/services/permission.service';
import { CareLogService } from './care-log.service';
import { CreateCareLogDto } from './dto/care-log.dto';
import { FamilyMemberRole } from '../family/entities/family-member.entity';

@ApiTags('照护日志')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('care-logs')
export class CareLogController {
  constructor(
    private readonly service: CareLogService,
    private readonly permission: PermissionService,
  ) {}

  @Post()
  @ApiOperation({ summary: '创建照护日志' })
  async create(
    @CurrentUser('id') userId: string,
    @Query('familyId') familyId: string,
    @Body() dto: CreateCareLogDto,
  ) {
    // 所有角色都可以记录照护日志（owner/coordinator/caregiver/guest）
    await this.permission.requireRole(userId, familyId, [
      FamilyMemberRole.OWNER,
      FamilyMemberRole.COORDINATOR,
      FamilyMemberRole.CAREGIVER,
      FamilyMemberRole.GUEST,
    ]);
    return this.service.create(familyId, userId, dto);
  }

  @Get()
  @ApiOperation({ summary: '获取照护日志列表' })
  findAll(
    @Query('familyId') familyId: string,
    @Query('recipientId') recipientId?: string,
    @Query('type') type?: string,
    @Query('limit') limit?: string,
    @Query('before') before?: string, // ISO 时间戳，用于分页游标
  ) {
    return this.service.findByFamily(familyId, {
      recipientId,
      type,
      limit: limit ? parseInt(limit, 10) : 50,
      before: before ? new Date(before) : undefined,
    });
  }
}
