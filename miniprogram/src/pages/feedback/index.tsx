/**
 * 问题反馈页
 * 表单提交到后端 → 飞书 webhook 即时通知
 */
import { View, Text, Textarea, Input } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { useState } from 'react';
import { post } from '../../services/api';
import './index.scss';

const CATEGORIES = [
  { key: 'bug', label: '🐛 问题反馈', desc: '功能异常、闪退、数据错误' },
  { key: 'feature', label: '💡 功能建议', desc: '希望增加的新功能' },
  { key: 'other', label: '📝 其他', desc: '使用咨询、合作等' },
];

export default function FeedbackPage() {
  const [category, setCategory] = useState('bug');
  const [content, setContent] = useState('');
  const [contact, setContact] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async () => {
    if (!content.trim()) {
      Taro.showToast({ title: '请输入反馈内容', icon: 'none' });
      return;
    }
    if (content.trim().length < 5) {
      Taro.showToast({ title: '反馈内容至少5个字', icon: 'none' });
      return;
    }

    setSubmitting(true);
    try {
      await post('/feedback', {
        category,
        content: content.trim(),
        contact: contact.trim() || undefined,
      });
      Taro.showToast({ title: '感谢反馈，我们会尽快处理！', icon: 'none', duration: 2000 });
      setTimeout(() => Taro.navigateBack(), 2000);
    } catch (err: any) {
      Taro.showToast({ title: err.message || '提交失败，请稍后重试', icon: 'none' });
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <View className="feedback-page">
      {/* 反馈类型 */}
      <View className="section">
        <Text className="section-title">反馈类型</Text>
        <View className="category-list">
          {CATEGORIES.map((cat) => (
            <View
              key={cat.key}
              className={`category-card ${category === cat.key ? 'category-active' : ''}`}
              onClick={() => setCategory(cat.key)}
            >
              <Text className="category-label">{cat.label}</Text>
              <Text className="category-desc">{cat.desc}</Text>
            </View>
          ))}
        </View>
      </View>

      {/* 反馈内容 */}
      <View className="section">
        <Text className="section-title">详细描述</Text>
        <View className="textarea-wrap">
          <Textarea
            className="feedback-textarea"
            placeholder="请描述您遇到的问题或建议，越详细越好..."
            placeholderClass="textarea-placeholder"
            value={content}
            maxlength={1000}
            onInput={(e) => setContent(e.detail.value)}
          />
          <Text className="textarea-count">{content.length}/1000</Text>
        </View>
      </View>

      {/* 联系方式（可选） */}
      <View className="section">
        <Text className="section-title">联系方式（选填）</Text>
        <Input
          className="contact-input"
          placeholder="手机号 / 微信号 / 邮箱（选填）"
          placeholderClass="input-placeholder"
          value={contact}
          maxlength={100}
          onInput={(e) => setContact(e.detail.value)}
        />
      </View>

      {/* 提交按钮 */}
      <View
        className={`submit-btn ${submitting || !content.trim() ? 'submit-btn-disabled' : ''}`}
        onClick={submitting ? undefined : handleSubmit}
      >
        <Text className="submit-btn-text">{submitting ? '提交中...' : '提交反馈'}</Text>
      </View>
    </View>
  );
}
