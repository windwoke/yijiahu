import { Controller, Post, Get, Patch, Body, Param, Query, UseGuards, ParseUUIDPipe } from '@nestjs/common';
import { ApiBearerAuth, ApiTags, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { SosService } from './sos.service';
import { CreateSosDto } from './dto/create-sos.dto';
import { UpdateSosDto } from './dto/update-sos.dto';
import { SosStatus } from './entities/sos-record.entity';

@ApiTags('SOS 紧急求助')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('sos-alerts')
export class SosController {
  constructor(private readonly service: SosService) {}

  @Post()
  @ApiOperation({ summary: '触发 SOS 紧急求助' })
  create(@Body() dto: CreateSosDto, @CurrentUser('id') userId: string) {
    return this.service.create(dto, userId);
  }

  @Get('active')
  @ApiOperation({ summary: '查询当前家庭活跃的 SOS 记录' })
  findActive(@Query('familyId', ParseUUIDPipe) familyId: string) {
    return this.service.findActive(familyId);
  }

  @Get()
  @ApiOperation({ summary: '查询 SOS 历史记录' })
  findAll(@Query('familyId', ParseUUIDPipe) familyId: string) {
    return this.service.findByFamily(familyId);
  }

  @Patch(':id/status')
  @ApiOperation({ summary: '更新 SOS 状态' })
  updateStatus(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateSosDto,
    @Query('familyId', ParseUUIDPipe) familyId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.service.updateStatus(id, familyId, dto.status, userId);
  }
}
