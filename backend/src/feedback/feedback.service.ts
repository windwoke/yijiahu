import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { CreateFeedbackDto } from './dto/feedback.dto';

@Injectable()
export class FeedbackService {
  private webhookUrl: string;

  constructor(private configService: ConfigService) {
    this.webhookUrl = this.configService.get<string>('feishu.webhookUrl') || '';
  }

  async submit(dto: CreateFeedbackDto, userId?: string, userAgent?: string) {
    // 如果没配 webhook，记录日志即可
    if (!this.webhookUrl) {
      console.log('[Feedback] 未配置飞书 webhook，反馈内容:', dto);
      return { message: '反馈已收到，感谢您的建议！' };
    }

    const categoryMap: Record<string, string> = {
      bug: '🐛 Bug 反馈',
      feature: '💡 功能建议',
      other: '📝 其他',
    };

    const card = {
      msg_type: 'interactive',
      card: {
        header: {
          title: { tag: 'plain_text', content: '🏠 一家护 · 新的用户反馈' },
          template: 'blue',
        },
        elements: [
          {
            tag: 'div',
            fields: [
              { is_short: true, text: { tag: 'lark_md', content: `**类型**\n${categoryMap[dto.category] || dto.category}` } },
              { is_short: true, text: { tag: 'lark_md', content: `**时间**\n${new Date().toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai' })}` } },
            ],
          },
          { tag: 'hr' },
          {
            tag: 'div',
            text: { tag: 'lark_md', content: `**反馈内容**\n${dto.content}` },
          },
          ...(dto.contact ? [{
            tag: 'div',
            text: { tag: 'lark_md', content: `**联系方式**\n${dto.contact}` },
          }] : []),
          { tag: 'hr' },
          {
            tag: 'note',
            elements: [
              { tag: 'plain_text', content: `来源：微信小程序${userId ? ` | 用户：${userId.slice(0, 8)}...` : ''}` },
            ],
          },
        ],
      },
    };

    try {
      const response = await fetch(this.webhookUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(card),
      });

      if (!response.ok) {
        console.error('[Feedback] 飞书 webhook 调用失败:', response.status, await response.text());
      }
    } catch (err) {
      console.error('[Feedback] 飞书 webhook 调用异常:', err);
    }

    return { message: '反馈已收到，感谢您的建议！' };
  }
}
