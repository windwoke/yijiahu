import { Controller, Get, Post, Patch, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CareRecipientService } from './care-recipient.service';
import { CreateCareRecipientDto, UpdateCareRecipientDto } from './dto/care-recipient.dto';

@ApiTags('照护对象')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('care-recipients')
export class CareRecipientController {
  constructor(private readonly service: CareRecipientService) {}

  @Post()
  @ApiOperation({ summary: '添加照护对象' })
  create(@CurrentUser('id') userId: string, @Body() dto: CreateCareRecipientDto) {
    // TODO: 需要先从用户关联的家庭中获取 familyId
    return this.service.create('mock-family-id', dto);
  }

  @Get()
  @ApiOperation({ summary: '获取家庭照护对象列表' })
  findByFamily(@Query('family_id') familyId: string) {
    return this.service.findByFamily(familyId);
  }

  @Get(':id')
  @ApiOperation({ summary: '获取照护对象详情' })
  findOne(@Param('id') id: string, @Query('family_id') familyId: string) {
    return this.service.findOne(id, familyId);
  }

  @Patch(':id')
  @ApiOperation({ summary: '更新照护对象' })
  update(
    @Param('id') id: string,
    @Query('family_id') familyId: string,
    @Body() dto: UpdateCareRecipientDto,
  ) {
    return this.service.update(id, familyId, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: '删除照护对象' })
  delete(@Param('id') id: string, @Query('family_id') familyId: string) {
    return this.service.delete(id, familyId);
  }
}
