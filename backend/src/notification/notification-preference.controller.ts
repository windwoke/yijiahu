import { Controller, Get, Put, Body, UseGuards, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiTags, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { NotificationPreferenceService } from './notification-preference.service';
import { UpdatePreferenceDto } from './dto/notification-preference.dto';

@ApiTags('通知偏好')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('notification-preferences')
export class NotificationPreferenceController {
  constructor(private readonly svc: NotificationPreferenceService) {}

  @Get()
  @ApiOperation({ summary: '获取当前用户的通知偏好' })
  async get(@Req() req: any) {
    return this.svc.getByUserId(req.user.id);
  }

  @Put()
  @ApiOperation({ summary: '更新当前用户的通知偏好' })
  async update(@Req() req: any, @Body() dto: UpdatePreferenceDto) {
    return this.svc.update(req.user.id, dto);
  }
}
