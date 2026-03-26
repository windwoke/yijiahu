import { Controller, Get, Post, Body, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { SubscriptionService } from './subscription.service';
import {
  CreateSubscriptionDto,
  AppleReceiptDto,
  SubscriptionStatusDto,
  WechatNotifyDto,
} from './dto/subscription.dto';

@ApiTags('订阅')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('subscriptions')
export class SubscriptionController {
  constructor(private readonly service: SubscriptionService) {}

  /** 查询指定家庭订阅状态 */
  @Get('status')
  @ApiOperation({ summary: '查询家庭订阅状态' })
  async getStatus(@Query('familyId') familyId: string): Promise<SubscriptionStatusDto> {
    return this.service.getStatus(familyId);
  }

  /** Apple IAP 收据验证并激活订阅 */
  @Post('apple/verify')
  @ApiOperation({ summary: 'Apple IAP 收据验证' })
  async verifyAppleReceipt(@Body() dto: AppleReceiptDto) {
    // TODO: 调用 Apple 收据验证接口（App Store Connect API）
    // 目前为占位实现
    return { success: false, message: 'Apple IAP 验证待接入' };
  }

  /** 取消订阅 */
  @Post('cancel')
  @ApiOperation({ summary: '取消订阅（取消但不过期，到期前仍有效）' })
  async cancel(@Query('familyId') familyId: string) {
    await this.service.cancel(familyId);
    return { message: '已取消，到期前仍有效' };
  }

  /** 激活订阅（支付成功后服务端调用） */
  @Post('activate')
  @ApiOperation({ summary: '激活订阅（服务端内部调用）' })
  async activate(@Body() dto: CreateSubscriptionDto) {
    const sub = await this.service.activate(dto);
    return { message: '订阅已激活', subscriptionId: sub.id };
  }

  /** 微信支付回调 */
  @Post('wechat/notify')
  @ApiOperation({ summary: '微信支付回调' })
  async wechatNotify(@Body() dto: WechatNotifyDto) {
    const sub = await this.service.handleWechatNotify(dto.transaction_id, dto.out_trade_no);
    return { message: '回调处理成功', subscriptionId: sub.id };
  }
}
