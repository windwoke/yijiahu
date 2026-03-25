import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CareLogAttachmentService } from './care-log-attachment.service';

@ApiTags('照护日志附件')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('care-log-attachments')
export class CareLogAttachmentController {
  constructor(private readonly service: CareLogAttachmentService) {}

  @Get('care-log/:careLogId')
  @ApiOperation({ summary: '获取日志的所有附件' })
  findByCareLog(@Param('careLogId') careLogId: string) {
    return this.service.findByCareLogId(careLogId);
  }
}
