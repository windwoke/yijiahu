import { Controller, Get, Post, Body, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags, ApiOperation } from '@nestjs/swagger';
import { HealthRecordService } from './health-record.service';
import { CreateHealthRecordDto } from './dto/health-record.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('健康记录')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('health-records')
export class HealthRecordController {
  constructor(private readonly service: HealthRecordService) {}

  @Post()
  @ApiOperation({ summary: '添加健康记录' })
  create(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateHealthRecordDto,
  ) {
    return this.service.create(dto, userId);
  }

  @Get()
  @ApiOperation({ summary: '获取健康记录列表' })
  findByRecipient(
    @Query('recipientId') recipientId: string,
    @Query('recordType') recordType?: string,
    @Query('days') days?: string,
  ) {
    return this.service.findByRecipient(
      recipientId,
      recordType,
      days ? parseInt(days, 10) : 7,
    );
  }

  @Get('trends')
  @ApiOperation({ summary: '获取健康趋势（血压+血糖）' })
  getTrends(
    @Query('recipientId') recipientId: string,
    @Query('days') days?: string,
  ) {
    return this.service.getTrends(
      recipientId,
      days ? parseInt(days, 10) : 7,
    );
  }
}
