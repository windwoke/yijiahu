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
  create(@Body() body: CreateMedicationDto) {
    return this.service.create(body.recipientId, body);
  }

  @Get()
  @ApiOperation({ summary: '获取照护对象药品列表' })
  findByRecipient(@Query('recipientId') recipientId: string) {
    return this.service.findByRecipient(recipientId);
  }

  @Get(':id')
  @ApiOperation({ summary: '获取药品详情' })
  findOne(@Param('id') id: string) {
    return this.service.findOne(id);
  }

  @Patch(':id')
  @ApiOperation({ summary: '更新药品' })
  update(@Param('id') id: string, @Body() dto: UpdateMedicationDto) {
    return this.service.update(id, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: '删除药品' })
  delete(@Param('id') id: string) {
    return this.service.delete(id);
  }
}
