/**
 * 照护日志页
 * 温暖日记风时间线 — 与 Flutter 设计对齐
 */

import { useState, useEffect, useCallback } from 'react';
import { View, Text, ScrollView, Image } from '@tarojs/components';
import Taro, { useDidShow } from '@tarojs/taro';
import { get, post, del, uploadFile } from '../../services/api';
import { Storage } from '../../services/storage';
import { getImageUrl } from '../../shared/utils/image';
import './index.scss';

/* ============================
   类型定义
   ============================ */

const CARE_LOG_TYPES = [
  { key: null, label: '全部', emoji: '📋', color: '#7B9E87' },
  { key: 'medication', label: '服药', emoji: '💊', color: '#4A90D9' },
  { key: 'health', label: '健康', emoji: '🩺', color: '#7B9E87' },
  { key: 'emotion', label: '情绪', emoji: '😊', color: '#D4A855' },
  { key: 'activity', label: '活动', emoji: '🚶', color: '#6BA07E' },
  { key: 'meal', label: '饮食', emoji: '🍽', color: '#C88C50' },
  { key: 'other', label: '其他', emoji: '📝', color: '#6B6B6B' },
];

/** 健康指标类型 */
const HEALTH_METRIC_TYPES = [
  { key: 'blood_pressure', label: '血压', emoji: '🫀', unit: 'mmHg', hint: '120/80' },
  { key: 'blood_glucose', label: '血糖', emoji: '🩸', unit: 'mmol/L', hint: '5.6' },
  { key: 'weight', label: '体重', emoji: '⚖️', unit: 'kg', hint: '60' },
];

const HEALTH_NORMAL_RANGES: Record<string, string> = {
  blood_pressure: '正常 90-140/60-90 mmHg',
  blood_glucose: '空腹 3.9-6.1 mmol/L',
  weight: '参考个人基准',
};

interface CareRecipient {
  id: string;
  name: string;
  displayAvatar: string;
}

interface Attachment {
  url: string;
  type: 'image' | 'video';
}

/** 待上传的附件（选图后立即开始后台上传） */
interface PendingAttachment {
  id: string;
  localPath: string;
  uploading: boolean;
  uploadedUrl?: string;
  uploadedId?: string;
  failed?: boolean;
}

interface CareLog {
  id: string;
  content: string;
  type: string;
  createdAt: string;
  authorName: string;
  authorAvatar?: string;
  recipientId?: string;
  recipientName?: string;
  attachments: Attachment[];
  /** 'care_log' | 'medication' | 'health_record' | 'daily_care_checkin' */
  source: string;
  /** 健康记录专用字段 */
  recordType?: string;
  healthValue?: Record<string, any>;
  /** 每日护理打卡专用 */
  checkinStatus?: string;
  medicationCompleted?: number;
  medicationTotal?: number;
  specialNote?: string;
}

interface TimelineResponse {
  list: CareLog[];
  total: number;
}

/** 按日期分组 */
interface DayGroup {
  dateLabel: string;
  dateISO: string;
  logs: CareLog[];
}

/* ============================
   工具函数
   ============================ */

function getDateLabel(isoStr: string): string {
  const d = new Date(isoStr.replace(/-/g, '/'));
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const target = new Date(d);
  target.setHours(0, 0, 0, 0);
  const diff = Math.round((today.getTime() - target.getTime()) / 86400000);

  if (diff === 0) return '今天';
  if (diff === 1) return '昨天';

  const month = d.getMonth() + 1;
  const day = d.getDate();
  const weekday = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'][d.getDay()];
  return `${month}月${day}日 ${weekday}`;
}

function groupByDate(logs: CareLog[]): DayGroup[] {
  const map = new Map<string, CareLog[]>();
  for (const log of logs) {
    const d = new Date(log.createdAt.replace(/-/g, '/'));
    const iso = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
    if (!map.has(iso)) map.set(iso, []);
    map.get(iso)!.push(log);
  }
  return Array.from(map.entries())
    .sort(([a], [b]) => b.localeCompare(a))
    .map(([iso, logs]) => ({
      dateLabel: getDateLabel(iso),
      dateISO: iso,
      logs,
    }));
}

function getTypeDef(type: string | null) {
  return CARE_LOG_TYPES.find((t) => t.key === type) ?? CARE_LOG_TYPES[0];
}

function formatTime(isoStr: string): string {
  const d = new Date(isoStr.replace(/-/g, '/'));
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

/** 根据 recordType 和 value 构建健康记录显示内容 */
function buildHealthContent(recordType: string, value: Record<string, any> | undefined): string {
  switch (recordType) {
    case 'blood_pressure': {
      const sys = value?.systolic ?? '-';
      const dia = value?.diastolic ?? '-';
      return `血压 ${sys}/${dia} mmHg`;
    }
    case 'blood_glucose': {
      const val = value?.value ?? '-';
      const t = value?.type === 'postprandial' ? '餐后' : '空腹';
      return `${t}血糖 ${val} mmol/L`;
    }
    case 'weight': {
      const val = value?.value ?? '-';
      const unit = value?.unit ?? 'kg';
      return `体重 ${val} ${unit}`;
    }
    default:
      return '健康记录';
  }
}

/** 判断健康指标是否超出范围：'normal' | 'high' | 'low' */
function checkHealthRange(recordType: string, value: Record<string, any> | undefined): 'normal' | 'high' | 'low' {
  switch (recordType) {
    case 'blood_pressure': {
      const sys = (value?.systolic as number) ?? 0;
      const dia = (value?.diastolic as number) ?? 0;
      if (sys >= 140 || dia >= 90) return 'high';
      if (sys < 90 || dia < 60) return 'low';
      return 'normal';
    }
    case 'blood_glucose': {
      const val = (value?.value as number) ?? 0;
      if (val > 11.1 || val < 2.8) return 'high';
      if (val > 7.8 || val < 3.9) return 'low';
      return 'normal';
    }
    case 'weight':
    default:
      return 'normal';
  }
}

function getAttachmentUrl(url: string): string {
  return getImageUrl(url);
}

function getDefaultAvatarUrl(): string {
  // 返回默认头像的路径（与后端一致）
  return '';
}

/* ============================
   主组件
   ============================ */

export default function CareLogPage() {
  const [filterType, setFilterType] = useState<string | null>(null);
  const [selectedRecipientId, setSelectedRecipientId] = useState<string | null>(null);
  const [recipients, setRecipients] = useState<CareRecipient[]>([]);
  const [dayGroups, setDayGroups] = useState<DayGroup[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [hasMore, setHasMore] = useState(false);
  const [page, setPage] = useState(1);
  const [showAddSheet, setShowAddSheet] = useState(false);
  const [addContent, setAddContent] = useState('');
  const [addType, setAddType] = useState<string>('other');
  const [addRecipientId, setAddRecipientId] = useState<string>('');
  const [submitting, setSubmitting] = useState(false);
  const [pendingAttachments, setPendingAttachments] = useState<PendingAttachment[]>([]);

  // 健康指标
  const [addHealthMetric, setAddHealthMetric] = useState<string>(''); // 'blood_pressure' | 'blood_glucose' | 'weight'
  // 血压
  const [bpSys, setBpSys] = useState('');
  const [bpDia, setBpDia] = useState('');
  // 血糖
  const [glucoseVal, setGlucoseVal] = useState('');
  const [glucoseType, setGlucoseType] = useState<string>('fasting'); // 'fasting' | 'postprandial'
  // 体重
  const [weightVal, setWeightVal] = useState('');
  const [weightUnit, setWeightUnit] = useState<string>('kg'); // 'kg' | 'jin'

  const uploadAttachment = async (id: string, localPath: string) => {
    if (!familyId) return;
    try {
      const res = await uploadFile(`/upload/attachments?familyId=${familyId}`, localPath, 'files');
      console.log('[care-log] upload res:', JSON.stringify(res));
      // 后端返回 { attachments: [{ id, url, filename, ... }] }
      const attachments = res?.attachments || res?.data?.attachments || [];
      const first = attachments[0] || {};
      const uploadedId = first.id || '';
      const uploadedUrl = first.url || '';
      console.log('[care-log] upload parsed:', { uploadedId, uploadedUrl });
      setPendingAttachments((prev) =>
        prev.map((a) => a.id === id ? { ...a, uploading: false, uploadedUrl, uploadedId } : a)
      );
    } catch (err: any) {
      console.error('[care-log] upload failed:', err?.message);
      setPendingAttachments((prev) =>
        prev.map((a) => a.id === id ? { ...a, uploading: false, failed: true } : a)
      );
    }
  };

  const handleChooseImages = () => {
    const remaining = 9 - pendingAttachments.length;
    if (remaining <= 0) {
      Taro.showToast({ title: '最多上传9张', icon: 'none' });
      return;
    }
    Taro.chooseMedia({
      count: remaining,
      sizeType: ['compressed'],
      sourceType: ['album', 'camera'],
      mediaType: ['image', 'video'],
    }).then((res) => {
      const newOnes: PendingAttachment[] = res.tempFiles.map((f: any) => ({
        id: `local-${Date.now()}-${Math.random()}`,
        localPath: f.tempFilePath,
        uploading: true,
      }));
      setPendingAttachments((prev) => [...prev, ...newOnes]);
      newOnes.forEach((a) => uploadAttachment(a.id, a.localPath));
    });
  };

  const removeAttachment = (id: string) => {
    setPendingAttachments((prev) => prev.filter((a) => a.id !== id));
  };

  const hasUploading = pendingAttachments.some((a) => a.uploading);

  const uploadedAttachments = pendingAttachments
    .filter((a) => !a.uploading && a.uploadedId && !a.failed)
    .map((a) => a.uploadedId!);

  const familyId = Storage.getCurrentFamilyId();

  const loadRecipients = useCallback(async () => {
    if (!familyId) return;
    try {
      const data = await get<CareRecipient[]>(`/care-recipients?familyId=${familyId}`);
      setRecipients(data ?? []);
      if (data && data.length > 0 && !addRecipientId) {
        setAddRecipientId(data[0].id);
      }
    } catch (err) {
      console.error('加载照护对象失败', err);
    }
  }, [familyId, addRecipientId]);

  const loadTimeline = useCallback(async (reset = false) => {
    const currentPage = reset ? 1 : page;
    if (reset) setLoading(true);
    try {
      if (reset) {
        // 并发拉取 4 个来源
        const [careLogsData, medLogsData, healthData, checkinData] = await Promise.all([
          get<any[]>('/care-logs', {
            familyId,
            page: 1,
            limit: 20,
            ...(filterType ? { type: filterType } : {}),
            ...(selectedRecipientId ? { recipientId: selectedRecipientId } : {}),
          }),
          get<any[]>('/medication-logs/timeline', {
            days: 45,
            limit: 30,
            ...(selectedRecipientId ? { recipientId: selectedRecipientId } : {}),
            ...(familyId ? { familyId } : {}),
          }).catch(() => [] as any[]),
          get<any[]>('/health-records/recent', {
            limit: 20,
            days: 90,
            ...(selectedRecipientId ? { recipientId: selectedRecipientId } : {}),
            ...(familyId ? { familyId } : {}),
          }).catch(() => [] as any[]),
          get<any[]>('/daily-care-checkins/by-recipient', {
            limit: 30,
            ...(selectedRecipientId ? { careRecipientId: selectedRecipientId } : {}),
            ...(familyId ? { familyId } : {}),
          }).catch(() => [] as any[]),
        ]);

        // care logs
        const logs: CareLog[] = (careLogsData ?? []).map((item: any) => ({
          ...item,
          source: 'care_log',
          createdAt: item.createdAt,
        }));

        // 用药打卡（后端返回 time 字段）
        const medLogs: CareLog[] = (medLogsData ?? []).map((item: any) => ({
          id: item.id,
          content: item.content || '',
          type: 'medication',
          createdAt: item.time || item.createdAt,
          authorName: item.authorName || '家庭成员',
          authorAvatar: item.authorAvatar,
          recipientId: item.recipientId,
          attachments: [],
          source: 'medication',
        }));

        // 健康记录
        const healthLogs: CareLog[] = ((healthData ?? []) as any[]).map((item: any) => ({
          id: item.id,
          content: buildHealthContent(item.recordType, item.value),
          type: 'health',
          createdAt: item.recordedAt,
          authorName: item.authorName || '家庭成员',
          authorAvatar: item.authorAvatar,
          recipientId: item.recipientId,
          attachments: [],
          source: 'health_record',
          recordType: item.recordType,
          healthValue: item.value,
        }));

        // 每日护理打卡（使用 createdAt 作为时间戳，checkinDate 仅为日期字段）
        const checkinLogs: CareLog[] = ((checkinData ?? []) as any[]).map((item: any) => {
          const medCompleted = item.medicationCompleted ?? 0;
          const medTotal = item.medicationTotal ?? 0;
          let content = medTotal > 0
            ? `用药完成 ${medCompleted}/${medTotal} 项`
            : '护理打卡';
          if (item.specialNote) content += ` · ${item.specialNote}`;
          return {
            id: item.id,
            content,
            type: 'other',
            createdAt: item.createdAt || item.checkinDate,
            authorName: item.authorName || '家庭成员',
            authorAvatar: item.authorAvatar,
            recipientId: item.careRecipientId,
            attachments: [],
            source: 'daily_care_checkin',
            checkinStatus: item.status,
            medicationCompleted: item.medicationCompleted,
            medicationTotal: item.medicationTotal,
            specialNote: item.specialNote,
          };
        });

        // 合并并按时间倒序
        const merged = [...logs, ...medLogs, ...healthLogs, ...checkinLogs].sort(
          (a, b) => new Date(b.createdAt.replace(/-/g, '/')).getTime() - new Date(a.createdAt.replace(/-/g, '/')).getTime(),
        );
        setDayGroups(groupByDate(merged));
        setPage(1);
        setHasMore(logs.length === 20);
      } else {
        // 加载更多：只追加 care logs
        const data = await get<any[]>('/care-logs', {
          familyId,
          page: currentPage,
          limit: 20,
          ...(filterType ? { type: filterType } : {}),
          ...(selectedRecipientId ? { recipientId: selectedRecipientId } : {}),
        });
        const logs: CareLog[] = (data ?? []).map((item: any) => ({ ...item, source: 'care_log' }));
        setDayGroups((prev) => {
          const existing = new Map(prev.map((g) => [g.dateISO, g]));
          for (const g of groupByDate(logs)) {
            if (existing.has(g.dateISO)) {
              existing.get(g.dateISO)!.logs.push(...g.logs);
            } else {
              existing.set(g.dateISO, g);
            }
          }
          return Array.from(existing.values()).sort((a, b) => b.dateISO.localeCompare(a.dateISO));
        });
        setHasMore(logs.length === 20);
      }
    } catch (err) {
      console.error('加载时间线失败', err);
    } finally {
      setLoading(false);
    }
  }, [familyId, filterType, selectedRecipientId, page]);

  useEffect(() => {
    loadRecipients();
  }, [loadRecipients]);

  useEffect(() => {
    if (!familyId) {
      setDayGroups([]);
      setLoading(false);
      return;
    }
    loadTimeline(true);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [familyId, filterType, selectedRecipientId]);

  useDidShow(() => {
    if (familyId) {
      loadTimeline(true);
      loadRecipients();
    }
  });

  const onScrollToLower = useCallback(() => {
    if (!hasMore || loading) return;
    setPage((p) => p + 1);
  }, [hasMore, loading]);

  useEffect(() => {
    if (page > 1) loadTimeline(false);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page]);

  const handleTypeChange = (type: string | null) => {
    setFilterType(type);
  };

  const handleRecipientChange = (id: string | null) => {
    setSelectedRecipientId(id);
  };

  const handleAddLog = async () => {
    if (!familyId) {
      Taro.showToast({ title: '请先加入家庭', icon: 'none' });
      return;
    }
    if (!addRecipientId) {
      Taro.showToast({ title: '请选择照护对象', icon: 'none' });
      return;
    }

    setSubmitting(true);
    try {
      if (addType === 'health') {
        // 健康类型：校验指标数据
        if (!addHealthMetric) {
          Taro.showToast({ title: '请选择健康指标', icon: 'none' });
          setSubmitting(false);
          return;
        }
        let value: Record<string, any> = {};
        if (addHealthMetric === 'blood_pressure') {
          if (!bpSys.trim() || !bpDia.trim()) {
            Taro.showToast({ title: '请填写血压数值', icon: 'none' });
            setSubmitting(false);
            return;
          }
          value = { systolic: Number(bpSys), diastolic: Number(bpDia) };
        } else if (addHealthMetric === 'blood_glucose') {
          if (!glucoseVal.trim()) {
            Taro.showToast({ title: '请填写血糖数值', icon: 'none' });
            setSubmitting(false);
            return;
          }
          value = { value: Number(glucoseVal), type: glucoseType };
        } else {
          if (!weightVal.trim()) {
            Taro.showToast({ title: '请填写体重数值', icon: 'none' });
            setSubmitting(false);
            return;
          }
          value = { value: Number(weightVal), unit: weightUnit };
        }
        await post('/health-records', {
          familyId,
          recipientId: addRecipientId,
          recordType: addHealthMetric,
          value,
          note: addContent.trim() || undefined,
        });
        Taro.showToast({ title: '记录成功', icon: 'success' });
      } else {
        // 普通日志
        if (!addContent.trim() && pendingAttachments.length === 0) {
          Taro.showToast({ title: '请输入内容或添加图片', icon: 'none' });
          setSubmitting(false);
          return;
        }
        const attachmentIds = pendingAttachments
          .filter((a) => !a.uploading && a.uploadedId && !a.failed)
          .map((a) => a.uploadedId!);
        const payload: Record<string, any> = {
          recipientId: addRecipientId,
          content: addContent.trim() || '（图片日志）',
          type: addType,
        };
        if (attachmentIds.length > 0) {
          payload.attachmentIds = attachmentIds;
        }
        await post(`/care-logs?familyId=${familyId}`, payload);
        Taro.showToast({ title: '记录成功', icon: 'success' });
      }
      setShowAddSheet(false);
      setAddContent('');
      setAddType('other');
      setAddHealthMetric('');
      setPendingAttachments([]);
      setBpSys('');
      setBpDia('');
      setGlucoseVal('');
      setWeightVal('');
      loadTimeline(true);
    } catch (err) {
      console.error('提交日志失败', err);
      Taro.showToast({ title: '提交失败，请重试', icon: 'none' });
    } finally {
      setSubmitting(false);
    }
  };

  const closeSheet = () => {
    setShowAddSheet(false);
    setPendingAttachments([]);
    setAddContent('');
    setAddType('other');
    setAddHealthMetric('');
    setBpSys('');
    setBpDia('');
    setGlucoseVal('');
    setWeightVal('');
  };

  const titleLabel = selectedRecipientId
    ? (recipients.find((r) => r.id === selectedRecipientId)?.name ?? '照护对象') + '的日志'
    : '照护日志';

  return (
    <View className="care-log-page">
      {/* 顶部留白（状态栏） */}
      <View className="status-bar" />

      {/* 页面标题 */}
      <View className="page-header">
        <Text className="page-title">{titleLabel}</Text>
        <View className="timeline-badge">
          <Text className="timeline-badge-text">时间线</Text>
        </View>
      </View>

      {/* 照护对象切换（横向滚动） */}
      {recipients.length > 1 && (
        <ScrollView className="recipient-switcher" scrollX>
          <View className="recipient-chips">
            <View
              className={`recipient-chip ${selectedRecipientId === null ? 'selected' : ''}`}
              onClick={() => handleRecipientChange(null)}
            >
              <Text className="chip-emoji">👨‍👩‍👧‍👦</Text>
              <Text className={`chip-name ${selectedRecipientId === null ? 'selected' : ''}`}>全部</Text>
            </View>
            {recipients.map((r) => (
              <View
                key={r.id}
                className={`recipient-chip ${selectedRecipientId === r.id ? 'selected' : ''}`}
                onClick={() => handleRecipientChange(r.id)}
              >
                <Text className="chip-emoji">{r.displayAvatar || '👤'}</Text>
                <Text className={`chip-name ${selectedRecipientId === r.id ? 'selected' : ''}`}>{r.name}</Text>
              </View>
            ))}
          </View>
        </ScrollView>
      )}

      {/* 类型筛选行 — 使用图标 + 文字 */}
      <ScrollView className="type-filter-row" scrollX>
        <View className="type-chips">
          {CARE_LOG_TYPES.map((t) => (
            <View
              key={t.key ?? 'all'}
              className={`type-chip ${filterType === t.key ? 'active' : ''}`}
              style={filterType === t.key && t.color ? { backgroundColor: t.color, borderColor: t.color } : {}}
              onClick={() => handleTypeChange(t.key)}
            >
              <Text className="type-chip-emoji">{t.emoji}</Text>
              <Text
                className={`type-chip-label ${filterType === t.key ? 'active' : ''}`}
              >
                {t.label}
              </Text>
            </View>
          ))}
        </View>
      </ScrollView>

      {/* 时间线列表 */}
      {!familyId ? (
        <View className="empty-state">
          <Image className="empty-icon-img" src={require('../../assets/icons/info.png')} mode="aspectFit" />
          <Text className="empty-title">请先加入家庭</Text>
          <Text className="empty-desc">在设置页加入或创建家庭后查看日志</Text>
        </View>
      ) : dayGroups.length === 0 && !loading ? (
        <View className="empty-state">
          <Image className="empty-icon-img" src={require('../../assets/icons/doc.png')} mode="aspectFit" />
          <Text className="empty-title">还没有日志</Text>
          <Text className="empty-desc">记下第一条吧</Text>
        </View>
      ) : (
        <ScrollView
          className="timeline-scroll"
          scrollY
          onScrollToLower={onScrollToLower}
          scrollWithAnimation
          refresherEnabled
          refresherTriggered={refreshing}
          onRefresherRefresh={() => {
            setRefreshing(true);
            loadTimeline(true)
              .catch(() => {})
              .finally(() => setRefreshing(false));
          }}
        >
          {dayGroups.map((group) => (
            <View key={group.dateISO} className="day-group">
              {/* 日期头：pill 标签 + 横向分隔线 */}
              <View className="date-header">
                <View
                  className={`date-label-wrap ${
                    group.dateLabel === '今天' ? 'today' :
                    group.dateLabel === '昨天' ? 'yesterday' : 'past'
                  }`}
                >
                  <Text className={`date-label ${
                    group.dateLabel === '今天' ? 'today' :
                    group.dateLabel === '昨天' ? 'yesterday' : 'past'
                  }`}>
                    {group.dateLabel}
                  </Text>
                </View>
                <View className="date-line" />
              </View>

              {/* 日志卡片列表 */}
              {group.logs.map((log) => {
                const typeDef = getTypeDef(log.type);
                const isHealth = log.source === 'health_record';
                const isMedication = log.source === 'medication';
                const isCheckin = log.source === 'daily_care_checkin';
                const range = isHealth ? checkHealthRange(log.recordType || '', log.healthValue) : 'normal';

                // 颜色
                const baseColor = isMedication ? '#4A90D9' : isCheckin ? '#7B9E87' : typeDef.color;
                const alertColor = range === 'high' ? '#E84040' : range === 'low' ? '#F5A623' : baseColor;

                // emoji
                const cardEmoji = isMedication ? '💊' : isCheckin
                  ? (log.checkinStatus === 'normal' ? '😊' : log.checkinStatus === 'concerning' ? '😟' : log.checkinStatus === 'poor' ? '😰' : '🆘')
                  : isHealth ? HEALTH_METRIC_TYPES.find(m => m.key === log.recordType)?.emoji || '🩺' : typeDef.emoji;

                // 护理打卡状态颜色
                const checkinColor = log.checkinStatus === 'normal' ? '#7B9E87'
                  : log.checkinStatus === 'concerning' ? '#D4A855'
                  : log.checkinStatus === 'poor' ? '#E07B5D'
                  : log.checkinStatus === 'critical' ? '#C0392B' : baseColor;

                // 超范围时卡片加边框
                const isAlertCard = isHealth && range !== 'normal';

                // 时间格式：护理打卡显示日期，其他显示时间
                const timeText = isCheckin ? log.createdAt.substring(0, 10) : formatTime(log.createdAt);

                return (
                  <View key={log.id} className="log-item-row">
                    {/* 左侧：圆形 emoji 指示器 */}
                    <View className="log-indicator">
                      <View
                        className="log-indicator-circle"
                        style={{
                          backgroundColor: `${alertColor}1A`,
                          borderColor: isAlertCard ? alertColor : `${alertColor}4D`,
                          borderWidth: isAlertCard ? '3rpx' : '1rpx',
                        }}
                      >
                        <Text className="log-indicator-emoji">{cardEmoji}</Text>
                      </View>
                    </View>

                    {/* 右侧：卡片 */}
                    <View
                      className={`log-card ${isAlertCard ? 'log-card-alert' : ''}`}
                      style={isAlertCard ? { borderColor: `${alertColor}66`, borderWidth: '1.5rpx' } : {}}
                    >
                      {/* 卡片顶部行 */}
                      <View className="log-card-top-row">
                        <Text className="log-time">{timeText}</Text>

                        {isHealth && log.recordType && (
                          <View className="log-type-badge" style={{ backgroundColor: `${baseColor}1A` }}>
                            <Text className="log-type-badge-text" style={{ color: baseColor }}>
                              {HEALTH_METRIC_TYPES.find(m => m.key === log.recordType)?.label || ''}
                            </Text>
                          </View>
                        )}
                        {!isHealth && (
                          <View className="log-type-badge" style={{ backgroundColor: `${alertColor}1A` }}>
                            <Text className="log-type-badge-text" style={{ color: alertColor }}>
                              {isMedication ? '服药' : isCheckin ? `护理打卡 · ${log.checkinStatus === 'normal' ? '状态良好' : log.checkinStatus === 'concerning' ? '需要关注' : log.checkinStatus === 'poor' ? '状态较差' : '紧急情况'}` : typeDef.label}
                            </Text>
                          </View>
                        )}

                        {/* 偏高/偏低标签（在头像前） */}
                        {range !== 'normal' && (
                          <View
                            className="log-alert-badge"
                            style={{ backgroundColor: range === 'high' ? 'rgba(232,64,64,0.12)' : 'rgba(245,166,35,0.12)' }}
                          >
                            <Text
                              className="log-alert-badge-text"
                              style={{ color: range === 'high' ? '#E84040' : '#F5A623' }}
                            >
                              {range === 'high' ? '偏高' : '偏低'}
                            </Text>
                          </View>
                        )}

                        {/* 头像 + 名字（偏高偏低时不显示右侧头像） */}
                        {!isAlertCard && (
                          <View className="log-card-top-right">
                            {log.authorAvatar ? (
                              <Image
                                className="log-author-avatar"
                                src={getImageUrl(log.authorAvatar || '')}
                                mode="aspectFill"
                              />
                            ) : (
                              <View className="log-author-avatar-placeholder">
                                <Text className="log-author-avatar-text">{(log.authorName || '家')[0]}</Text>
                              </View>
                            )}
                            <Text className="log-author-name">{log.authorName || '家庭成员'}</Text>
                          </View>
                        )}
                      </View>

                      {/* 卡片内容区 */}
                      {isCheckin ? (
                        /* 每日护理打卡：emoji + 状态 + 用药进度 + 备注 */
                        <View className="checkin-card-body">
                          <View
                            className="checkin-emoji-box"
                            style={{
                              borderColor: `${checkinColor}4D`,
                              backgroundColor: `${checkinColor}1A`,
                            }}
                          >
                            <Text className="checkin-emoji">{cardEmoji}</Text>
                          </View>
                          <View className="checkin-info">
                            <Text className="checkin-status" style={{ color: checkinColor }}>
                              {log.checkinStatus === 'normal' ? '状态良好'
                                : log.checkinStatus === 'concerning' ? '需要关注'
                                : log.checkinStatus === 'poor' ? '状态较差'
                                : log.checkinStatus === 'critical' ? '紧急情况'
                                : '护理打卡'}
                            </Text>
                            {log.medicationTotal && log.medicationTotal > 0 && (
                              <Text className="checkin-med-progress">
                                用药：{log.medicationCompleted ?? 0}/{log.medicationTotal} 项已完成
                              </Text>
                            )}
                            {log.specialNote && (
                              <Text className="checkin-note">备注：{log.specialNote}</Text>
                            )}
                          </View>
                        </View>
                      ) : (
                        <>
                          <Text
                            className={`log-content ${range !== 'normal' ? 'log-content-alert' : ''}`}
                            style={range !== 'normal' ? { color: alertColor } : {}}
                          >
                            {log.content}
                          </Text>
                          {/* 超范围时显示参考范围 */}
                          {isHealth && range !== 'normal' && (
                            <Text className="log-range-hint">
                              参考范围：{HEALTH_NORMAL_RANGES[log.recordType || ''] || ''}
                            </Text>
                          )}
                        </>
                      )}

                      {/* 附件图片 */}
                      {log.attachments && log.attachments.length > 0 && (
                        <View className="attachment-grid">
                          {log.attachments.slice(0, 4).map((att, idx) => (
                            <View
                              key={idx}
                              className={`attachment-item ${log.attachments.length === 1 ? 'single' : ''}`}
                              onClick={() => {
                                Taro.previewImage({
                                  urls: log.attachments.map((a) => getAttachmentUrl(a.url)),
                                  current: getAttachmentUrl(att.url),
                                });
                              }}
                            >
                              <Image
                                className="attachment-img"
                                src={getAttachmentUrl(att.url)}
                                mode="aspectFill"
                              />
                              {idx === 3 && log.attachments.length > 4 && (
                                <View className="attachment-more">
                                  <Text className="attachment-more-text">+{log.attachments.length - 4}</Text>
                                </View>
                              )}
                            </View>
                          ))}
                        </View>
                      )}
                    </View>
                  </View>
                );
              })}
            </View>
          ))}

          {loading && (
            <View className="loading-more">
              <Text className="loading-text">加载中...</Text>
            </View>
          )}

          {!hasMore && dayGroups.length > 0 && (
            <View className="end-tip">
              <Text className="end-tip-text">没有更多了</Text>
            </View>
          )}

          <View className="bottom-pad" />
        </ScrollView>
      )}

      {/* FAB 记一笔 — 使用图标 */}
      {familyId && (
        <View className="fab" onClick={() => setShowAddSheet(true)}>
          <Image className="fab-icon" src={require('../../assets/icons/care-add.png')} mode="aspectFit" />
          <Text className="fab-label">记一笔</Text>
        </View>
      )}

      {/* 添加日志底部弹窗 */}
      {showAddSheet && (
        <View className="sheet-overlay" onClick={closeSheet}>
          <View className="add-sheet" onClick={(e) => e.stopPropagation()}>
            {/* 拖拽条 */}
            <View className="sheet-handle" />

            {/* 头部：标题 + 关闭按钮 */}
            <View className="sheet-header">
              <Text className="sheet-title">{addType === 'health' ? '记录健康数据' : '记一笔'}</Text>
              <View className="sheet-close-btn" onClick={closeSheet}>
                <Image
                  className="sheet-close-icon"
                  src={require('../../assets/icons/care-close.png')}
                  mode="aspectFit"
                />
              </View>
            </View>

            {/* 照护对象选择 */}
            {recipients.length > 0 && (
              <View className="sheet-section">
                <Text className="sheet-label">照护对象</Text>
                <ScrollView className="sheet-recipients" scrollX>
                  <View className="sheet-recipient-chips">
                    {recipients.map((r) => (
                      <View
                        key={r.id}
                        className={`sheet-recipient-chip ${addRecipientId === r.id ? 'selected' : ''}`}
                        onClick={() => setAddRecipientId(r.id)}
                      >
                        <Text className="chip-emoji">{r.displayAvatar || '👤'}</Text>
                        <Text className="chip-name">{r.name}</Text>
                      </View>
                    ))}
                  </View>
                </ScrollView>
              </View>
            )}

            {/* 类型选择：Wrap 排列，带图标 + 文字 */}
            <View className="sheet-section">
              <Text className="sheet-label">类型</Text>
              <View className="sheet-type-chips-wrap">
                {CARE_LOG_TYPES.filter((t) => t.key !== null).map((t) => (
                  <View
                    key={t.key}
                    className={`sheet-type-chip ${addType === t.key ? 'active' : ''}`}
                    style={addType === t.key && t.color ? { backgroundColor: t.color } : {}}
                    onClick={() => {
                      setAddType(t.key!);
                      if (t.key !== 'health') {
                        setAddHealthMetric('');
                      }
                    }}
                  >
                    <Text className="sheet-type-emoji">{t.emoji}</Text>
                    <Text className={`sheet-type-label ${addType === t.key ? 'active' : ''}`}>{t.label}</Text>
                  </View>
                ))}
              </View>
            </View>

            {addType === 'health' ? (
              <>
                {/* 健康指标选择 */}
                <View className="sheet-section">
                  <Text className="sheet-label">选择指标</Text>
                  <View className="sheet-type-chips-wrap">
                    {HEALTH_METRIC_TYPES.map((m) => (
                      <View
                        key={m.key}
                        className={`sheet-type-chip ${addHealthMetric === m.key ? 'active' : ''}`}
                        style={addHealthMetric === m.key ? { backgroundColor: '#7B9E87' } : {}}
                        onClick={() => setAddHealthMetric(m.key)}
                      >
                        <Text className="sheet-type-emoji">{m.emoji}</Text>
                        <Text className={`sheet-type-label ${addHealthMetric === m.key ? 'active' : ''}`}>{m.label}</Text>
                      </View>
                    ))}
                  </View>
                </View>

                {/* 参考范围提示 */}
                {addHealthMetric && HEALTH_NORMAL_RANGES[addHealthMetric] && (
                  <View className="sheet-section">
                    <View className="health-range-hint">
                      <Text className="health-range-hint-text">
                        参考范围：{HEALTH_NORMAL_RANGES[addHealthMetric]}
                      </Text>
                    </View>
                  </View>
                )}

                {/* 健康指标输入 */}
                {addHealthMetric === 'blood_pressure' && (
                  <View className="sheet-section">
                    <View className="health-input-row">
                      <View className="health-input-item">
                        <Text className="sheet-label">收缩压 (mmHg)</Text>
                        <View className="health-input-wrap">
                          <input
                            className="health-input"
                            type="number"
                            placeholder="120"
                            value={bpSys}
                            onInput={(e: any) => setBpSys(e.detail.value)}
                          />
                        </View>
                      </View>
                      <Text className="health-input-sep">/</Text>
                      <View className="health-input-item">
                        <Text className="sheet-label">舒张压 (mmHg)</Text>
                        <View className="health-input-wrap">
                          <input
                            className="health-input"
                            type="number"
                            placeholder="80"
                            value={bpDia}
                            onInput={(e: any) => setBpDia(e.detail.value)}
                          />
                        </View>
                      </View>
                    </View>
                  </View>
                )}

                {addHealthMetric === 'blood_glucose' && (
                  <View className="sheet-section">
                    <View className="health-input-row">
                      <View className="health-input-item" style={{ flex: 1 }}>
                        <Text className="sheet-label">血糖值 (mmol/L)</Text>
                        <View className="health-input-wrap">
                          <input
                            className="health-input"
                            type="digit"
                            placeholder="5.6"
                            value={glucoseVal}
                            onInput={(e: any) => setGlucoseVal(e.detail.value)}
                          />
                        </View>
                      </View>
                    </View>
                    <View className="health-type-toggle">
                      <View
                        className={`health-type-btn ${glucoseType === 'fasting' ? 'active' : ''}`}
                        onClick={() => setGlucoseType('fasting')}
                      >
                        <Text className={`health-type-btn-text ${glucoseType === 'fasting' ? 'active' : ''}`}>空腹</Text>
                      </View>
                      <View
                        className={`health-type-btn ${glucoseType === 'postprandial' ? 'active' : ''}`}
                        onClick={() => setGlucoseType('postprandial')}
                      >
                        <Text className={`health-type-btn-text ${glucoseType === 'postprandial' ? 'active' : ''}`}>餐后</Text>
                      </View>
                    </View>
                  </View>
                )}

                {addHealthMetric === 'weight' && (
                  <View className="sheet-section">
                    <View className="health-input-row">
                      <View className="health-input-item" style={{ flex: 1 }}>
                        <Text className="sheet-label">体重</Text>
                        <View className="health-input-wrap">
                          <input
                            className="health-input"
                            type="digit"
                            placeholder="60"
                            value={weightVal}
                            onInput={(e: any) => setWeightVal(e.detail.value)}
                          />
                        </View>
                      </View>
                    </View>
                    <View className="health-type-toggle">
                      <View
                        className={`health-type-btn ${weightUnit === 'kg' ? 'active' : ''}`}
                        onClick={() => setWeightUnit('kg')}
                      >
                        <Text className={`health-type-btn-text ${weightUnit === 'kg' ? 'active' : ''}`}>公斤</Text>
                      </View>
                      <View
                        className={`health-type-btn ${weightUnit === 'jin' ? 'active' : ''}`}
                        onClick={() => setWeightUnit('jin')}
                      >
                        <Text className={`health-type-btn-text ${weightUnit === 'jin' ? 'active' : ''}`}>斤</Text>
                      </View>
                    </View>
                  </View>
                )}

                {/* 备注 */}
                <View className="sheet-section">
                  <Text className="sheet-label">备注（选填）</Text>
                  <View className="content-input-wrap">
                    <textarea
                      className="content-input"
                      placeholder="测量时状态..."
                      value={addContent}
                      onInput={(e: any) => setAddContent(e.detail.value)}
                      maxLength={200}
                    />
                  </View>
                </View>
              </>
            ) : (
              <>
                {/* 内容输入 */}
                <View className="sheet-section">
                  <Text className="sheet-label">内容</Text>
                  <View className="content-input-wrap">
                    <textarea
                      className="content-input"
                      placeholder="记录今天发生了什么..."
                      value={addContent}
                      onInput={(e: any) => setAddContent(e.detail.value)}
                      maxLength={1000}
                    />
                  </View>
                </View>

                {/* 图片附件 */}
                <View className="sheet-section attach-section">
                  <Text className="sheet-label">图片（选填）</Text>
                  <View className="attach-row">
                    {pendingAttachments.map((att) => (
                      <View key={att.id} className="attach-thumb">
                        <Image
                          className="attach-img"
                          src={att.localPath}
                          mode="aspectFill"
                        />
                        {att.uploading && (
                          <View className="attach-uploading">
                            <Text className="attach-uploading-text">上传中</Text>
                          </View>
                        )}
                        {att.failed && (
                          <View className="attach-failed">
                            <Text className="attach-failed-text">失败</Text>
                          </View>
                        )}
                        <View
                          className="attach-remove"
                          onClick={() => removeAttachment(att.id)}
                        >
                          <Image
                            className="attach-remove-icon"
                            src={require('../../assets/icons/care-close.png')}
                            mode="aspectFit"
                          />
                        </View>
                      </View>
                    ))}
                    {pendingAttachments.length < 9 && (
                      <View className="attach-add-btn" onClick={handleChooseImages}>
                        <Image
                          className="attach-add-icon-img"
                          src={require('../../assets/icons/care-add.png')}
                          mode="aspectFit"
                        />
                      </View>
                    )}
                  </View>
                </View>
              </>
            )}

            {/* 发送按钮 */}
            <View className="sheet-footer">
              <View
                className={`send-btn ${submitting || hasUploading ? 'disabled' : ''}`}
                onClick={hasUploading || submitting ? undefined : handleAddLog}
              >
                <Text className="send-btn-text">
                  {submitting ? '发送中...' : hasUploading ? '上传中...' : '发送'}
                </Text>
              </View>
            </View>
          </View>
        </View>
      )}
    </View>
  );
}
