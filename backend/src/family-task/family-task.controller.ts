import { Controller, Get, Post, Patch, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { FamilyTaskService } from './family-task.service';
import { CreateFamilyTaskDto, UpdateFamilyTaskDto, CompleteTaskDto } from './dto/family-task.dto';

@ApiTags('家庭任务')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('family-tasks')
export class FamilyTaskController {
  constructor(private readonly service: FamilyTaskService) {}

  @Get()
  @ApiOperation({ summary: '家庭任务列表' })
  findAll(@Query('familyId') familyId: string) {
    return this.service.findByFamily(familyId);
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

  @Post()
  @ApiOperation({ summary: '创建任务' })
  create(
    @Body() dto: CreateFamilyTaskDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.service.create(dto, userId);
  }

  @Patch(':id')
  @ApiOperation({ summary: '更新任务' })
  update(
    @Param('id') id: string,
    @Body() dto: UpdateFamilyTaskDto,
    @Query('familyId') familyId: string,
  ) {
    return this.service.update(id, familyId, dto);
  }

  @Post(':id/complete')
  @ApiOperation({ summary: '完成任务' })
  complete(
    @Param('id') id: string,
    @Body() dto: CompleteTaskDto,
    @CurrentUser('id') userId: string,
    @Query('familyId') familyId: string,
  ) {
    return this.service.complete(id, userId, dto, familyId);
  }

  @Delete(':id')
  @ApiOperation({ summary: '删除任务' })
  delete(@Param('id') id: string, @Query('familyId') familyId: string) {
    return this.service.delete(id, familyId);
  }
}
