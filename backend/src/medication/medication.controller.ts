import { Controller, Get, Post, Patch, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { MedicationService } from './medication.service';
import { CreateMedicationDto, UpdateMedicationDto } from './dto/medication.dto';

@ApiTags('药品')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('medications')
export class MedicationController {
  constructor(private readonly service: MedicationService) {}

  @Post()
  @ApiOperation({ summary: '添加药品' })
  create(@Body() dto: CreateMedicationDto) {
    return this.service.create(dto.familyId, dto);
  }

  @Get()
  @ApiOperation({ summary: '按家庭获取药品列表' })
  findByFamily(
    @Query('familyId') familyId?: string,
    @Query('recipientId') recipientId?: string,
  ) {
    return this.service.findByFamilyOrRecipient(familyId, recipientId);
  }

  @Get(':id')
  @ApiOperation({ summary: '获取药品详情' })
  findOne(@Param('id') id: string, @Query('familyId') familyId: string) {
    return this.service.findOne(id, familyId);
  }

  @Patch(':id')
  @ApiOperation({ summary: '更新药品' })
  update(@Param('id') id: string, @Query('familyId') familyId: string, @Body() dto: UpdateMedicationDto) {
    return this.service.update(id, familyId, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: '删除药品' })
  delete(@Param('id') id: string, @Query('familyId') familyId: string) {
    return this.service.delete(id, familyId);
  }
}
