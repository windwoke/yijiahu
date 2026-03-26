import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsOptional, IsIn, IsDateString } from 'class-validator';

/** 创建订阅（由服务端内部使用，支付成功后调用） */
export class CreateSubscriptionDto {
  @ApiProperty({ example: 'family-uuid' })
  @IsString()
  familyId: string;

  @ApiProperty({ example: 'premium', enum: ['premium', 'annual'] })
  @IsString()
  @IsIn(['premium', 'annual'])
  plan: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  paymentPlatform?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  paymentTradeNo?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  appleReceipt?: string;

  @ApiPropertyOptional()
  @IsString()
  @IsOptional()
  wechatPrepayId?: string;
}

/** 微信支付成功回调 */
export class WechatNotifyDto {
  @ApiProperty()
  @IsString()
  return_code: string;

  @ApiProperty()
  @IsString()
  result_code: string;

  @ApiProperty()
  @IsString()
  transaction_id: string;

  @ApiProperty()
  @IsString()
  out_trade_no: string;

  @ApiProperty()
  @IsString()
  time_end: string;
}

/** Apple IAP receipt 验证 */
export class AppleReceiptDto {
  @ApiProperty()
  @IsString()
  receiptData: string;

  @ApiProperty()
  @IsString()
  familyId: string;
}

/** 套餐功能列表 */
export class SubscriptionFeaturesDto {
  @ApiProperty()
  maxRecipients: number;

  @ApiProperty()
  maxMembers: number;

  @ApiProperty()
  maxLogsPerMonth: number;

  /** 存储空间上限（MB），-1 表示不限 */
  @ApiProperty()
  maxStorageMB: number;

  @ApiProperty()
  healthReports: boolean;

  @ApiProperty()
  recurrenceReminders: boolean;
}

/** 查询订阅状态响应 */
export class SubscriptionStatusDto {
  @ApiProperty()
  plan: string;

  @ApiProperty()
  status: string;

  @ApiPropertyOptional()
  expiresAt: string;

  @ApiProperty()
  features: SubscriptionFeaturesDto;
}
