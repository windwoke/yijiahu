/**
 * 每日护理打卡页
 * 通过 Taro.getCurrentInstance().router?.params 获取 recipientId / recipientName
 */

import { useState } from 'react';
import { View, Text, Textarea, Image } from '@tarojs/components';
import Taro, { useDidShow } from '@tarojs/taro';
import { get, post } from '../../services/api';
import { getImageUrl } from '../../shared/utils/image';
import { Storage } from '../../services/storage';
import type { DailyCareCheckin, CheckinStatus } from '../../shared/models/daily-care-checkin';
import type { TodayMedicationSummary } from '../../shared/models/medication';
import './index.scss';

/** 状态选项配置 */
const STATUS_OPTIONS: Array<{
  status: CheckinStatus;
  color: string;
  emoji: string;
  label: string;
}> = [
  { status: 'normal', color: '#7B9E87', emoji: '😊', label: '状态良好' },
  { status: 'concerning', color: '#D4A855', emoji: '😟', label: '需要关注' },
  { status: 'poor', color: '#E07B5D', emoji: '😰', label: '状态较差' },
  { status: 'critical', color: '#C0392B', emoji: '🆘', label: '紧急情况' },
];

export default function DailyCarePage() {
  // 从路由参数获取照护对象信息
  const params = Taro.getCurrentInstance().router?.params ?? {};
  const recipientId: string = params.recipientId ?? '';
  const recipientName: string = decodeURIComponent(params.recipientName ?? '') || '未知';
  const recipientAvatar: string = decodeURIComponent(params.recipientAvatar ?? '');

  // 状态
  const [selectedStatus, setSelectedStatus] = useState<CheckinStatus>('normal');
  const [noteText, setNoteText] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [medCompleted, setMedCompleted] = useState(0);
  const [medTotal, setMedTotal] = useState(0);

  /** 格式化今日日期 */
  const formatTodayDate = () => {
    const d = new Date();
    const weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日 ${weekdays[d.getDay()]}`;
  };

  /** 获取今日打卡数据和用药进度 */
  const loadData = async () => {
    const familyId = Storage.getCurrentFamilyId();
    const today = new Date();
    const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;

    try {
      // 并行请求：今日打卡数据 + 今日用药汇总（后者作为 fallback）
      const [checkinsData, medSummary] = await Promise.all([
        get<DailyCareCheckin[]>(
          '/daily-care-checkins/today',
          { recipientIds: recipientId, todayDate: todayStr, familyId }
        ).catch(() => null),
        get<TodayMedicationSummary>(
          '/medication-logs/today',
          { recipientId, familyId }
        ).catch(() => null),
      ]);

      if (checkinsData && Array.isArray(checkinsData) && checkinsData.length > 0) {
        const checkin = checkinsData[0];
        setSelectedStatus(checkin.status);
        // 优先用打卡记录中的用药数，否则用今日用药汇总
        setMedTotal(checkin.medicationTotal > 0 ? checkin.medicationTotal : (medSummary?.total ?? 0));
        setMedCompleted(checkin.medicationCompleted >= 0 ? checkin.medicationCompleted : (medSummary?.completed ?? 0));
        if (checkin.specialNote) {
          setNoteText(checkin.specialNote);
        }
      } else if (medSummary) {
        // 无打卡记录，直接用今日用药汇总
        setMedTotal(medSummary.total);
        setMedCompleted(medSummary.completed);
      }
    } catch (err) {
      console.error('加载今日打卡数据失败:', err);
    }
  };

  useDidShow(() => {
    loadData();
  });

  /** 提交打卡 */
  const handleSubmit = async () => {
    if (isLoading) return;
    setIsLoading(true);

    const today = new Date();
    const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
    const familyId = Storage.getCurrentFamilyId();

    try {
      await post('/daily-care-checkins', {
        familyId,
        careRecipientId: recipientId,
        checkinDate: todayStr,
        status: selectedStatus,
        medicationCompleted: medCompleted,
        medicationTotal: medTotal,
        specialNote: noteText.trim() || undefined,
      });

      Taro.showToast({ title: '打卡成功', icon: 'success', duration: 1500 });
      setTimeout(() => {
        Taro.navigateBack();
      }, 1500);
    } catch (err) {
      console.error('打卡失败:', err);
      Taro.showToast({ title: '打卡失败，请重试', icon: 'none', duration: 2000 });
    } finally {
      setIsLoading(false);
    }
  };

  // 用药进度
  const progress = medTotal > 0 ? Math.min(100, Math.round((medCompleted / medTotal) * 100)) : 0;
  const progressColor = progress >= 80 ? '#6BA07E' : '#7B9E87';

  return (
    <View className="daily-care-page">
      {/* 顶部导航栏 */}
      <View className="nav-bar">
        <View
          className="nav-back"
          onClick={() => Taro.navigateBack()}
        >
          <Text className="back-arrow">‹</Text>
        </View>
        <Text className="nav-title">今日护理打卡</Text>
        <View className="nav-placeholder" />
      </View>

      <View className="page-content">
        {/* 照护对象卡片 */}
        <View className="recipient-card">
          <View className="recipient-avatar">
            {recipientAvatar ? (
              <Image className="avatar-img" src={getImageUrl(recipientAvatar)} mode="aspectFill" />
            ) : (
              <Text className="avatar-emoji">👤</Text>
            )}
          </View>
          <View className="recipient-info">
            <Text className="recipient-name">{recipientName}</Text>
            <Text className="recipient-date">{formatTodayDate()}</Text>
          </View>
        </View>

        {/* 状态选择区域 */}
        <View className="section">
          <Text className="section-title">老人今日状态</Text>
          <View className="status-wrap">
            {STATUS_OPTIONS.map((opt) => {
              const isSelected = selectedStatus === opt.status;
              return (
                <View
                  key={opt.status}
                  className={`status-chip ${isSelected ? 'selected' : ''}`}
                  style={
                    isSelected
                      ? {
                          borderColor: opt.color,
                          backgroundColor: `${opt.color}1a`,
                          boxShadow: `0 4rpx 16rpx ${opt.color}33`,
                        }
                      : {}
                  }
                  onClick={() => setSelectedStatus(opt.status)}
                >
                  <Text className="status-emoji">{opt.emoji}</Text>
                  <Text
                    className="status-label"
                    style={isSelected ? { color: opt.color } : {}}
                  >
                    {opt.label}
                  </Text>
                </View>
              );
            })}
          </View>
        </View>

        {/* 用药情况卡片 */}
        <View className="section">
          <Text className="section-title">用药情况</Text>
          <View className="med-card">
            <View className="med-header">
              <Image className="med-icon" src={require('../../assets/icons/medication.png')} />
              <Text className="med-title">今日用药</Text>
              <Text className="med-count">
                {medTotal > 0 ? `${medCompleted} / ${medTotal} 项` : '暂无药品'}
              </Text>
            </View>
            {medTotal > 0 && (
              <View className="progress-bar-wrap">
                <View className="progress-bar-bg">
                  <View
                    className="progress-bar-fill"
                    style={{
                      width: `${progress}%`,
                      backgroundColor: progressColor,
                    }}
                  />
                </View>
                <Text className="progress-percent">{progress}%</Text>
              </View>
            )}
          </View>
        </View>

        {/* 特殊情况备注 */}
        <View className="section">
          <Text className="section-title">特殊情况（选填）</Text>
          <View className="note-wrap">
            <Textarea
              className="note-input"
              placeholder="如：发热、腹泻、食欲不佳、跌倒等特殊情况"
              placeholderClass="note-placeholder"
              value={noteText}
              onInput={(e) => setNoteText(e.detail.value)}
              maxlength={500}
              autoHeight
            />
          </View>
        </View>

        {/* 确认打卡按钮 */}
        <View className="submit-wrap">
          <View
            className={`submit-btn ${isLoading ? 'loading' : ''}`}
            onClick={!isLoading ? handleSubmit : undefined}
          >
            {isLoading ? (
              <Text className="submit-text loading-text">打卡中...</Text>
            ) : (
              <Text className="submit-text">确认打卡</Text>
            )}
          </View>
        </View>

        <View className="bottom-pad" />
      </View>
    </View>
  );
}
