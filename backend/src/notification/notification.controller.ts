import {
  Controller,
  Get,
  Put,
  Delete,
  Param,
  Query,
  Body,
  UseGuards,
  Req,
} from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { NotificationService } from './notification.service';
import { NotificationQueryDto } from './dto/notification.dto';

@Controller('notifications')
@UseGuards(JwtAuthGuard)
export class NotificationController {
  constructor(private readonly svc: NotificationService) {}

  /** 通知列表（分页） */
  @Get()
  async list(@Req() req: any, @Query() q: NotificationQueryDto) {
    const isRead =
      q.isRead === 'true' ? true : q.isRead === 'false' ? false : undefined;
    return this.svc.findByUser(
      req.user.id,
      q.page,
      q.pageSize,
      q.type,
      isRead,
      q.familyId,
    );
  }

  /** 未读数 */
  @Get('unread-count')
  async unreadCount(@Req() req: any, @Query('familyId') familyId?: string) {
    const count = await this.svc.getUnreadCount(req.user.id, familyId);
    return { code: 0, message: 'success', data: { count } };
  }

  /** 标记单条已读 */
  @Put(':id/read')
  async markRead(
    @Req() req: any,
    @Param('id') id: string,
    @Query('familyId') familyId?: string,
  ) {
    const n = await this.svc.markAsRead(id, req.user.id, familyId);
    return { code: 0, message: 'success', data: n };
  }

  /** 全部已读 */
  @Put('read-all')
  async markAllRead(@Req() req: any, @Query('familyId') familyId?: string) {
    await this.svc.markAllAsRead(req.user.id, familyId);
    return { code: 0, message: 'success' };
  }

  /** 删除通知 */
  @Delete(':id')
  async delete(
    @Req() req: any,
    @Param('id') id: string,
    @Query('familyId') familyId?: string,
  ) {
    await this.svc.delete(id, req.user.id, familyId);
    return { code: 0, message: 'success' };
  }
}
