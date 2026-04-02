/// JPush 推送服务
import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class JPushService implements OnModuleInit {
  private client: any;
  private jpushLib: any;
  private readonly logger = new Logger(JPushService.name);
  private enabled = false;

  constructor(private readonly config: ConfigService) {}

  async onModuleInit() {
    const appKey = this.config.get<string>('jpush.appKey');
    const masterSecret = this.config.get<string>('jpush.masterSecret');

    if (!appKey || !masterSecret) {
      this.logger.warn(
        'JPush 未配置（jpush.appKey / jpush.masterSecret），推送已禁用',
      );
      return;
    }

    try {
      this.jpushLib = require('jpush-sdk');
      this.client = this.jpushLib.buildClient(appKey, masterSecret);
      this.enabled = true;
      this.logger.log('JPush 初始化成功');
    } catch (e: any) {
      this.logger.error(`JPush 初始化失败: ${e?.message || e?.toString() || String(e)}`);
    }
  }

  /**
   * 推送消息给指定设备
   * @param registrationId 极光 Registration ID（设备标识）
   * @param title 通知标题
   * @param body 通知内容
   * @param extras 额外数据（传递给 App）
   */
  async pushToRegistration(
    registrationId: string,
    title: string,
    body: string,
    extras: Record<string, any> = {},
  ): Promise<void> {
    if (!this.enabled || !this.client) {
      this.logger.debug(`[JPush Mock] → ${registrationId}: ${title} - ${body}`);
      return;
    }

    return new Promise((resolve, reject) => {
      this.client
        .push()
        .setPlatform('ios', 'android')
        .setAudience(this.jpushLib.registration_id(registrationId))
        .setNotification(
          this.jpushLib.android(body, title, null, extras),
          this.jpushLib.ios({ title, body }, 'default', '+1', null, extras),
        )
        .setMessage(body)
        .setOptions(null, 86400, null, true) // time_to_live: 24h
        .send((err: any) => {
          if (err) {
            this.logger.error(`JPush 推送失败 → ${registrationId}:`, err);
            reject(err);
          } else {
            this.logger.debug(`JPush 推送成功 → ${registrationId}`);
            resolve();
          }
        });
    });
  }
}
