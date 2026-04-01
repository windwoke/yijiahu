import {
  Controller,
  Get,
  Post,
  Body,
  Query,
  UseGuards,
  Request,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { PermissionService } from '../common/services/permission.service';
import { DailyCareCheckinService } from './daily-care-checkin.service';
import { CreateDailyCareCheckinDto } from './dto/daily-care-checkin.dto';
import { FamilyMemberRole } from '../family/entities/family-member.entity';

@ApiTags('每日护理打卡')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('daily-care-checkins')
export class DailyCareCheckinController {
  constructor(
    private readonly service: DailyCareCheckinService,
    private readonly permission: PermissionService,
  ) {}

  @Get('today')
  @ApiOperation({ summary: '获取今日所有打卡（用于首页横幅）' })
  findToday(
    @Query('recipientIds') recipientIds: string,
    @Query('todayDate') todayDate: string,
    @Query('familyId') familyId: string,
  ) {
    const ids = recipientIds ? recipientIds.split(',') : [];
    return this.service.findTodayByRecipients(ids, todayDate, familyId);
  }

  @Get('by-recipient')
  @ApiOperation({ summary: '获取照护对象打卡历史（用于时间线）' })
  findByRecipient(
    @Query('careRecipientId') careRecipientId?: string,
    @Query('familyId') familyId?: string,
    @Query('limit') limit?: number,
  ) {
    return this.service.findByRecipient(careRecipientId, familyId, limit);
  }

  @Post()
  @ApiOperation({ summary: '创建或更新打卡（upsert）' })
  async upsert(
    @Body() dto: CreateDailyCareCheckinDto,
    @CurrentUser('id') userId: string,
  ) {
    // guest 不能操作每日护理打卡
    await this.permission.requireRole(userId, dto.familyId, [
      FamilyMemberRole.OWNER,
      FamilyMemberRole.COORDINATOR,
      FamilyMemberRole.CAREGIVER,
    ]);
    return this.service.upsert(dto, userId);
  }
}
