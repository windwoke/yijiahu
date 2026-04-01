import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { PermissionService } from '../common/services/permission.service';
import { AppointmentService } from './appointment.service';
import {
  CreateAppointmentDto,
  UpdateAppointmentDto,
  UpdateAppointmentStatusDto,
} from './dto/appointment.dto';
import { AppointmentStatus } from './entities/appointment.entity';
import { FamilyMemberRole } from '../family/entities/family-member.entity';

@ApiTags('复诊管理')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('appointments')
export class AppointmentController {
  constructor(
    private readonly service: AppointmentService,
    private readonly permission: PermissionService,
  ) {}

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
  async create(
    @Body() dto: CreateAppointmentDto,
    @CurrentUser('id') userId: string,
    @Query('familyId') familyId: string,
  ) {
    await this.permission.requireRole(userId, familyId, [
      FamilyMemberRole.OWNER,
      FamilyMemberRole.COORDINATOR,
    ]);
    return this.service.create(familyId, dto, userId);
  }

  @Patch(':id')
  @ApiOperation({ summary: '更新复诊' })
  async update(
    @Param('id') id: string,
    @Body() dto: UpdateAppointmentDto,
    @CurrentUser('id') userId: string,
    @Query('familyId') familyId: string,
  ) {
    await this.permission.requireRole(userId, familyId, [
      FamilyMemberRole.OWNER,
      FamilyMemberRole.COORDINATOR,
    ]);
    return this.service.update(id, familyId, dto);
  }

  @Patch(':id/status')
  @ApiOperation({ summary: '更新复诊状态' })
  async updateStatus(
    @Param('id') id: string,
    @Body() dto: UpdateAppointmentStatusDto,
    @CurrentUser('id') userId: string,
    @Query('familyId') familyId: string,
  ) {
    await this.permission.requireRole(userId, familyId, [
      FamilyMemberRole.OWNER,
      FamilyMemberRole.COORDINATOR,
    ]);
    return this.service.updateStatus(id, familyId, dto.status);
  }

  @Delete(':id')
  @ApiOperation({ summary: '删除复诊' })
  async delete(
    @Param('id') id: string,
    @CurrentUser('id') userId: string,
    @Query('familyId') familyId: string,
  ) {
    await this.permission.requireRole(userId, familyId, [
      FamilyMemberRole.OWNER,
      FamilyMemberRole.COORDINATOR,
    ]);
    return this.service.delete(id, familyId);
  }
}
