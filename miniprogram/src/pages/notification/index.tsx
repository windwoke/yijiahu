/**
 * 微信通知订阅页
 * 极简版：只有一个开关，引导用户开启微信订阅通知
 */
import { View, Text, Switch } from '@tarojs/components';
import Taro, { useDidShow } from '@tarojs/taro';
import { useState } from 'react';
import { get, put } from '../../services/api';
import './index.scss';

export default function NotificationPage() {
  const [enabled, setEnabled] = useState(false);
  const [loading, setLoading] = useState(true);
  const [toggling, setToggling] = useState(false);

  useDidShow(() => {
    setLoading(true);
    get<{ wechatEnabled?: boolean }>('/notification-preferences')
      .then((data) => setEnabled(data?.wechatEnabled ?? false))
      .catch((err) => console.error('[notif] 加载失败:', err))
      .finally(() => setLoading(false));
  });

  const handleToggle = async (checked: boolean) => {
    if (!checked) {
      // 关闭：直接保存
      setToggling(true);
      try {
        await put('/notification-preferences', { wechatEnabled: false });
        setEnabled(false);
      } catch (err: any) {
        Taro.showToast({ title: err?.message || '保存失败', icon: 'none' });
      } finally {
        setToggling(false);
      }
      return;
    }

    // 开启：先调起微信授权
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const res = await (Taro as any).requestSubscribeMessage({
      tmplIds: ['G7yHV1nGEup9A4YsszDfvHi4vmUl9ztqxDdqWn-ffxQ'],
    });

    const accept = res?.['G7yHV1nGEup9A4YsszDfvHi4vmUl9ztqxDdqWn-ffxQ'] === 'accept';
    if (!accept) {
      Taro.showToast({ title: '您拒绝了授权', icon: 'none', duration: 2000 });
      return;
    }

    setToggling(true);
    try {
      await put('/notification-preferences', { wechatEnabled: true });
      setEnabled(true);
      Taro.showToast({ title: '已开启', icon: 'success', duration: 1500 });
    } catch (err: any) {
      Taro.showToast({ title: err?.message || '保存失败', icon: 'none' });
    } finally {
      setToggling(false);
    }
  };

  if (loading) {
    return (
      <View className="sub-page">
        <View className="loading">加载中...</View>
      </View>
    );
  }

  return (
    <View className="sub-page">
      {/* 顶部说明 */}
      <View className="intro-card">
        <View className="intro-icon-wrap">
          <Text className="intro-icon">🔔</Text>
        </View>
        <Text className="intro-title">微信通知</Text>
        <Text className="intro-desc">
          开启后，SOS 紧急求助和复诊提醒将推送到你的微信通知中心
        </Text>
      </View>

      {/* 开关 */}
      <View className="toggle-card">
        <View className="toggle-left">
          <Text className="toggle-label">接收微信通知</Text>
          <Text className="toggle-hint">
            {enabled ? '已开启' : '关闭后将不再收到微信通知'}
          </Text>
        </View>
        <Switch
          checked={enabled}
          disabled={toggling}
          color="#07C160"
          onChange={(e) => handleToggle(e.detail.value)}
        />
      </View>

      {/* 通知说明 */}
      <View className="desc-card">
        <Text className="desc-title">支持的通知类型</Text>
        <View className="desc-item">
          <Text className="desc-dot">•</Text>
          <Text className="desc-text">🔔 SOS 紧急求助</Text>
        </View>
        <View className="desc-item">
          <Text className="desc-dot">•</Text>
          <Text className="desc-text">🏥 复诊提醒</Text>
        </View>
      </View>

      {/* 注意 */}
      <View className="note-card">
        <Text className="note-text">
          微信订阅为一次性授权，如需关闭请在此页面操作
        </Text>
      </View>
    </View>
  );
}
