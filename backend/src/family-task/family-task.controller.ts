import { Controller, Get, Post, Patch, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { PermissionService } from '../common/services/permission.service';
import { FamilyTaskService } from './family-task.service';
import { CreateFamilyTaskDto, UpdateFamilyTaskDto, CompleteTaskDto } from './dto/family-task.dto';
import { FamilyMemberRole } from '../family/entities/family-member.entity';

@ApiTags('家庭任务')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('family-tasks')
export class FamilyTaskController {
  constructor(
    private readonly service: FamilyTaskService,
    private readonly permission: PermissionService,
  ) {}

  @Get()
  @ApiOperation({ summary: '家庭任务列表' })
  findAll(
    @Query('familyId') familyId: string,
    @Query('year') year?: string,
    @Query('month') month?: string,
  ) {
    return this.service.findByFamily(
      familyId,
      year ? parseInt(year) : undefined,
      month ? parseInt(month) : undefined,
    );
  }

  @Get('upcoming')
  @ApiOperation({ summary: '即将到期的任务' })
  findUpcoming(@Query('familyId') familyId: string) {
    return this.service.findUpcoming(familyId);
  }

  @Get('calendar')
  @ApiOperation({ summary: '任务日历月视图' })
  getCalendar(
    @Query('familyId') familyId: string,
    @Query('year') year: string,
    @Query('month') month: string,
  ) {
    return this.service.findByMonth(familyId, parseInt(year), parseInt(month));
  }

  // ⚠️ 动态路由必须放在具体路由之后，否则 /calendar /upcoming 会被 :id 捕获
  @Get(':id')
  @ApiOperation({ summary: '任务详情（含最近完成记录）' })
  async findOne(
    @Param('id') id: string,
    @Query('familyId') familyId: string,
  ) {
    return this.service.findById(id, familyId);
  }

  @Post()
  @ApiOperation({ summary: '创建任务' })
  async create(
    @Body() dto: CreateFamilyTaskDto,
    @CurrentUser('id') userId: string,
  ) {
    await this.permission.requireRole(userId, dto.familyId, [
      FamilyMemberRole.OWNER,
      FamilyMemberRole.COORDINATOR,
    ]);
    return this.service.create(dto, userId);
  }

  @Patch(':id')
  @ApiOperation({ summary: '更新任务' })
  async update(
    @Param('id') id: string,
    @Body() dto: UpdateFamilyTaskDto,
    @CurrentUser('id') userId: string,
    @Query('familyId') familyId: string,
  ) {
    await this.permission.requireRole(userId, familyId, [
      FamilyMemberRole.OWNER,
      FamilyMemberRole.COORDINATOR,
    ]);
    return this.service.update(id, familyId, dto);
  }

  @Post(':id/complete')
  @ApiOperation({ summary: '完成任务' })
  async complete(
    @Param('id') id: string,
    @Body() dto: CompleteTaskDto,
    @CurrentUser('id') userId: string,
    @Query('familyId') familyId: string,
  ) {
    // caregiver 只能完成分配给自己的任务；如果未传 assigneeId，从数据库查
    const assigneeId = dto.assigneeId ?? (await this.service.getAssigneeId(id));
    await this.permission.canCompleteTask(userId, familyId, assigneeId ?? userId);
    return this.service.complete(id, userId, dto, familyId);
  }

  @Delete(':id')
  @ApiOperation({ summary: '删除任务' })
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
