/**
 * 微信通知页
 * 小程序引流到 App：提示用户下载 App 享受完整通知体验
 */
import { View, Text } from '@tarojs/components';
import Taro from '@tarojs/taro';
import './index.scss';

export default function NotificationPage() {
  const handleDownload = () => {
    // 复制下载链接到剪贴板
    Taro.setClipboardData({
      data: 'https://yijiahu.com/download',
      success: () => {
        Taro.showToast({ title: '链接已复制，请在浏览器打开', icon: 'none', duration: 2500 });
      },
    });
  };

  const handleCopyAppName = () => {
    Taro.setClipboardData({
      data: '一家护',
      success: () => {
        Taro.showToast({ title: '已复制 App 名称', icon: 'success', duration: 1500 });
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
          在各大应用商店搜索「一家护」下载，或点击下方复制下载链接
        </Text>
        <View className="action-btn" onClick={handleDownload}>
          <Text className="action-btn-text">复制下载链接</Text>
        </View>
        <View className="action-hint">
          <Text className="action-hint-text" onClick={handleCopyAppName}>
            在应用商店搜索：一家护
          </Text>
        </View>
      </View>
    </View>
  );
}
