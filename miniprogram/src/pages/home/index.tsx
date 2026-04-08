/**
 * 首页 - 与 Flutter home_page.dart 完全对齐
 * 玻璃态顶栏 + 照护对象用药打卡网格 + 每日护理打卡 + 复诊提醒 + 今日任务 + SOS
 */
import { View, Text, ScrollView, Image } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { useState, useCallback, useEffect } from 'react';
import { get, post } from '../../services/api';
import { Storage } from '../../services/storage';
import { store, selectCurrentFamilyId } from '../../store';
import type {
  TodayMedicationSummary,
  MedicationLogItem,
} from '../../shared/models/medication';
import type { CareRecipient } from '../../shared/models/care-recipient';
import type { DailyCareCheckin, CheckinStatus } from '../../shared/models/daily-care-checkin';
import type { Appointment } from '../../shared/models/appointment';
import type { FamilyTask } from '../../shared/models/family-task';
import type { Family } from '../../shared/models/family';
import type { CaregiverRecord } from '../../shared/models/caregiver-record';
import { getImageUrl } from '../../shared/utils/image';
import './index.scss';

// ─── 常量 ───────────────────────────────────────────────────────────────────

/** 颜色 */
const COLOR_PRIMARY = '#7B9E87';   // 鼠尾草绿
const COLOR_CORAL = '#E07B5D';      // 珊瑚色
const COLOR_BLUE = '#4A90D9';       // 蓝色
const COLOR_BG = '#FAF9F7';         // 背景色
const COLOR_SURFACE = '#FFFFFF';
const COLOR_TEXT_PRIMARY = '#2C2C2C';
const COLOR_TEXT_SECONDARY = '#6B6B6B';
const COLOR_TEXT_TERTIARY = '#B0ADAD';
const COLOR_SUCCESS = '#6BA07E';
const COLOR_WARNING = '#F5A623';
const COLOR_CARD_SHADOW = 'rgba(0,0,0,0.04)';

// ─── 类型 ───────────────────────────────────────────────────────────────────

/** 打卡状态图标/颜色 */
interface StatusInfo {
  icon: string; // emoji 或图标名
  color: string;
  label: string;
}

interface HomeState {
  familyName: string;
  familyAvatarUrl: string | null;
  memberCount: number;
  unreadCount: number;
  recipients: CareRecipient[];
  medicationSummaries: TodayMedicationSummary[];
  checkins: Record<string, DailyCareCheckin>;
  caregivers: Record<string, CaregiverRecord>;
  appointments: Appointment[];
  tasks: FamilyTask[];
  loading: boolean;
}

// ─── 辅助函数 ────────────────────────────────────────────────────────────────

/** 问候语 */
function getGreeting(): string {
  const hour = new Date().getHours();
  if (hour < 12) return '早上好';
  if (hour < 18) return '下午好';
  return '晚上好';
}

/** 日期字符串 */
function getDateStr(): string {
  const d = new Date();
  const weekdays = ['日', '一', '二', '三', '四', '五', '六'];
  return `${d.getMonth() + 1}月${d.getDate()}日 周${weekdays[d.getDay()]}`;
}

/** 今天日期 YYYY-MM-DD */
function getTodayDate(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/** 计算药品是否已过时间（当前时间超过计划时间 30 分钟） */
function isOverdue(scheduledTime: string): boolean {
  const now = new Date();
  const [h, m] = scheduledTime.split(':').map(Number);
  const scheduled = new Date();
  scheduled.setHours(h, m, 0, 0);
  return now.getTime() - scheduled.getTime() > 30 * 60 * 1000;
}

/** 药品状态颜色和标签 */
function getMedStatus(item: MedicationLogItem): { color: string; borderColor: string; bgColor: string } {
  const isTaken = item.status === 'taken' || item.status === 'skipped';
  if (isTaken) {
    return { color: COLOR_SUCCESS, borderColor: COLOR_SUCCESS, bgColor: 'rgba(107,160,126,0.08)' };
  }
  // pending / missed
  if (isOverdue(item.scheduledTime)) {
    return { color: COLOR_CORAL, borderColor: COLOR_CORAL, bgColor: 'rgba(224,123,93,0.08)' };
  }
  return { color: COLOR_TEXT_TERTIARY, borderColor: COLOR_TEXT_TERTIARY, bgColor: 'rgba(176,173,173,0.08)' };
}

/** 打卡状态信息 */
function getCheckinStatusInfo(checkin: DailyCareCheckin | undefined): StatusInfo {
  if (!checkin) {
    return { icon: 'schedule', color: COLOR_TEXT_TERTIARY, label: '每日护理打卡' };
  }
  const statusMap: Record<CheckinStatus, StatusInfo> = {
    normal: { icon: 'check_circle', color: COLOR_SUCCESS, label: '状态良好' },
    concerning: { icon: 'info', color: COLOR_WARNING, label: '需要关注' },
    poor: { icon: 'warning', color: COLOR_CORAL, label: '状态较差' },
    critical: { icon: 'error', color: COLOR_CORAL, label: '状态危险' },
  };
  return statusMap[checkin.status] || statusMap.normal;
}

/** 格式化预约时间为 HH:mm */
function formatTime(isoTime: string): string {
  if (!isoTime) return '';
  const d = new Date(isoTime);
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

/** 格式化预约日期为 1月1日（周一） */
function formatDateStr(isoTime: string): string {
  const d = new Date(isoTime);
  const weekdays = ['日', '一', '二', '三', '四', '五', '六'];
  return `${d.getMonth() + 1}月${d.getDate()}日（${weekdays[d.getDay()]}）`;
}

// ─── 主组件 ─────────────────────────────────────────────────────────────────

export default function HomePage() {
  const greeting = getGreeting();
  const dateStr = getDateStr();
  const todayDate = getTodayDate();

  const [isRefreshing, setIsRefreshing] = useState(false);
  const [state, setState] = useState<HomeState>({
    familyName: '我的家庭',
    familyAvatarUrl: null,
    memberCount: 0,
    unreadCount: 0,
    recipients: [],
    medicationSummaries: [],
    checkins: {},
    appointments: [],
    tasks: [],
    caregivers: {},
    loading: true,
  });

  const loadData = useCallback(async () => {
    await loadDataInner();
  }, [todayDate]);

  const loadDataInner = useCallback(async () => {
    const familyId = Storage.getCurrentFamilyId();
    if (!familyId) {
      setState((s) => ({ ...s, loading: false }));
      return;
    }

    setState((s) => ({ ...s, loading: true }));

    try {
      // 1. 先获取家庭信息（从 /users/me/families 的第一条）
      const familyRes = await get<{ families: Array<{ family: Family }> }>('/users/me/families');
      const familyList = familyRes?.families ?? [];
      // 用 Storage 中当前 familyId 精确查找，不用 [0]（后端排序不稳定）
      const currentFamily = familyList.find((item) => item.family?.id === familyId)?.family
        || familyList[0]?.family;
      const familyIdFromRes = currentFamily?.id || familyId;
      const familyName = currentFamily?.name || '我的家庭';
      const familyAvatarUrl = currentFamily?.avatarUrl || null;

      // 1b. 获取家庭成员数量
      let memberCount = 0;
      try {
        const members = await get<any[]>(`/families/${familyIdFromRes}/members`);
        memberCount = members?.length ?? 0;
      } catch {}

      // 2. 获取照护对象列表
      let careRecipients: CareRecipient[] = [];
      try {
        careRecipients = await get<CareRecipient[]>('/care-recipients', { familyId }) || [];
      } catch {}

      // 3. 照护对象获取成功后，并发请求今日用药汇总（每个照护对象一份）
      const medPromises = careRecipients.map((r) =>
        get<TodayMedicationSummary>(`/medication-logs/today?recipientId=${r.id}&familyId=${familyId}`)
          .catch(() => null)
      );
      const medResults = await Promise.all(medPromises);

      const medicationSummaries: TodayMedicationSummary[] = medResults.filter(Boolean) as TodayMedicationSummary[];

      // 4b. 获取未读通知数
      let unreadCount = 0;
      try {
        const notifications = await get<{ items: any[] }>('/notifications', { unread: true, limit: 1 });
        // 获取总未读数（后端支持 count 字段）
        unreadCount = (notifications as any)?.totalUnread ?? 0;
      } catch {}
      const [appointmentsData, tasksData] = await Promise.allSettled([
        // 本月复诊日历
        get<Appointment[]>(`/appointments/calendar?familyId=${familyId}&year=${new Date().getFullYear()}&month=${new Date().getMonth() + 1}`),
        // 今日家庭任务（按年月筛选）
        get<FamilyTask[]>(`/family-tasks?familyId=${familyId}&year=${new Date().getFullYear()}&month=${new Date().getMonth() + 1}`),
      ]);

      // 过滤7天内即将到来的复诊
      const now = new Date();
      const weekLater = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
      let appointments: Appointment[] = [];
      if (appointmentsData.status === 'fulfilled' && appointmentsData.value) {
        appointments = (appointmentsData.value as Appointment[]).filter((a) => {
          if (a.status !== 'upcoming') return false;
          const aptTime = new Date(a.appointmentTime);
          return aptTime > now && aptTime < weekLater;
        });
      }

      // 过滤 pending 状态任务
      let tasks: FamilyTask[] = [];
      if (tasksData.status === 'fulfilled' && tasksData.value) {
        tasks = (tasksData.value as FamilyTask[]).filter((t) => t.status === 'pending');
      }

      setState({
        familyName,
        familyAvatarUrl,
        memberCount,
        unreadCount,
        recipients: careRecipients,
        medicationSummaries,
        checkins: {},
        caregivers: {},
        appointments,
        tasks,
        loading: false,
      });

      // 并发加载每日护理打卡 + 当前照护人
      if (careRecipients.length > 0) {
        const ids = careRecipients.map((r) => r.id).join(',');

        const [checkinsData, ...cgResults] = await Promise.all([
          get<DailyCareCheckin[]>('/daily-care-checkins/today', {
            recipientIds: ids,
            todayDate,
            familyId,
          }).catch(() => [] as DailyCareCheckin[]),
          ...careRecipients.map((r) =>
            get<CaregiverRecord>(`/caregiver-records/current`, {
              careRecipientId: r.id,
              familyId,
            }).catch(() => null as CaregiverRecord | null)
          ),
        ]);

        const checkinsMap: Record<string, DailyCareCheckin> = {};
        (checkinsData || []).forEach((c: DailyCareCheckin) => {
          checkinsMap[c.careRecipientId] = c;
        });

        const caregiversMap: Record<string, CaregiverRecord> = {};
        careRecipients.forEach((r, i) => {
          if (cgResults[i]) caregiversMap[r.id] = cgResults[i] as CaregiverRecord;
        });

        setState((s) => ({ ...s, checkins: checkinsMap, caregivers: caregiversMap }));
      }
    } catch (err) {
      console.error('首页加载失败:', err);
      setState((s) => ({ ...s, loading: false }));
    }
  }, [todayDate]);

  // 初始加载
  useEffect(() => {
    loadDataInner();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // 订阅 Redux currentFamilyId 变化（切换家庭时触发）
  useEffect(() => {
    const currentFamilyIdRef = { current: selectCurrentFamilyId(store.getState()) };
    const unsubscribe = store.subscribe(() => {
      const newId = selectCurrentFamilyId(store.getState());
      if (newId !== currentFamilyIdRef.current) {
        currentFamilyIdRef.current = newId;
        loadDataInner();
      }
    });
    return unsubscribe;
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const onRefresh = useCallback(async () => {
    setIsRefreshing(true);
    await loadDataInner();
    setIsRefreshing(false);
  }, []);

  // ─── 打卡操作 ──────────────────────────────────────────────────────────────

  // Flutter 风格：点击药品卡片 → 跳转到打卡弹窗页（与 MedicationCheckInSheet 对齐）
  const showCheckInSheet = (item: MedicationLogItem, recipientId: string) => {
    Taro.navigateTo({
      url: `/pages/medication/index?logId=${item.id}&medicationId=${item.medicationId}&medicationName=${encodeURIComponent(item.medicationName)}&dosage=${encodeURIComponent(item.dosage)}&scheduledTime=${encodeURIComponent(item.scheduledTime)}&recipientId=${recipientId}&status=${item.status}`,
    });
  };

  // ─── 任务完成 ──────────────────────────────────────────────────────────────

  const handleCompleteTask = async (task: FamilyTask) => {
    const familyId = Storage.getCurrentFamilyId();
    const dueDate = task.nextDueAt ? new Date(task.nextDueAt) : null;
    const scheduledDate = dueDate
      ? `${dueDate.getFullYear()}-${String(dueDate.getMonth() + 1).padStart(2, '0')}-${String(dueDate.getDate()).padStart(2, '0')}`
      : null;
    try {
      await post(`/family-tasks/${task.id}/complete`, scheduledDate ? { scheduledDate } : {});
      Taro.showToast({ title: '任务已完成', icon: 'success', duration: 1500 });
      loadData();
    } catch (e: any) {
      Taro.showToast({ title: e?.message || '操作失败', icon: 'none', duration: 2000 });
    }
  };

  // ─── 渲染 ──────────────────────────────────────────────────────────────────

  const { familyName, familyAvatarUrl, memberCount, unreadCount, recipients, medicationSummaries, checkins, caregivers, appointments, tasks, loading } = state;
  const hasRecipients = recipients.length > 0;

  return (
    <View className="home-page">
      {/* ── 1. 玻璃态顶栏 ─────────────────────────────────────────────── */}
      <View className="glass-bar">
        <View className="glass-bar-inner">
          {/* 家庭头像 */}
          <View className="family-avatar">
            {familyAvatarUrl ? (
              <Image className="family-avatar-img" src={getImageUrl(familyAvatarUrl)} mode="aspectFill" />
            ) : (
              <Text className="family-avatar-emoji">👨‍👩‍👧</Text>
            )}
          </View>

          {/* 家庭信息 */}
          <View className="family-info">
            <Text className="family-name">{familyName}</Text>
            <View className="member-row">
              <Image className="member-icon" src={require('../../assets/icons/people.png')} />
              <Text className="member-count">{memberCount}位成员</Text>
            </View>
          </View>

          {/* 通知铃铛 */}
          <View className="bell-btn" onClick={() => Taro.navigateTo({ url: '/pages/notification/index' })}>
            <Image className="bell-icon" src={require('../../assets/icons/bell.png')} />
            {unreadCount > 0 && (
              <View className="bell-badge">
                <Text className="bell-badge-text">{unreadCount > 99 ? '99+' : unreadCount}</Text>
              </View>
            )}
          </View>
        </View>
      </View>

      {/* ── 2. 可滚动内容区 ──────────────────────────────────────────── */}
      <ScrollView
        className="home-scroll"
        scrollY
        refresherEnabled
        refresherTriggered={isRefreshing}
        onRefresherRefresh={onRefresh}
      >

        {/* 加载中 */}
        {loading && (
          <View className="loading-state">
            <Text className="loading-text">加载中...</Text>
          </View>
        )}

        {!loading && (
          <>
            {/* ── 无照护对象空状态 ────────────────────────────────────── */}
            {!hasRecipients && (
              <View className="empty-state-card">
                <Image className="empty-emoji-img" src={require('../../assets/icons/info.png')} mode="aspectFit" />
                <Text className="empty-title">还没有添加照护对象</Text>
                <Text className="empty-subtitle">点击下方添加照护对象，开始记录用药和护理</Text>
                <View
                  className="empty-add-btn"
                  onClick={() => Taro.navigateTo({ url: '/pages/care-recipient/add' })}
                >
                  <Text className="empty-add-btn-text">添加照护对象</Text>
                </View>
              </View>
            )}

            {/* ── 有照护对象：每个照护对象一个 section ─────────────── */}
            {hasRecipients && medicationSummaries.map((summary) => {
              const recipient = recipients.find((r) => r.id === summary.recipientId) || {
                id: summary.recipientId,
                name: summary.recipientName || '照护对象',
                avatarEmoji: summary.recipientAvatar,
                avatarUrl: null,
              } as CareRecipient;
              const checkin = checkins[summary.recipientId];
              const checkinInfo = getCheckinStatusInfo(checkin);
              const caregiver = caregivers[summary.recipientId];
              const progress = summary.total > 0 ? summary.completed / summary.total : 0;
              const progressColor = progress >= 1 ? COLOR_SUCCESS : COLOR_PRIMARY;

              return (
                <View key={summary.recipientId} className="recipient-section">
                  {/* 照护对象头部卡片：左侧信息（点击进详情） + 右侧打卡入口 */}
                  <View className="recipient-header-card">
                    <View
                      className="recipient-left"
                      onClick={() => Taro.navigateTo({ url: `/pages/care-recipient/detail?id=${summary.recipientId}` })}
                    >
                      {/* 头像 */}
                      <View className="recipient-avatar">
                        {recipient.avatarUrl ? (
                          <Image
                            className="recipient-avatar-img"
                            src={getImageUrl(recipient.avatarUrl)}
                            mode="aspectFill"
                          />
                        ) : (
                          <Text className="recipient-avatar-text">
                            {recipient.avatarEmoji || '👤'}
                          </Text>
                        )}
                      </View>

                      {/* 姓名 + 年龄 + 进度条 */}
                      <View className="recipient-info">
                        <View className="recipient-name-row">
                          <Text className="recipient-name">{recipient.name}</Text>
                          {recipient.age && (
                            <View className="age-badge">
                              <Text className="age-text">{recipient.age}岁</Text>
                            </View>
                          )}
                        </View>
                        <View className="recipient-progress-row">
                          <View className="progress-bar-mini">
                            <View
                              className="progress-fill-mini"
                              style={{ width: `${Math.round(progress * 100)}%`, backgroundColor: progressColor }}
                            />
                          </View>
                          <Text className="progress-text-mini" style={{ color: progressColor }}>
                            {summary.total > 0 ? `${summary.completed}/${summary.total}` : '无药品'}
                          </Text>
                        </View>
                        {/* 照护人信息 */}
                        {caregiver && (
                          <View className="recipient-caregiver-row">
                            <Text className="recipient-caregiver-label">当前照护人：</Text>
                            <Text className="recipient-caregiver-name">{caregiver.caregiverNickname || '家庭成员'}</Text>
                          </View>
                        )}
                      </View>
                    </View>

                    {/* 右侧：每日护理打卡入口（阻止冒泡到父级） */}
                    <View
                      className="checkin-entry"
                      onClick={(e) => {
                        e.stopPropagation?.();
                        Taro.navigateTo({
                          url: `/pages/daily-care/index?recipientId=${summary.recipientId}&recipientName=${encodeURIComponent(summary.recipientName || '')}`,
                        });
                      }}
                    >
                      <Text className="checkin-status-icon" style={{ color: checkinInfo.color }}>
                        {checkin ? (checkin.status === 'normal' ? '✓' : checkin.status === 'concerning' ? 'ℹ' : checkin.status === 'poor' ? '⚠' : '✕') : '⏱'}
                      </Text>
                      <Text className="checkin-status-label" style={{ color: checkinInfo.color }}>
                        {checkinInfo.label}
                      </Text>
                      <View className="checkin-btn" style={{
                        backgroundColor: checkin
                          ? `${checkinInfo.color}26` // 15% opacity
                          : `${COLOR_PRIMARY}1A`,
                      }}>
                        <Text className="checkin-btn-text" style={{ color: checkin ? checkinInfo.color : COLOR_PRIMARY }}>
                          {checkin ? '已打卡' : '去打卡'}
                        </Text>
                      </View>
                    </View>
                  </View>

                  {/* 药品打卡网格 2列 */}
                  <View className="med-grid">
                    {(summary.items || []).map((item) => {
                      const { color, borderColor, bgColor } = getMedStatus(item);
                      const isDone = item.status === 'taken' || item.status === 'skipped';
                      return (
                        <View
                          key={item.id}
                          className="med-card"
                          style={{ borderLeftColor: borderColor, backgroundColor: bgColor }}
                          onClick={() => showCheckInSheet(item, summary.recipientId)}
                        >
                          <View className="med-card-top">
                            <Text className="med-name" style={{ textDecorationLine: item.status === 'skipped' ? 'line-through' : 'none' }}>
                              {item.medicationName}
                            </Text>
                            <Text className="med-check-icon" style={{ color }}>
                              {isDone ? '✓' : '⏱'}
                            </Text>
                          </View>
                          <Text className="med-dosage">{item.dosage}</Text>
                          <Text className="med-time" style={{ color }}>{item.scheduledTime}</Text>

                          {/* 底部：打卡按钮 / 已完成信息 */}
                          {isDone && item.takenBy ? (
                            <View className="med-done-info">
                              <View className="med-done-row">
                                <Text className="med-done-time" style={{ color }}>
                                  {item.actualTime ? item.actualTime.slice(11, 16) : ''}
                                </Text>
                                <Text className="med-done-label">
                                  {item.status === 'taken' ? '已服用' : '已跳过'}
                                </Text>
                              </View>
                              <Text className="med-done-by">由 {item.takenBy?.name} 记录</Text>
                            </View>
                          ) : item.canCheckIn ? (
                            <View className="med-action-btn">
                              <Text className="med-action-text">打卡</Text>
                            </View>
                          ) : null}
                        </View>
                      );
                    })}

                    {/* 空状态：无药品 */}
                    {(!summary.items || summary.items.length === 0) && (
                      <View className="med-empty">
                        <Text className="med-empty-text">今日暂无用药计划</Text>
                      </View>
                    )}
                  </View>
                </View>
              );
            })}

            {/* ── 复诊提醒 ──────────────────────────────────────────── */}
            {appointments.length > 0 && (
              <View className="section">
                <View className="section-header">
                  <View className="section-icon-wrap" style={{ backgroundColor: `${COLOR_CORAL}1A` }}>
                    <Image className="section-icon-img" src={require('../../assets/icons/info.png')} mode="aspectFit" />
                  </View>
                  <Text className="section-title">复诊提醒</Text>
                  <View className="section-spacer" />
                  <View
                    className="see-all-btn"
                    onClick={() => Taro.navigateTo({ url: '/pages/calendar/index?tab=appointments' })}
                  >
                    <Text className="see-all-text" style={{ color: COLOR_CORAL }}>查看全部</Text>
                    <Text className="see-all-arrow" style={{ color: COLOR_CORAL }}>›</Text>
                  </View>
                </View>

                {appointments.slice(0, 2).map((apt) => (
                  <View key={apt.id} className="apt-card" onClick={() => Taro.navigateTo({ url: `/pages/calendar/index?tab=appointments` })}>
                    <View className="apt-left-bar" style={{ backgroundColor: COLOR_CORAL }} />
                    <View className="apt-content">
                      <View className="apt-top-row">
                        {apt.recipient && (
                          <>
                            <Text className="apt-emoji">{apt.recipient.avatarEmoji || '👤'}</Text>
                            <Text className="apt-recipient-name">{apt.recipient.name}</Text>
                          </>
                        )}
                      </View>
                      <View className="apt-info-row">
                        <Text className="apt-hospital">{apt.hospital}</Text>
                        {apt.department && <Text className="apt-dept">{apt.department}</Text>}
                      </View>
                    </View>
                    <View className="apt-right">
                      <Text className="apt-date" style={{ color: COLOR_CORAL }}>{formatDateStr(apt.appointmentTime)}</Text>
                      <View className="apt-time-badge">
                        <Text className="apt-time" style={{ color: COLOR_CORAL }}>{formatTime(apt.appointmentTime)}</Text>
                      </View>
                      {apt.doctorPhone && (
                        <View
                          className="apt-phone-btn"
                          onClick={(e) => {
                            e.stopPropagation?.();
                            Taro.makePhoneCall({ phoneNumber: apt.doctorPhone! });
                          }}
                        >
                          <Image className="apt-phone-icon-img" src={require('../../assets/icons/phone.png')} mode="aspectFit" />
                        </View>
                      )}
                    </View>
                  </View>
                ))}
              </View>
            )}

            {/* ── 今日任务 ──────────────────────────────────────────── */}
            {tasks.length > 0 && (
              <View className="section">
                <View className="section-header">
                  <View className="section-icon-wrap" style={{ backgroundColor: `${COLOR_BLUE}1A` }}>
                    <Image className="section-icon-img" src={require('../../assets/icons/doc.png')} mode="aspectFit" />
                  </View>
                  <Text className="section-title">今日任务</Text>
                  <View className="section-spacer" />
                  <View
                    className="see-all-btn"
                    onClick={() => Taro.navigateTo({ url: '/pages/calendar/index?tab=tasks' })}
                  >
                    <Text className="see-all-text" style={{ color: COLOR_BLUE }}>查看全部</Text>
                    <Text className="see-all-arrow" style={{ color: COLOR_BLUE }}>›</Text>
                  </View>
                </View>

                {tasks.slice(0, 2).map((task) => (
                  <View key={task.id} className="task-card">
                    <View className="task-left-bar" style={{ backgroundColor: COLOR_BLUE }} />
                    <View className="task-content">
                      <View className="task-top-row">
                        {task.recipient && (
                          <>
                            <Text className="task-emoji">{task.recipient.avatarEmoji || '👤'}</Text>
                          </>
                        )}
                        <Text className="task-title">{task.title}</Text>
                      </View>
                      {task.description && (
                        <Text className="task-desc" numberOfLines={1}>{task.description}</Text>
                      )}
                      <View className="task-meta-row">
                        <View className="task-freq-badge">
                          <Text className="task-freq-text">{task.frequencyLabel}</Text>
                        </View>
                        {task.scheduledTime && (
                          <Text className="task-time">{task.scheduledTime}</Text>
                        )}
                        {task.assignee && (
                          <>
                            <Text className="task-assignee-icon">👤</Text>
                            <Text className="task-assignee-name">{task.assignee.name}</Text>
                          </>
                        )}
                      </View>
                    </View>
                    {/* 完成按钮 */}
                    <View
                      className="task-complete-btn"
                      onClick={() => handleCompleteTask(task)}
                    >
                      <Text className="task-complete-icon">✓</Text>
                    </View>
                  </View>
                ))}
              </View>
            )}

            {/* 底部留白（给 SOS 按钮和 tabBar） */}
            <View className="bottom-pad" />
          </>
        )}
      </ScrollView>

      {/* ── 3. SOS 按钮（Flutter 设计：放在内容流中）───────────────────── */}
      <View
        className="sos-btn-wrap"
        onClick={() => {
          Taro.vibrateShort && Taro.vibrateShort({ type: 'light' });
          Taro.navigateTo({ url: '/pages/sos/index' });
        }}
      >
        <View className="sos-inner">
          <Image
            className="sos-icon-img"
            src={require('../../assets/icons/sos.png')}
            mode="aspectFit"
          />
          <Text className="sos-label">紧急求助</Text>
        </View>
      </View>
    </View>
  );
}
