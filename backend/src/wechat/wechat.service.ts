import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';
import { createDecipheriv, randomBytes } from 'crypto';

/**
 * 微信 API 封装服务
 * 负责与微信服务器的所有交互（登录凭证校验、access_token、模板消息等）
 */
@Injectable()
export class WechatService {
  private readonly logger = new Logger(WechatService.name);

  private readonly miniAppId: string;
  private readonly miniAppSecret: string;
  private readonly oaAppId: string;
  private readonly oaAppSecret: string;
  private readonly redis: Redis;

  // access_token 缓存 key
  private readonly ACCESS_TOKEN_KEY = 'wechat:access_token';
  private readonly ACCESS_TOKEN_EXPIRE = 7100; // 微信 access_token 有效期 7200s，提前 100s 刷新

  constructor(private config: ConfigService) {
    this.miniAppId = this.config.get<string>('wechat.miniApp.appId') || '';
    this.miniAppSecret = this.config.get<string>('wechat.miniApp.appSecret') || '';
    this.oaAppId = this.config.get<string>('wechat.officialAccount.appId') || '';
    this.oaAppSecret = this.config.get<string>('wechat.officialAccount.appSecret') || '';
    this.redis = new Redis({
      host: this.config.get<string>('redis.host') || 'localhost',
      port: this.config.get<number>('redis.port') || 6379,
      password: this.config.get<string>('redis.password') || undefined,
    });
  }

  // ══════════════════════════════════════════════════════════════
  // 1. 微信登录凭证校验（code2session）
  // ══════════════════════════════════════════════════════════════

  /**
   * 小程序登录：通过 code 换取 openId 和 session_key
   * 文档：https://developers.weixin.qq.com/miniprogram/dev/OpenApiDoc/user-login/code2Session.html
   */
  async code2Session(code: string): Promise<{
    openId: string;
    sessionKey: string;
    unionId?: string;
    errcode?: number;
    errmsg?: string;
  }> {
    if (!this.miniAppId || !this.miniAppSecret) {
      this.logger.warn('微信小程序 AppID 或 AppSecret 未配置，尝试 mock 模式');
      // 开发模式：mock 返回
      return {
        openId: `mock_openid_${code}`,
        sessionKey: `mock_session_key_${code}`,
        unionId: undefined,
      };
    }

    const url = `https://api.weixin.qq.com/sns/jscode2session`;
    const params = new URLSearchParams({
      appid: this.miniAppId,
      secret: this.miniAppSecret,
      js_code: code,
      grant_type: 'authorization_code',
    });

    const response = await fetch(`${url}?${params.toString()}`);
    const data = (await response.json()) as {
      openid?: string;
      session_key?: string;
      unionid?: string;
      errcode?: number;
      errmsg?: string;
    };

    if (data.errcode) {
      this.logger.warn(
        `微信 code2session 失败 (errcode=${data.errcode}), 降级为 mock 模式用于开发调试: ${data.errmsg}`,
      );
      // 开发者工具测试 code 无法调微信 API，降级到 mock
      return {
        openId: `mock_openid_${code}`,
        sessionKey: `mock_session_key_${code}`,
        unionId: undefined,
      };
    }

    return {
      openId: data.openid!,
      sessionKey: data.session_key!,
      unionId: data.unionid,
    };
  }

  // ══════════════════════════════════════════════════════════════
  // 2. 解密微信手机号
  // ══════════════════════════════════════════════════════════════

  /**
   * 解密微信 getPhoneNumber 返回的加密手机号
   * 文档：https://developers.weixin.qq.com/miniprogram/dev/OpenApiDoc/user-info/phone-number/getPhoneNumber.html
   *
   * @param code - wx.login() 返回的 code（用于换取 sessionKey）
   * @param encryptedData - getPhoneNumber 回调返回的 encryptedData
   * @param iv - getPhoneNumber 回调返回的 iv
   */
  async decryptPhoneNumber(code: string, encryptedData: string, iv: string): Promise<string> {
    // 用 code 换取 sessionKey
    const { sessionKey } = await this.code2Session(code);

    if (!sessionKey) {
      throw new Error('无法获取 sessionKey，解密失败');
    }

    // AES-256-CBC 解密
    const decipher = createDecipheriv(
      'aes-256-cbc',
      Buffer.from(sessionKey, 'base64'),
      Buffer.from(iv, 'base64'),
    );

    // PKCS7 自动去 padding
    let decrypted = Buffer.concat([
      decipher.update(Buffer.from(encryptedData, 'base64')),
      decipher.final(),
    ]).toString('utf8');

    const data = JSON.parse(decrypted) as { phoneNumber?: string };
    if (!data.phoneNumber) {
      throw new Error('解密结果中未找到手机号');
    }

    this.logger.log(`手机号解密成功: ${data.phoneNumber.replace(/(\d{3})\d{4}(\d{4})/, '$1****$2')}`);
    return data.phoneNumber;
  }

  // ══════════════════════════════════════════════════════════════
  // 3. 获取 access_token（带缓存自动刷新）
  // ══════════════════════════════════════════════════════════════

  /**
   * 获取服务号的 access_token（用于发送模板消息等）
   * 文档：https://developers.weixin.qq.com/doc/offiaccount/Basic_Information/Get_access_token.html
   */
  async getAccessToken(): Promise<string> {
    // 先查 Redis 缓存
    const cached = await this.redis.get(this.ACCESS_TOKEN_KEY);
    if (cached) {
      return cached;
    }

    if (!this.oaAppId || !this.oaAppSecret) {
      this.logger.warn('微信服务号 AppID 或 AppSecret 未配置');
      throw new Error('微信服务号未配置');
    }

    const url = `https://api.weixin.qq.com/cgi-bin/token`;
    const params = new URLSearchParams({
      grant_type: 'client_credential',
      appid: this.oaAppId,
      secret: this.oaAppSecret,
    });

    const response = await fetch(`${url}?${params.toString()}`);
    const data = (await response.json()) as {
      access_token?: string;
      expires_in?: number;
      errcode?: number;
      errmsg?: string;
    };

    if (data.errcode || !data.access_token) {
      this.logger.error(
        `获取 access_token 失败: ${JSON.stringify(data)}`,
      );
      throw new Error(`获取微信 access_token 失败: ${data.errmsg}`);
    }

    // 缓存到 Redis（比实际过期时间提前 100s）
    const ttl = Math.max((data.expires_in || 7200) - 100, 100);
    await this.redis.set(this.ACCESS_TOKEN_KEY, data.access_token, 'EX', ttl);

    return data.access_token;
  }

  // ══════════════════════════════════════════════════════════════
  // 3. 发送服务号模板消息
  // ══════════════════════════════════════════════════════════════

  /**
   * 发送微信服务号模板消息
   * 文档：https://developers.weixin.qq.com/doc/offiaccount/Message_Management/Template_Message_Interface.html
   */
  async sendTemplateMessage(params: {
    openId: string; // 用户在服务号的 openId（不同于小程序 openId）
    templateId: string;
    page?: string; // 点击模板消息后跳转的小程序页面
    data: Record<string, { value: string; color?: string }>;
  }): Promise<{ msgid: number; errcode?: number; errmsg?: string }> {
    const accessToken = await this.getAccessToken();

    const url = `https://api.weixin.qq.com/cgi-bin/message/template/send`;
    const body = {
      touser: params.openId,
      template_id: params.templateId,
      page: params.page || 'pages/home/home', // 跳转到小程序指定页面
      data: params.data,
      miniprogram: {
        appid: this.miniAppId,
        pagepath: params.page || 'pages/home/home',
      },
    };

    const response = await fetch(`${url}?access_token=${accessToken}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });

    const result = (await response.json()) as {
      errcode: number;
      errmsg: string;
      msgid: number;
    };

    if (result.errcode !== 0) {
      this.logger.warn(
        `模板消息发送失败: errcode=${result.errcode} errmsg=${result.errmsg}`,
      );
    }

    return result;
  }

  // ══════════════════════════════════════════════════════════════
  // 4. 微信支付统一下单（Native 支付，用于 H5/网页支付场景）
  // ══════════════════════════════════════════════════════════════

  /**
   * 微信支付 V2 统一下单
   * 文档：https://pay.weixin.qq.com/wiki/doc/apiv2/apis/chapter3_3_1.shtml
   */
  async unifiedOrder(params: {
    outTradeNo: string;
    totalFee: number; // 单位：分
    body: string;
    openId: string; // 小程序支付时需要用户 openId
    notifyUrl: string;
    spbillCreateIp: string;
  }): Promise<{ prepayId: string; sign: string; timestamp: string; nonceStr: string }> {
    const mchId = this.config.get<string>('wechat.payment.mchId') || '';
    const apiKey = this.config.get<string>('wechat.payment.apiKey') || '';

    const timeStart = new Date()
      .toISOString()
      .replace(/[-T:.Z]/g, '')
      .slice(0, 14);
    const nonceStr = Math.random().toString(36).slice(2);

    const payload = {
      appid: this.miniAppId,
      mch_id: mchId,
      nonce_str: nonceStr,
      body: params.body,
      out_trade_no: params.outTradeNo,
      total_fee: String(params.totalFee),
      spbill_create_ip: params.spbillCreateIp,
      notify_url: params.notifyUrl,
      trade_type: 'JSAPI',
      openid: params.openId,
      time_start: timeStart,
    };

    // 生成签名
    const sign = this.generateSign(payload, apiKey);

    const xmlPayload = this.toXml({ ...payload, sign });

    const response = await fetch('https://api.mch.weixin.qq.com/pay/unifiedorder', {
      method: 'POST',
      headers: { 'Content-Type': 'text/xml' },
      body: xmlPayload,
    });

    const xmlResult = await response.text();
    const result = this.parseXml(xmlResult);

    if (result.return_code !== 'SUCCESS' || result.result_code !== 'SUCCESS') {
      throw new Error(
        `微信支付下单失败: ${result.return_msg || result.err_code_des}`,
      );
    }

    return {
      prepayId: result.prepay_id,
      sign: this.generateSign(
        {
          appId: this.miniAppId,
          partnerId: mchId,
          prepayId: result.prepay_id,
          nonceStr,
          timeStamp: Math.floor(Date.now() / 1000).toString(),
        },
        apiKey,
      ),
      timestamp: Math.floor(Date.now() / 1000).toString(),
      nonceStr,
    };
  }

  // ══════════════════════════════════════════════════════════════
  // 内部工具方法
  // ══════════════════════════════════════════════════════════════

  /** 生成微信支付签名（MD5） */
  private generateSign(
    params: Record<string, string | number>,
    key: string,
  ): string {
    const sorted = Object.entries(params)
      .filter(([, v]) => v !== '' && v !== undefined && v !== null)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([k, v]) => `${k}=${v}`)
      .join('&');
    const signStr = `${sorted}&key=${key}`;
    return this.md5(signStr).toUpperCase();
  }

  /** MD5 实现（Node.js 内置 crypto） */
  private md5(input: string): string {
    // 使用 Node.js 内置 crypto
    const { createHash } = require('crypto');
    return createHash('md5').update(input).digest('hex');
  }

  /** 对象转 XML */
  private toXml(obj: Record<string, string>): string {
    const parts = Object.entries(obj)
      .map(([k, v]) => `<${k}><![CDATA[${v}]]></${k}>`)
      .join('');
    return `<xml>${parts}</xml>`;
  }

  /** XML 转对象（简化版） */
  private parseXml(xml: string): Record<string, string> {
    const result: Record<string, string> = {};
    const regex = /<(\w+)><!\[CDATA\[([^\]]*)\]\]><\/\1>/g;
    let match: RegExpExecArray | null;
    while ((match = regex.exec(xml)) !== null) {
      result[match[1]] = match[2];
    }
    return result;
  }
}
