/**
 * 药品详情页
 * 对齐 Flutter medication_detail_page.dart
 * 导航栏 + 基本信息 + 服药时间 + 用药记录
 */

import { useState, useEffect, useCallback } from 'react';
import { View, Text, ScrollView } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { get, del } from '../../services/api';
import { Storage } from '../../services/storage';
import {
  Medication,
  MedicationLog,
  MedicationLogStatus,
  MEDICATION_FREQUENCY_LABELS,
} from '../../shared/models/medication';
import './detail.scss';

const FREQ_LABEL: Record<string, string> = {
  daily: '每日',
  weekly: '每周',
  as_needed: '按需',
};

function formatDate(dateStr: string | null | undefined): string {
  if (!dateStr) return '';
  const d = new Date(dateStr);
  return `${d.getMonth() + 1}月${d.getDate()}日`;
}

function formatTimeStr(timeStr: string | null | undefined): string {
  if (!timeStr) return '';
  const parts = timeStr.split(' ');
  if (parts.length < 2) return timeStr;
  const date = parts[0].split('-');
  if (date.length < 3) return timeStr;
  return `${date[1]}/${date[2]} ${parts[1].substring(0, 5)}`;
}

function formatLogTime(log: MedicationLog): string {
  if (log.actualTime) return formatTimeStr(log.actualTime);
  if (log.createdAt) return formatTimeStr(log.createdAt);
  return '';
}

export default function MedicationDetailPage() {
  const params = (Taro.getCurrentInstance().router?.params as any) || {};
  const { id } = params;
  const familyId = Storage.getCurrentFamilyId();

  const [med, setMed] = useState<Medication | null>(null);
  const [history, setHistory] = useState<MedicationLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingHistory, setLoadingHistory] = useState(true);

  const load = useCallback(async () => {
    if (!id || !familyId) { setLoading(false); return; }
    try {
      const data = await get<Medication>(`/medications/${id}`, { familyId });
      setMed(data);
    } catch (e) {
      console.error('[detail] load error', e);
    } finally {
      setLoading(false);
    }
  }, [id, familyId]);

  const loadHistory = useCallback(async () => {
    if (!id || !familyId || !med) { setLoadingHistory(false); return; }
    try {
      const data = await get<MedicationLog[]>('/medication-logs/history', {
        familyId,
        recipientId: med.recipientId,
      });
      // 过滤当前药品的记录
      const filtered = (Array.isArray(data) ? data : []).filter(
        (log) => log.medicationId === id
      );
      setHistory(filtered);
    } catch (e) {
      console.error('[detail] load history error', e);
    } finally {
      setLoadingHistory(false);
    }
  }, [id, familyId, med]);

  useEffect(() => { load(); }, [load]);

  useEffect(() => {
    if (med) loadHistory();
  }, [med, loadHistory]);

  const handleEdit = () => {
    if (!id) return;
    Taro.navigateTo({ url: `/pages/medication/index?action=edit&medicationId=${id}` });
  };

  const handleDelete = async () => {
    if (!med) return;
    const res = await Taro.showModal({
      title: '确认删除',
      content: `确定要删除"${med.name}"吗？此操作不可恢复。`,
      confirmColor: '#E07B5D',
    });
    if (!res.confirm) return;
    try {
      await del(`/medications/${id}`, { params: { familyId } });
      Taro.showToast({ title: '已删除', icon: 'success' });
      setTimeout(() => Taro.navigateBack(), 1500);
    } catch (e: any) {
      Taro.showToast({ title: e?.message || '删除失败', icon: 'none' });
    }
  };

  if (loading) {
    return (
      <View className="med-detail-page loading-state">
        <Text className="loading-text">加载中...</Text>
      </View>
    );
  }

  if (!med) {
    return (
      <View className="med-detail-page empty-state">
        <Text className="empty-emoji">💊</Text>
        <Text className="empty-title">未找到该药品</Text>
      </View>
    );
  }

  const statusText = med.isActive ? '在用' : '已停用';
  const statusColor = med.isActive ? '#6BA07E' : '#B0ADAD';

  return (
    <View className="med-detail-page">
      {/* 导航栏 */}
      <View className="detail-navbar">
        <View className="navbar-left" onClick={() => Taro.navigateBack()}>
          <Text className="navbar-back">‹</Text>
        </View>
        <Text className="navbar-title">药品详情</Text>
        <View className="navbar-right">
          <Text className="navbar-edit" onClick={handleEdit}>编辑</Text>
          <Text className="navbar-delete" onClick={handleDelete}>删除</Text>
        </View>
      </View>

      <ScrollView className="detail-scroll" scrollY>
        {/* 头部卡片 */}
        <View className="header-card">
          <View className="header-icon">
            <Text className="header-icon-text">💊</Text>
          </View>
          <View className="header-info">
            <Text className="header-name">{med.name}</Text>
            {med.realName && <Text className="header-realname">{med.realName}</Text>}
            <View className="header-status">
              <Text className="status-badge" style={{ color: statusColor, backgroundColor: `${statusColor}1A` }}>
                {statusText}
              </Text>
            </View>
          </View>
        </View>

        {/* 基本信息 */}
        <View className="section">
          <Text className="section-title">基本信息</Text>
          <View className="info-card">
            <View className="info-row">
              <Text className="info-label">剂量</Text>
              <Text className="info-value">{med.dosage}{med.unit || ''}</Text>
            </View>
            <View className="info-row">
              <Text className="info-label">频率</Text>
              <Text className="info-value">{FREQ_LABEL[med.frequency] || med.frequency}</Text>
            </View>
            <View className="info-row">
              <Text className="info-label">开始日期</Text>
              <Text className="info-value">{med.startDate ? formatDate(med.startDate) : '-'}</Text>
            </View>
            <View className="info-row">
              <Text className="info-label">结束日期</Text>
              <Text className="info-value">{med.endDate ? formatDate(med.endDate) : '长期服用'}</Text>
            </View>
            {med.prescribedBy && (
              <View className="info-row">
                <Text className="info-label">开药医生</Text>
                <Text className="info-value">{med.prescribedBy}</Text>
              </View>
            )}
            {med.instructions && (
              <View className="info-row">
                <Text className="info-label">用药说明</Text>
                <Text className="info-value info-value-multiline">{med.instructions}</Text>
              </View>
            )}
          </View>
        </View>

        {/* 服药时间 */}
        {med.times && med.times.length > 0 && (
          <View className="section">
            <Text className="section-title">服药时间</Text>
            <View className="time-card">
              {med.times.map((t) => (
                <View key={t} className="time-chip">
                  <Text className="time-chip-icon">⏰</Text>
                  <Text className="time-chip-text">{t}</Text>
                </View>
              ))}
            </View>
          </View>
        )}

        {/* 用药记录 */}
        <View className="section">
          <View className="section-title-row">
            <Text className="section-title">用药记录</Text>
            <Text className="section-subtitle">近7天</Text>
          </View>
          <View className="info-card">
            {loadingHistory ? (
              <View className="history-loading">
                <View className="loading-dot" />
                <View className="loading-dot" />
                <View className="loading-dot" />
              </View>
            ) : history.length === 0 ? (
              <View className="history-empty">
                <Text className="history-empty-icon">📋</Text>
                <Text className="history-empty-text">暂无用药记录</Text>
              </View>
            ) : (
              history.slice(0, 7).map((log) => {
                const isTaken = log.status === MedicationLogStatus.TAKEN;
                const color = isTaken ? '#6BA07E' : '#B0ADAD';
                const authorName = log.takenBy?.name || '家庭成员';
                return (
                  <View key={log.id} className="history-row">
                    <View className="history-dot" style={{ backgroundColor: color }} />
                    <Text className="history-time">{formatLogTime(log)}</Text>
                    <View className="history-badge" style={{ color, backgroundColor: `${color}1A` }}>
                      <Text className="history-badge-text">
                        {isTaken ? '已服用' : '已跳过'}
                      </Text>
                    </View>
                    <View className="history-author">
                      <View className="author-avatar">
                        <Text className="author-avatar-text">
                          {authorName ? authorName[0] : '?'}
                        </Text>
                      </View>
                      <Text className="author-name">
                        {authorName.length > 4 ? `${authorName.substring(0, 4)}…` : authorName}
                      </Text>
                    </View>
                  </View>
                );
              })
            )}
          </View>
        </View>

        <View className="bottom-pad" />
      </ScrollView>
    </View>
  );
}
