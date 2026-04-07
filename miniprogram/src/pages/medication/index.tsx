/**
 * 用药管理页面
 * - 无参数：药品列表页（底部浮动添加按钮）
 * - ?action=add：添加药品表单
 * - ?action=edit&medicationId=xxx：编辑药品表单
 * - ?medicationId=xxx（无action）：打卡弹窗（原有的 MedicationCheckInSheet 逻辑）
 * 对齐 Flutter medication_management_page.dart
 */

import { View, Text, ScrollView, Input, Button, Image, Picker } from '@tarojs/components';
import Taro, { useRouter } from '@tarojs/taro';
import { useEffect, useState } from 'react';
import { get, post, patch, del } from '../../services/api';
import { Storage } from '../../services/storage';
import { MedicationLogStatus } from '../../shared/models/medication';
import type { Medication } from '../../shared/models/medication';
import type { CareRecipient } from '../../shared/models/care-recipient';
import type { MedicationLog } from '../../shared/models/medication';
import './index.scss';

// ═══════════════════════════════════════════════════════════════════
// 服用时间选项
// ═══════════════════════════════════════════════════════════════════

const TIME_OPTIONS = [
  { label: '早餐', value: 'breakfast' },
  { label: '午餐', value: 'lunch' },
  { label: '晚餐', value: 'dinner' },
  { label: '睡前', value: 'bedtime' },
] as const;

type TimeValue = typeof TIME_OPTIONS[number]['value'];

const TIME_LABEL: Record<string, string> = {
  breakfast: '早餐',
  lunch: '午餐',
  dinner: '晚餐',
  bedtime: '睡前',
};

/** 时间值 → 24h 时钟字符串（存储到后端 times 字段） */
const TIME_HOUR: Record<TimeValue, string> = {
  breakfast: '08:00',
  lunch: '12:00',
  dinner: '18:00',
  bedtime: '21:00',
};

// ═══════════════════════════════════════════════════════════════════
// 跳过原因（打卡页用）
// ═══════════════════════════════════════════════════════════════════

const SKIP_REASONS = ['忘记了', '身体不适', '医生建议停药', '已自行服药', '其他'];

// ═══════════════════════════════════════════════════════════════════
// 打卡页组件
// ═══════════════════════════════════════════════════════════════════

function CheckInSheet(props: {
  medicationId: string;
  medicationName: string;
  dosage: string;
  scheduledTime: string;
  recipientId: string;
  status: string;
}) {
  const [loading, setLoading] = useState(false);
  const [loadingHistory, setLoadingHistory] = useState(true);
  const [history, setHistory] = useState<MedicationLog[]>([]);
  const [showReasonSheet, setShowReasonSheet] = useState(false);

  const isDone =
    props.status === MedicationLogStatus.TAKEN ||
    props.status === MedicationLogStatus.SKIPPED;

  const loadHistory = async () => {
    if (!props.medicationId || !props.recipientId) return;
    const familyId = Storage.getCurrentFamilyId();
    if (!familyId) return;
    try {
      const data = await get<MedicationLog[]>('/medication-logs/history', {
        familyId,
        recipientId: props.recipientId,
      });
      setHistory(Array.isArray(data) ? data : []);
    } catch (err) {
      console.error('加载历史记录失败', err);
    } finally {
      setLoadingHistory(false);
    }
  };

  useEffect(() => { loadHistory(); }, []);

  const handleCheckIn = async () => {
    if (isDone || loading) return;
    const familyId = Storage.getCurrentFamilyId();
    if (!familyId || !props.medicationId) return;
    setLoading(true);
    try {
      await post(`/medication-logs/${props.medicationId}/check-in`, {
        familyId,
        status: 'taken',
      });
      Taro.showToast({ title: '打卡成功', icon: 'success', duration: 1500 });
      setTimeout(() => Taro.navigateBack(), 1500);
    } catch (err) {
      console.error('打卡失败', err);
    } finally {
      setLoading(false);
    }
  };

  const handleDelay = () => {
    if (isDone) return;
    Taro.showToast({ title: '已设置 15 分钟后提醒', icon: 'none', duration: 2000 });
    Taro.navigateBack();
  };

  const handleSkip = async (reason: string) => {
    if (isDone || loading) return;
    const familyId = Storage.getCurrentFamilyId();
    if (!familyId || !props.medicationId) return;
    setLoading(true);
    try {
      await post(`/medication-logs/${props.medicationId}/check-in`, {
        familyId,
        status: 'skipped',
        note: reason,
      });
      Taro.showToast({ title: '已跳过', icon: 'none', duration: 1500 });
      setTimeout(() => Taro.navigateBack(), 1500);
    } catch (err) {
      console.error('跳过失败', err);
    } finally {
      setLoading(false);
    }
  };

  const formatTime = (timeStr: string | null | undefined): string => {
    if (!timeStr) return '--';
    const parts = timeStr.split(' ');
    if (parts.length < 2) return timeStr;
    const date = parts[0].split('-');
    if (date.length < 3) return timeStr;
    return `${date[1]}/${date[2]} ${parts[1].substring(0, 5)}`;
  };

  const statusText = (s: MedicationLogStatus): string => {
    switch (s) {
      case MedicationLogStatus.TAKEN: return '已服用';
      case MedicationLogStatus.SKIPPED: return '已跳过';
      case MedicationLogStatus.MISSED: return '已错过';
      default: return '待打卡';
    }
  };

  const statusColor = (s: MedicationLogStatus): string => {
    switch (s) {
      case MedicationLogStatus.TAKEN: return '#6BA07E';
      case MedicationLogStatus.SKIPPED: return '#B0ADAD';
      case MedicationLogStatus.MISSED: return '#E07B5D';
      default: return '#6B6B6B';
    }
  };

  return (
    <View className="med-checkin-page">
      <View className="sheet-overlay" onClick={() => Taro.navigateBack()} />
      <View className="sheet-container">
        <ScrollView className="sheet-scroll" scrollY>
          <View className="drag-handle" />
          <Text className="med-name">{props.medicationName || '未知药品'}</Text>
          <Text className="med-sub">
            {props.dosage || ''}{props.dosage && props.scheduledTime ? ' · ' : ''}{props.scheduledTime || ''}
          </Text>

          <View className="action-area">
            <View
              className={`checkin-btn ${isDone ? 'done' : ''} ${loading && !isDone ? 'loading' : ''}`}
              onClick={handleCheckIn}
            >
              {loading && !isDone ? (
                <View className="spinner" />
              ) : (
                <>
                  <Text className="checkin-icon">✓</Text>
                  <Text className="checkin-label">{isDone ? '已完成' : '打卡'}</Text>
                </>
              )}
            </View>
          </View>

          <View className="secondary-actions">
            <View
              className={`btn-outline btn-delay ${isDone ? 'disabled' : ''}`}
              onClick={isDone ? undefined : handleDelay}
            >
              <Text className="btn-outline-icon">⏰</Text>
              <Text className="btn-outline-text">稍后 15 分钟</Text>
            </View>
            <View
              className={`btn-outline btn-skip ${isDone ? 'disabled' : ''}`}
              onClick={isDone ? undefined : () => setShowReasonSheet(true)}
            >
              <Text className="btn-outline-icon">✕</Text>
              <Text className="btn-outline-text">跳过</Text>
            </View>
          </View>

          <View className="divider" />

          <View className="history-section">
            <Text className="history-title">用药记录</Text>
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
              history.slice(0, 5).map((log) => {
                const color = statusColor(log.status);
                const authorName = log.takenBy?.name || '家庭成员';
                return (
                  <View key={log.id} className="history-item">
                    <View className="history-dot" style={{ backgroundColor: color }} />
                    <Text className="history-time">{formatTime(log.actualTime || log.createdAt)}</Text>
                    <View className="history-badge" style={{ color, backgroundColor: `${color}1A` }}>
                      <Text className="history-badge-text">{statusText(log.status)}</Text>
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

          <View className="bottom-pad" />
        </ScrollView>
      </View>

      {showReasonSheet && (
        <View className="reason-overlay" onClick={() => setShowReasonSheet(false)}>
          <View className="reason-sheet" onClick={(e) => e.stopPropagation()}>
            <Text className="reason-title">选择跳过原因</Text>
            {SKIP_REASONS.map((reason) => (
              <View
                key={reason}
                className="reason-item"
                onClick={() => { setShowReasonSheet(false); handleSkip(reason); }}
              >
                <Text className="reason-item-text">{reason}</Text>
              </View>
            ))}
            <View className="reason-cancel" onClick={() => setShowReasonSheet(false)}>
              <Text className="reason-cancel-text">取消</Text>
            </View>
          </View>
        </View>
      )}
    </View>
  );
}

// ═══════════════════════════════════════════════════════════════════
// 药品管理主页面
// ═══════════════════════════════════════════════════════════════════

export default function MedicationPage() {
  const router = useRouter();

  // 解析 URL 参数
  const action = (router.params.action as string) as 'add' | 'edit' | undefined;
  const medicationId = router.params.medicationId as string | undefined;
  const addForRecipientId = router.params.addForRecipientId as string | undefined;
  const isCheckIn = !!medicationId && !action && !addForRecipientId; // 只有 medicationId，无 action → 打卡
  const isEdit = action === 'edit' && !!medicationId;
  const isAdd = action === 'add' || !!addForRecipientId; // action=add 或有 addForRecipientId 都显示添加表单

  // ── 列表状态 ──────────────────────────────────────────────
  const [medications, setMedications] = useState<Medication[]>([]);
  const [loading, setLoading] = useState(true);

  // ── 表单状态 ──────────────────────────────────────────────
  const [name, setName] = useState('');
  const [dosage, setDosage] = useState('');
  const [selectedTimes, setSelectedTimes] = useState<TimeValue[]>([]);
  const [frequency, setFrequency] = useState<'daily' | 'weekly' | 'as_needed'>('daily');
  const [startDate, setStartDate] = useState(() => {
    const d = new Date();
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  });
  const [endDate, setEndDate] = useState<string>('');
  const [instructions, setInstructions] = useState('');
  const [prescribedBy, setPrescribedBy] = useState('');
  const [recipientIndex, setRecipientIndex] = useState<number>(0);
  const [recipients, setRecipients] = useState<CareRecipient[]>([]);
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState('');

  // ── 加载药品列表 ──────────────────────────────────────────
  const loadMedications = async () => {
    const familyId = Storage.getCurrentFamilyId();
    if (!familyId) { setLoading(false); return; }
    try {
      const data = await get<Medication[]>(`/medications?familyId=${familyId}`);
      setMedications(Array.isArray(data) ? data : []);
    } catch (err) {
      console.error('加载药品列表失败:', err);
      setMedications([]);
    } finally {
      setLoading(false);
    }
  };

  // ── 加载照护对象 ──────────────────────────────────────────
  const loadRecipients = async () => {
    const familyId = Storage.getCurrentFamilyId();
    if (!familyId) return;
    try {
      const data = await get<CareRecipient[]>(`/care-recipients?familyId=${familyId}`);
      setRecipients(Array.isArray(data) ? data : []);
    } catch (err) {
      console.error('加载照护对象失败:', err);
    }
  };

  // ── 加载编辑药品详情 ──────────────────────────────────────
  const loadMedicationDetail = async (id: string) => {
    try {
      const data = await get<Medication>(`/medications/${id}`);
      setName(data.name || '');
      setDosage(data.dosage || '');
      setFrequency(data.frequency || 'daily');
      setInstructions(data.instructions || '');
      setPrescribedBy(data.prescribedBy || '');
      if (data.startDate) setStartDate(data.startDate.slice(0, 10));
      if (data.endDate) setEndDate(data.endDate.slice(0, 10));

      // times 可能是 ["08:00", "12:00"] 或 ["breakfast", "lunch"]
      const hourToTime: Record<string, TimeValue> = {
        '08:00': 'breakfast',
        '12:00': 'lunch',
        '18:00': 'dinner',
        '21:00': 'bedtime',
      };
      const times = (data.times || [])
        .map((t: string) => (hourToTime[t] ?? t) as TimeValue)
        .filter((t: string) => TIME_OPTIONS.some((o) => o.value === t));
      setSelectedTimes(times as TimeValue[]);

      const idx = recipients.findIndex((r) => r.id === data.recipientId);
      if (idx >= 0) setRecipientIndex(idx);
    } catch (err) {
      console.error('加载药品详情失败:', err);
    }
  };

  useEffect(() => {
    if (isAdd) {
      Taro.setNavigationBarTitle({ title: '添加药品' });
      loadRecipients();
    } else if (isEdit) {
      Taro.setNavigationBarTitle({ title: '编辑药品' });
      loadRecipients().then(() => {
        if (medicationId) loadMedicationDetail(medicationId);
      });
    } else if (!isCheckIn) {
      Taro.setNavigationBarTitle({ title: '用药管理' });
      loadMedications();
    } else {
      Taro.setNavigationBarTitle({ title: '用药打卡' });
    }
  }, [isAdd, isEdit, isCheckIn, medicationId]);

  // 当 recipients 加载完毕后，如果有 addForRecipientId 则自动预选
  useEffect(() => {
    if (addForRecipientId && recipients.length > 0) {
      const idx = recipients.findIndex((r) => r.id === addForRecipientId);
      if (idx >= 0) setRecipientIndex(idx);
    }
  }, [addForRecipientId, recipients]);

  // ── 切换服用时间 ──────────────────────────────────────────
  const toggleTime = (value: TimeValue) => {
    setSelectedTimes((prev) =>
      prev.includes(value) ? prev.filter((t) => t !== value) : [...prev, value]
    );
    setFormError('');
  };

  // ── 提交表单 ─────────────────────────────────────────────
  const handleSubmit = async () => {
    const familyId = Storage.getCurrentFamilyId();
    if (!familyId) { Taro.showToast({ title: '请先加入家庭', icon: 'none' }); return; }
    if (!name.trim()) { setFormError('请输入药品名称'); return; }
    if (!dosage.trim()) { setFormError('请输入剂量'); return; }
    if (selectedTimes.length === 0) { setFormError('请至少选择一种服用时间'); return; }
    if (recipientIndex < 0 || recipientIndex >= recipients.length) {
      setFormError('请选择照护对象'); return;
    }

    setSubmitting(true);
    setFormError('');

    const payload: Record<string, any> = {
      familyId,
      recipientId: recipients[recipientIndex].id,
      name: name.trim(),
      dosage: dosage.trim(),
      times: selectedTimes.map((t) => TIME_HOUR[t]),
      frequency,
      startDate,
    };
    if (endDate) payload.endDate = endDate;
    if (instructions.trim()) payload.instructions = instructions.trim();
    if (prescribedBy.trim()) payload.prescribedBy = prescribedBy.trim();

    try {
      if (isAdd) {
        await post('/medications', payload);
        Taro.showToast({ title: '添加成功', icon: 'success' });
        // 如果是为特定照护对象添加，提交后返回详情页
        const nextUrl = addForRecipientId
          ? `/pages/care-recipient/detail?id=${addForRecipientId}`
          : '/pages/medication/index';
        setTimeout(() => Taro.redirectTo({ url: nextUrl }), 1500);
      } else {
        await patch(`/medications/${medicationId}?familyId=${familyId}`, payload);
        Taro.showToast({ title: '保存成功', icon: 'success' });
        setTimeout(() => Taro.navigateBack(), 1500);
      }
    } catch (err: any) {
      Taro.showToast({ title: err.message || '保存失败', icon: 'none' });
      setSubmitting(false);
    }
  };

  const goBack = () => Taro.redirectTo({ url: '/pages/medication/index' });

  // ── 打卡视图 ─────────────────────────────────────────────
  if (isCheckIn) {
    return (
      <CheckInSheet
        medicationId={medicationId!}
        medicationName={decodeURIComponent(router.params.medicationName || '')}
        dosage={decodeURIComponent(router.params.dosage || '')}
        scheduledTime={decodeURIComponent(router.params.scheduledTime || '')}
        recipientId={router.params.recipientId || ''}
        status={router.params.status || 'pending'}
      />
    );
  }

  // ── 添加 / 编辑表单视图 ───────────────────────────────────
  if (isAdd || isEdit) {
    return (
      <View className="med-page">
        <ScrollView className="med-scroll" scrollY>
          <View className="form-section">
            {/* 页面标题 */}
            <Text className="form-page-title">{isAdd ? '添加药品' : '编辑药品'}</Text>

            {/* 药品名称 */}
            <View className="form-group">
              <Text className="form-label">药品名称</Text>
              <Input
                className="form-input"
                placeholder="如：氨氯地平"
                placeholder-class="form-placeholder"
                value={name}
                onInput={(e) => { setName(e.detail.value); setFormError(''); }}
                maxLength={50}
              />
            </View>

            {/* 剂量 */}
            <View className="form-group">
              <Text className="form-label">剂量</Text>
              <Input
                className="form-input"
                placeholder="如：1片、5mg"
                placeholder-class="form-placeholder"
                value={dosage}
                onInput={(e) => { setDosage(e.detail.value); setFormError(''); }}
                maxLength={30}
              />
            </View>

            {/* 服用时间 */}
            <View className="form-group">
              <Text className="form-label">服用时间</Text>
              <View className="time-grid">
                {TIME_OPTIONS.map((opt) => (
                  <View
                    key={opt.value}
                    className={`time-check-btn ${selectedTimes.includes(opt.value) ? 'checked' : ''}`}
                    onClick={() => toggleTime(opt.value)}
                  >
                    <Text className={`time-check-label ${selectedTimes.includes(opt.value) ? 'checked' : ''}`}>
                      {opt.label}
                    </Text>
                  </View>
                ))}
              </View>
            </View>

            {/* 用药频率 */}
            <View className="form-group">
              <Text className="form-label">用药频率</Text>
              <View className="freq-grid">
                {(['daily', 'weekly', 'as_needed'] as const).map((f) => (
                  <View
                    key={f}
                    className={`freq-btn ${frequency === f ? 'checked' : ''}`}
                    onClick={() => setFrequency(f)}
                  >
                    <Text className={`freq-label ${frequency === f ? 'checked' : ''}`}>
                      {f === 'daily' ? '每日' : f === 'weekly' ? '每周' : '按需'}
                    </Text>
                  </View>
                ))}
              </View>
            </View>

            {/* 日期范围 */}
            <View className="form-group">
              <Text className="form-label">服药日期</Text>
              <View className="date-row">
                <Picker
                  mode="date"
                  value={startDate}
                  onChange={(e) => setStartDate(e.detail.value)}
                  className="date-field date-picker"
                >
                  <Text className="date-field-text">{startDate}</Text>
                </Picker>
                <Text className="date-sep">至</Text>
                <Picker
                  mode="date"
                  value={endDate || startDate}
                  onChange={(e) => setEndDate(e.detail.value)}
                  className="date-field date-picker"
                >
                  <Text className={`date-field-text ${!endDate ? 'placeholder' : ''}`}>{endDate || '长期服用'}</Text>
                </Picker>
              </View>
            </View>

            {/* 用药说明 */}
            <View className="form-group">
              <Text className="form-label">用药说明</Text>
              <Input
                className="form-input"
                placeholder="如：饭后服用、避免与柚子同食"
                placeholder-class="form-placeholder"
                value={instructions}
                onInput={(e) => setInstructions(e.detail.value)}
                maxLength={200}
              />
            </View>

            {/* 开药医生 */}
            <View className="form-group">
              <Text className="form-label">开药医生</Text>
              <Input
                className="form-input"
                placeholder="如：王建国医生"
                placeholder-class="form-placeholder"
                value={prescribedBy}
                onInput={(e) => setPrescribedBy(e.detail.value)}
                maxLength={50}
              />
            </View>

            {/* 照护对象 */}
            <View className="form-group">
              <Text className="form-label">照护对象</Text>
              {recipients.length === 0 ? (
                <View className="recipient-empty">
                  <Text className="recipient-empty-text">暂无照护对象，请先在家庭中添加</Text>
                </View>
              ) : (
                <View className="picker-wrap">
                  <View className="picker-col">
                    {recipients.map((r, i) => (
                      <View
                        key={r.id}
                        className={`picker-row ${recipientIndex === i ? 'selected' : ''}`}
                        onClick={() => { setRecipientIndex(i); setFormError(''); }}
                      >
                        <View className="recipient-avatar">
                          <Text className="recipient-avatar-text">
                            {r.avatarEmoji || r.name?.[0] || '?'}
                          </Text>
                        </View>
                        <Text className={`recipient-name-text ${recipientIndex === i ? 'selected' : ''}`}>
                          {r.name}
                        </Text>
                        {recipientIndex === i && <Text className="picker-check">✓</Text>}
                      </View>
                    ))}
                  </View>
                </View>
              )}
            </View>

            {formError && <Text className="form-error">{formError}</Text>}

            <Button
              className={`btn-save ${submitting ? 'disabled' : ''}`}
              onClick={handleSubmit}
              disabled={submitting}
            >
              {submitting ? '保存中...' : isAdd ? '添加药品' : '保存修改'}
            </Button>

            {isEdit && (
              <Button
                className="btn-delete"
                onClick={() => {
                  Taro.showModal({
                    title: '确认删除',
                    content: '删除后无法恢复，确定要删除该药品吗？',
                    confirmColor: '#E07B5D',
                    success: async (res) => {
                      if (res.confirm) {
                        const familyId = Storage.getCurrentFamilyId();
                        try {
                          await del(`/medications/${medicationId}`, { params: { familyId } });
                          Taro.showToast({ title: '已删除', icon: 'success' });
                          setTimeout(() => Taro.redirectTo({ url: '/pages/medication/index' }), 1500);
                        } catch {
                          Taro.showToast({ title: '删除失败', icon: 'none' });
                        }
                      }
                    },
                  });
                }}
              >
                删除药品
              </Button>
            )}

            <Button className="btn-cancel" onClick={goBack}>取消</Button>
          </View>
        </ScrollView>
      </View>
    );
  }

  // ── 药品列表视图 ──────────────────────────────────────────
  const familyId = Storage.getCurrentFamilyId();

  if (!familyId) {
    return (
      <View className="med-page">
        <View className="empty-state">
          <Image className="empty-icon" src={require('../../assets/icons/medication.png')} />
          <Text className="empty-title">暂无家庭</Text>
          <Text className="empty-desc">请先加入或创建一个家庭</Text>
          <Button className="btn-primary-empty" onClick={() => Taro.switchTab({ url: '/pages/family/index' })}>
            前往家庭
          </Button>
        </View>
      </View>
    );
  }

  return (
    <View className="med-page">
      {/* 导航栏 */}
      <View className="list-navbar">
        <View className="navbar-left" onClick={() => Taro.navigateBack()}>
          <Text className="navbar-back">‹</Text>
        </View>
        <Text className="navbar-title">用药管理</Text>
        <View className="navbar-right" />
      </View>

      <ScrollView className="med-scroll" scrollY>
        {loading ? (
          <View className="loading-state">
            <Text className="loading-text">加载中...</Text>
          </View>
        ) : medications.length === 0 ? (
          <View className="empty-state">
            <Image className="empty-icon" src={require('../../assets/icons/medication.png')} />
            <Text className="empty-title">暂无药品</Text>
            <Text className="empty-desc">点击下方按钮添加药品</Text>
          </View>
        ) : (
          <View className="med-list">
            {medications.map((med) => (
              <View
                key={med.id}
                className="med-card"
                onClick={() =>
                  Taro.navigateTo({
                    url: `/pages/medication/detail?id=${med.id}`,
                  })
                }
              >
                <View className="med-card-left">
                  <Text className="med-name-text">{med.name}</Text>
                  <Text className="med-dosage-text">{med.dosage || '剂量未填'}</Text>
                </View>
                <View className="med-card-right">
                  <View className="time-tags">
                    {(med.times || []).map((t: string) => (
                      <View key={t} className="time-tag">
                        <Text className="time-tag-text">{TIME_LABEL[t] || t}</Text>
                      </View>
                    ))}
                  </View>
                  <Image className="arrow-icon" src={require('../../assets/icons/calendar.png')} />
                </View>
              </View>
            ))}
          </View>
        )}
        <View className="bottom-pad" />
      </ScrollView>

      {/* 底部浮动添加按钮 */}
      <View className="fab-wrap">
        <View
          className="fab"
          onClick={() => Taro.navigateTo({ url: '/pages/medication/index?action=add' })}
        >
          <Text className="fab-text">+</Text>
        </View>
      </View>
    </View>
  );
}
