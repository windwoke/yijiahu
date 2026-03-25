import { Controller, Get, Post, Query, Body, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CareLogService } from './care-log.service';
import { CreateCareLogDto } from './dto/care-log.dto';

@ApiTags('照护日志')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('care-logs')
export class CareLogController {
  constructor(private readonly service: CareLogService) {}

  @Post()
  @ApiOperation({ summary: '创建照护日志' })
  create(
    @CurrentUser('id') userId: string,
    @Query('familyId') familyId: string,
    @Body() dto: CreateCareLogDto,
  ) {
    return this.service.create(familyId, userId, dto);
  }

  @Get()
  @ApiOperation({ summary: '获取照护日志列表' })
  findAll(
    @Query('familyId') familyId: string,
    @Query('recipientId') recipientId?: string,
    @Query('type') type?: string,
    @Query('limit') limit?: string,
    @Query('before') before?: string,  // ISO 时间戳，用于分页游标
  ) {
    return this.service.findByFamily(familyId, {
      recipientId,
      type,
      limit: limit ? parseInt(limit, 10) : 50,
      before: before ? new Date(before) : undefined,
    });
  }
}
