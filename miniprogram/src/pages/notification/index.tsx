/**
 * 微信通知页
 * 小程序引流到官网下载 App
 */
import { View, Text } from '@tarojs/components';
import Taro from '@tarojs/taro';
import './index.scss';

export default function NotificationPage() {
  const handleGoWebsite = () => {
    Taro.navigateTo({ url: '/pages/webview/index?url=https://yijiahu.com.cn' });
  };

  const handleCopyLink = () => {
    Taro.setClipboardData({
      data: 'https://yijiahu.com.cn',
      success: () => {
        Taro.showToast({ title: '链接已复制，请在浏览器打开', icon: 'none', duration: 2500 });
      },
    });
  };

  return (
    <View className="page">
      {/* 顶部插图 */}
      <View className="hero">
        <View className="hero-icon-wrap">
          <Text className="hero-icon">📲</Text>
        </View>
        <Text className="hero-title">在 App 中接收通知</Text>
        <Text className="hero-subtitle">
          小程序通知有限，下载一家护 App 后可第一时间收到 SOS 紧急求助、用药提醒、复诊提醒等所有通知
        </Text>
      </View>

      {/* 优势对比 */}
      <View className="compare-card">
        <Text className="compare-title">小程序 vs App 通知对比</Text>

        <View className="compare-item compare-item-mp">
          <Text className="compare-label">小程序</Text>
          <View className="compare-list">
            <Text className="compare-x">✗ SOS 需手动订阅，紧急时来不及</Text>
            <Text className="compare-x">✗ 每天都要重新订阅提醒</Text>
            <Text className="compare-x">✗ 通知在服务通知里，容易漏看</Text>
          </View>
        </View>

        <View className="compare-divider" />

        <View className="compare-item compare-item-app">
          <Text className="compare-label">App</Text>
          <View className="compare-list">
            <Text className="compare-check">✓ SOS 实时推送，无需订阅</Text>
            <Text className="compare-check">✓ 所有提醒自动推送，不漏一条</Text>
            <Text className="compare-check">✓ 系统通知栏直接显示</Text>
          </View>
        </View>
      </View>

      {/* 操作区 */}
      <View className="action-card">
        <Text className="action-title">下载一家护 App</Text>
        <Text className="action-desc">
          前往官网下载 Android 版，即将上架各大应用商店
        </Text>
        <View className="action-btn" onClick={handleGoWebsite}>
          <Text className="action-btn-text">前往官网下载</Text>
        </View>
        <View className="action-hint">
          <Text className="action-hint-text" onClick={handleCopyLink}>
            或复制官网链接在浏览器打开
          </Text>
        </View>
      </View>
    </View>
  );
}
