import { Controller, Get, Post, Delete, Body, Param, Query, UseGuards, Request } from '@nestjs/common';
import { ApiBearerAuth, ApiTags, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CaregiverRecordService } from './caregiver-record.service';
import { CreateCaregiverRecordDto } from './dto/caregiver-record.dto';

@ApiTags('照护记录')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('caregiver-records')
export class CaregiverRecordController {
  constructor(private readonly service: CaregiverRecordService) {}

  @Get()
  @ApiOperation({ summary: '获取照护记录列表' })
  findAll(
    @Query('careRecipientId') careRecipientId: string,
    @Query('familyId') familyId: string,
  ) {
    return this.service.findByRecipient(careRecipientId, familyId);
  }

  @Get('current')
  @ApiOperation({ summary: '获取当前照护人' })
  findCurrent(
    @Query('careRecipientId') careRecipientId: string,
    @Query('familyId') familyId: string,
  ) {
    return this.service.findCurrent(careRecipientId, familyId);
  }

  @Post()
  @ApiOperation({ summary: '创建照护记录（自动切换）' })
  create(@Body() dto: CreateCaregiverRecordDto, @Request() req: any) {
    return this.service.create(dto, req.user.id);
  }

  @Delete(':id')
  @ApiOperation({ summary: '删除照护记录' })
  delete(
    @Param('id') id: string,
    @Query('familyId') familyId: string,
  ) {
    return this.service.delete(id, familyId);
  }
}
