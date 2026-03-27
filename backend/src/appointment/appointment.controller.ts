import { Controller, Get, Post, Patch, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { AppointmentService } from './appointment.service';
import { CreateAppointmentDto, UpdateAppointmentDto } from './dto/appointment.dto';
import { AppointmentStatus } from './entities/appointment.entity';

@ApiTags('复诊管理')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('appointments')
export class AppointmentController {
  constructor(private readonly service: AppointmentService) {}

  @Get()
  @ApiOperation({ summary: '复诊列表' })
  findAll(
    @Query('familyId') familyId: string,
    @Query('recipientId') recipientId: string,
    @Query('status') status?: AppointmentStatus,
  ) {
    if (recipientId) {
      return this.service.findByRecipient(recipientId, familyId, status);
    }
    return [];
  }

  @Get('calendar')
  @ApiOperation({ summary: '复诊日历月视图' })
  getCalendar(
    @Query('familyId') familyId: string,
    @Query('year') year: string,
    @Query('month') month: string,
  ) {
    return this.service.findByFamily(familyId, parseInt(year), parseInt(month));
  }

  @Post()
  @ApiOperation({ summary: '创建复诊' })
  create(
    @Body() dto: CreateAppointmentDto,
    @CurrentUser('id') userId: string,
    @Query('familyId') familyId: string,
  ) {
    return this.service.create(familyId, dto, userId);
  }

  @Patch(':id')
  @ApiOperation({ summary: '更新复诊' })
  update(
    @Param('id') id: string,
    @Body() dto: UpdateAppointmentDto,
    @Query('familyId') familyId: string,
  ) {
    return this.service.update(id, familyId, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: '删除复诊' })
  delete(@Param('id') id: string, @Query('familyId') familyId: string) {
    return this.service.delete(id, familyId);
  }
}
