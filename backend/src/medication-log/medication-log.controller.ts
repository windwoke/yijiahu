import { Controller, Get, Post, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { MedicationLogService } from './medication-log.service';
import { CheckInDto } from './dto/medication-log.dto';

@ApiTags('用药记录')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('medication-logs')
export class MedicationLogController {
  constructor(private readonly service: MedicationLogService) {}

  @Get('today')
  @ApiOperation({ summary: '获取今日用药汇总' })
  getToday(@Query('recipientId') recipientId: string) {
    return this.service.getTodaySummary(recipientId);
  }

  @Post(':id/check-in')
  @ApiOperation({ summary: '用药打卡' })
  checkIn(
    @Param('id') id: string,
    @CurrentUser('id') userId: string,
    @Body() dto: CheckInDto,
  ) {
    return this.service.checkIn(id, dto, userId);
  }

  @Get('history')
  @ApiOperation({ summary: '获取历史用药记录' })
  getHistory(@Query('recipientId') recipientId: string, @Query('date') date: string) {
    return this.service.getHistory(recipientId, date);
  }
}
