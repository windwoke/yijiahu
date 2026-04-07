import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { WechatService } from './wechat.service';

@Module({
  imports: [ConfigModule],
  providers: [WechatService],
  exports: [WechatService],
})
export class WechatModule {}
