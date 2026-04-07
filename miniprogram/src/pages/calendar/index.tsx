/**
 * 日历页
 * 手写月历网格 + 当天事件列表 / 列表视图
 * 对应 Flutter calendar_page.dart
 */

import { useState, useEffect, useCallback } from 'react';
import { View, Text, ScrollView } from '@tarojs/components';
import Taro, { useDidShow } from '@tarojs/taro';
import { get, post } from '../../services/api';
import { Storage } from '../../services/storage';
import type { Appointment } from '../../shared/models/appointment';
import type { FamilyTask } from '../../shared/models/family-task';
import './index.scss';

/* ============================
   数据类型
   ============================ */

/** 日历事件（复诊 | 任务） */
interface CalendarEvent {
  type: 'appointment' | 'task';
  id: string;
  title: string;
  // 复诊
  appointment?: Appointment;
  // 任务
  task?: FamilyTask;
}

/** 月历 API 返回：{ "2026-04-07": [...events] } */
type MonthEvents = Record<string, CalendarEvent[]>;

/** 当天分组 */
interface DayGroup {
  dateStr: string; // "4月7日 · 周一"
  dateISO: string; // "2026-04-07"
  events: CalendarEvent[];
}

/* ============================
   工具函数
   ============================ */

const WEEKDAY_LABELS = ['一', '二', '三', '四', '五', '六', '日'];

/** 获取某月第一天是星期几（0=周一 … 6=周日） */
function getFirstWeekdayOfMonth(year: number, month: number): number {
  const d = new Date(year, month - 1, 1);
  return (d.getDay() + 6) % 7; // 转成周一=0
}

/** 获取某月总天数 */
function getDaysInMonth(year: number, month: number): number {
  return new Date(year, month, 0).getDate();
}

/** 格式化日期为 YYYY-MM-DD */
function formatDateISO(year: number, month: number, day: number): string {
  return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

/** 解析 ISO 日期字符串为 Date */
function parseDate(iso: string): Date {
  return new Date(iso.replace(/-/g, '/'));
}

/** 派生复诊显示时间 */
function getAppointmentDisplay(appt: Appointment): { date: string; time: string } {
  if (!appt.appointmentTime) return { date: '', time: '' };
  const d = parseDate(appt.appointmentTime);
  d.setHours(d.getHours() + 8); // UTC+8
  const date = `${d.getMonth() + 1}月${d.getDate()}日`;
  const time = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
  return { date, time };
}

/* ============================
   主组件
   ============================ */

export default function CalendarPage() {
  const today = new Date();
  const [year, setYear] = useState(today.getFullYear());
  const [month, setMonth] = useState(today.getMonth() + 1);
  const [selectedDay, setSelectedDay] = useState(today.getDate());
  const [showList, setShowList] = useState(false);
  const [loading, setLoading] = useState(false);
  const [monthEvents, setMonthEvents] = useState<MonthEvents>({});
  const [showAddSheet, setShowAddSheet] = useState(false);
  const [completingTaskId, setCompletingTaskId] = useState<string | null>(null);
  /** 本地乐观更新：已完成但尚未等后端确认的任务 ID */
  const [pendingCompleteIds, setPendingCompleteIds] = useState<Set<string>>(new Set());
  /** 当前用户角色（用于权限控制） */
  const [myRole, setMyRole] = useState<string>('');

  const familyId = Storage.getCurrentFamilyId();

  /* 加载当月事件 */
  const loadMonthEvents = useCallback(async () => {
    if (!familyId) return;
    setLoading(true);
    try {
      // 并发请求复诊日历、任务日历、成员角色
      const [aptRes, taskRes, membersRes] = await Promise.allSettled([
        get<any[]>(`/appointments/calendar?familyId=${familyId}&year=${year}&month=${month}`),
        get<any[]>(`/family-tasks/calendar?familyId=${familyId}&year=${year}&month=${month}`),
        get<any[]>('/users/me/families'),
      ]);

      // 获取当前用户在当前家庭中的角色
      if (membersRes.status === 'fulfilled' && membersRes.value) {
        const families: any[] = (membersRes.value as any).families ?? membersRes.value;
        const currentFamilyData = families.find((f: any) => f.family?.id === familyId || f.id === familyId);
        setMyRole(currentFamilyData?.role ?? '');
      }

      const events: MonthEvents = {};
      // 处理复诊事件
      if (aptRes.status === 'fulfilled' && aptRes.value) {
        for (const apt of aptRes.value) {
          const d = new Date(apt.appointmentTime);
          const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
          if (!events[key]) events[key] = [];
          events[key].push({ type: 'appointment' as const, data: apt });
        }
      }
      // 处理任务事件
      if (taskRes.status === 'fulfilled' && taskRes.value) {
        for (const task of taskRes.value) {
          const d = new Date(task.scheduledDate || task.dueDate);
          const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
          if (!events[key]) events[key] = [];
          events[key].push({ type: 'task' as const, data: task });
        }
      }
      setMonthEvents(events);
    } catch (err) {
      console.error('加载月历事件失败:', err);
    } finally {
      setLoading(false);
    }
  }, [familyId, year, month]);

  useEffect(() => {
    loadMonthEvents();
  }, [loadMonthEvents]);

  useDidShow(() => {
    loadMonthEvents();
  });

  /* 月份切换 */
  const goPrevMonth = () => {
    if (month === 1) {
      setYear(year - 1);
      setMonth(12);
    } else {
      setMonth(month - 1);
    }
    setSelectedDay(1);
  };

  const goNextMonth = () => {
    if (month === 12) {
      setYear(year + 1);
      setMonth(1);
    } else {
      setMonth(month + 1);
    }
    setSelectedDay(1);
  };

  /* 构建月历格子（42格 = 6行） */
  const buildCalendarCells = (): Array<{
    year: number;
    month: number;
    day: number | null;
    isCurrentMonth: boolean;
    dateISO: string;
  }> => {
    const cells: Array<{
      year: number;
      month: number;
      day: number | null;
      isCurrentMonth: boolean;
      dateISO: string;
    }> = [];

    const firstWeekday = getFirstWeekdayOfMonth(year, month); // 0=周一
    const daysInMonth = getDaysInMonth(year, month);

    // 上月补齐
    const prevMonth = month === 1 ? 12 : month - 1;
    const prevYear = month === 1 ? year - 1 : year;
    const daysInPrevMonth = getDaysInMonth(prevYear, prevMonth);
    for (let i = firstWeekday - 1; i >= 0; i--) {
      const d = daysInPrevMonth - i;
      cells.push({ year: prevYear, month: prevMonth, day: d, isCurrentMonth: false, dateISO: formatDateISO(prevYear, prevMonth, d) });
    }

    // 本月
    for (let d = 1; d <= daysInMonth; d++) {
      cells.push({ year, month, day: d, isCurrentMonth: true, dateISO: formatDateISO(year, month, d) });
    }

    // 下月补齐（凑满42格）
    const remaining = 42 - cells.length;
    const nextMonth = month === 12 ? 1 : month + 1;
    const nextYear = month === 12 ? year + 1 : year;
    for (let d = 1; d <= remaining; d++) {
      cells.push({ year: nextYear, month: nextMonth, day: d, isCurrentMonth: false, dateISO: formatDateISO(nextYear, nextMonth, d) });
    }

    return cells;
  };

  const cells = buildCalendarCells();

  /* 判断是否是今天 */
  const isToday = (c: (typeof cells)[0]) =>
    c.isCurrentMonth && c.day === today.getDate() && c.month === today.getMonth() + 1 && c.year === today.getFullYear();

  /* 判断是否选中 */
  const isSelected = (c: (typeof cells)[0]) =>
    c.isCurrentMonth && c.day === selectedDay;

  /* 获取某天的所有事件（排除乐观更新中已完成的） */
  const getDayEvents = (dateISO: string): CalendarEvent[] => {
    return (monthEvents[dateISO] || []).filter(
      (e) => !(e.type === 'task' && pendingCompleteIds.has(e.id))
    );
  };

  /* 选中某天 */
  const selectDay = (c: (typeof cells)[0]) => {
    if (!c.isCurrentMonth) return;
    setSelectedDay(c.day!);
  };

  /* 当天视图的事件 */
  const selectedDateISO = formatDateISO(year, month, selectedDay);
  const selectedDayEvents = getDayEvents(selectedDateISO);

  /* 列表视图：收集所有未来事件 */
  const listGroups: DayGroup[] = (() => {
    const now = new Date();
    now.setHours(0, 0, 0, 0);
    const all: Array<{ iso: string; event: CalendarEvent }> = [];

    for (const [iso, events] of Object.entries(monthEvents)) {
      const d = parseDate(iso);
      d.setHours(0, 0, 0, 0);
      if (d >= now) {
        for (const ev of events) {
          // 乐观更新中已完成的跳过
          if (ev.type === 'task' && pendingCompleteIds.has(ev.id)) continue;
          all.push({ iso, event: ev });
        }
      }
    }

    // 按时间排序
    all.sort((a, b) => {
      const ta = a.event.type === 'appointment'
        ? a.event.appointment?.appointmentTime
        : a.event.task?.nextDueAt;
      const tb = b.event.type === 'appointment'
        ? b.event.appointment?.appointmentTime
        : b.event.task?.nextDueAt;
      if (!ta && !tb) return 0;
      if (!ta) return 1;
      if (!tb) return -1;
      return ta.localeCompare(tb);
    });

    // 按日期分组
    const groups: DayGroup[] = [];
    for (const item of all) {
      const d = parseDate(item.iso);
      const last = groups[groups.length - 1];
      if (last && last.dateISO === item.iso) {
        last.events.push(item.event);
      } else {
        const weekdayIdx = (d.getDay() + 6) % 7;
        groups.push({
          dateStr: `${d.getMonth() + 1}月${d.getDate()}日 · ${WEEKDAY_LABELS[weekdayIdx]}`,
          dateISO: item.iso,
          events: [item.event],
        });
      }
    }
    return groups;
  })();

  /* 完成任务的乐观更新 */
  const completeTask = async (task: FamilyTask) => {
    if (!familyId || completingTaskId === task.id) return;
    setCompletingTaskId(task.id);
    // 乐观更新：立即从 UI 移除
    setPendingCompleteIds((prev) => new Set([...prev, task.id]));
    try {
      const dueDate = task.nextDueAt;
      const scheduledDate = dueDate ? dueDate.slice(0, 10) : null;
      await post(`/family-tasks/${task.id}/complete`, scheduledDate ? { scheduledDate } : {}, {
        params: { familyId },
      });
      Taro.showToast({ title: '已完成', icon: 'success', duration: 1500 });
      // 后端确认后重新加载当月事件
      await loadMonthEvents();
    } catch (err) {
      console.error('完成任务失败:', err);
      Taro.showToast({ title: '操作失败', icon: 'none', duration: 1500 });
      // 失败回滚：从 pending 移除，任务会重新出现
      setPendingCompleteIds((prev) => {
        const next = new Set(prev);
        next.delete(task.id);
        return next;
      });
    } finally {
      setCompletingTaskId(null);
    }
  };

  /* 无家庭提示 */
  if (!familyId) {
    return (
      <View className="calendar-page">
        <View className="empty-state">
          <Text className="empty-emoji">🏠</Text>
          <Text className="empty-title">请先加入一个家庭</Text>
          <Text className="empty-sub">在"我的"页面加入或创建家庭后使用日历功能</Text>
        </View>
      </View>
    );
  }

  return (
    <View className="calendar-page">
      {/* 右侧添加按钮（仅 owner/coordinator 可用） */}
      {(myRole === 'owner' || myRole === 'coordinator') && (
        <View className="fixed-add-btn" onClick={() => setShowAddSheet(true)}>
          <Text className="fixed-add-icon">+</Text>
        </View>
      )}

      {/* 月切换头 */}
      <View className="month-header">
        <View className="month-arrow" onClick={goPrevMonth}>
          <Text className="arrow-text">◀</Text>
        </View>
        <Text className="month-label">{year}年{month}月</Text>
        <View className="month-arrow" onClick={goNextMonth}>
          <Text className="arrow-text">▶</Text>
        </View>
      </View>

      {/* 星期头 */}
      <View className="weekday-row">
        {WEEKDAY_LABELS.map((label) => (
          <View key={label} className="weekday-cell">
            <Text className="weekday-text">{label}</Text>
          </View>
        ))}
      </View>

      {/* 日历网格 */}
      <View className="calendar-grid">
        {cells.map((c, idx) => {
          const events = c.day !== null ? getDayEvents(c.dateISO) : [];
          const hasAppt = events.some((e) => e.type === 'appointment');
          const hasTask = events.some((e) => e.type === 'task');
          const todayCls = isToday(c) ? 'cell-today' : '';
          const selCls = isSelected(c) ? 'cell-selected' : '';
          const disabledCls = !c.isCurrentMonth ? 'cell-other-month' : '';

          return (
            <View
              key={idx}
              className={`calendar-cell ${todayCls} ${selCls} ${disabledCls}`}
              onClick={() => selectDay(c)}
            >
              {c.day !== null && (
                <>
                  <Text className={`cell-day ${isSelected(c) ? 'cell-day-selected' : ''} ${isToday(c) ? 'cell-day-today' : ''}`}>
                    {c.day}
                  </Text>
                  <View className="cell-dots">
                    {hasAppt && <View className="dot dot-appointment" />}
                    {hasTask && <View className="dot dot-task" />}
                  </View>
                </>
              )}
            </View>
          );
        })}
      </View>

      {/* 分隔线 */}
      <View className="divider" />

      {/* 事件区域标签行 */}
      <View className="events-header">
        <Text className="events-title">本月日程</Text>
        <View className="events-legend">
          <View className="legend-item">
            <View className="legend-dot legend-appt" />
            <Text className="legend-text">复诊</Text>
          </View>
          <View className="legend-item">
            <View className="legend-dot legend-task" />
            <Text className="legend-text">任务</Text>
          </View>
        </View>
        <View className="view-toggle">
          <View
            className={`toggle-btn ${showList ? 'toggle-active' : ''}`}
            onClick={() => setShowList(true)}
          >
            <Text className={`toggle-text ${showList ? 'toggle-text-active' : ''}`}>列表</Text>
          </View>
          <View
            className={`toggle-btn ${!showList ? 'toggle-active' : ''}`}
            onClick={() => setShowList(false)}
          >
            <Text className={`toggle-text ${!showList ? 'toggle-text-active' : ''}`}>当天</Text>
          </View>
        </View>
      </View>

      {/* 加载状态 */}
      {loading && (
        <View className="loading-row">
          <Text className="loading-text">加载中...</Text>
        </View>
      )}

      {/* 当天视图 */}
      {!showList && (
        <ScrollView className="events-scroll" scrollY>
          {selectedDayEvents.length === 0 && !loading ? (
            <View className="empty-state">
              <Text className="empty-emoji">📅</Text>
              <Text className="empty-title">当天暂无安排</Text>
              <Text className="empty-sub">点击右上角"+"添加</Text>
            </View>
          ) : (
            <View className="day-events">
              {selectedDayEvents.some((e) => e.type === 'appointment') && (
                <>
                  <View className="section-tag">
                    <View className="section-bar section-bar-appt" />
                    <Text className="section-label section-label-appt">复诊</Text>
                  </View>
                  <View className="cards-list">
                    {selectedDayEvents
                      .filter((e) => e.type === 'appointment')
                      .map((e) => (
                        <AppointmentCard
                          key={e.id}
                          appointment={e.appointment!}
                          onCall={() => {
                            if (e.appointment?.doctorPhone) {
                              Taro.makePhoneCall({ phoneNumber: e.appointment!.doctorPhone });
                            }
                          }}
                          onNav={() => {
                            if (e.appointment?.address) {
                              Taro.openLocation({
                                address: e.appointment!.address,
                                latitude: e.appointment!.latitude || 0,
                                longitude: e.appointment!.longitude || 0,
                                name: e.appointment!.hospital,
                              });
                            }
                          }}
                        />
                      ))}
                  </View>
                </>
              )}

              {selectedDayEvents.some((e) => e.type === 'task') && (
                <>
                  <View className="section-tag">
                    <View className="section-bar section-bar-task" />
                    <Text className="section-label section-label-task">任务</Text>
                  </View>
                  <View className="cards-list">
                    {selectedDayEvents
                      .filter((e) => e.type === 'task')
                      .map((e) => (
                        <TaskCard
                          key={e.id}
                          task={e.task!}
                          familyId={familyId}
                          isCompleting={completingTaskId === e.task!.id}
                          onComplete={() => completeTask(e.task!)}
                        />
                      ))}
                  </View>
                </>
              )}
            </View>
          )}
          <View className="bottom-pad" />
        </ScrollView>
      )}

      {/* 列表视图 */}
      {showList && (
        <ScrollView className="events-scroll" scrollY>
          {listGroups.length === 0 && !loading ? (
            <View className="empty-state">
              <Text className="empty-emoji">📅</Text>
              <Text className="empty-title">本月暂无日程安排</Text>
              <Text className="empty-sub">点击右上角"+"添加复诊或任务</Text>
            </View>
          ) : (
            <View className="list-view">
              {listGroups.map((group) => (
                <View key={group.dateISO} className="list-group">
                  <Text className="group-date">{group.dateStr}</Text>
                  <View className="cards-list">
                    {group.events.map((ev) =>
                      ev.type === 'appointment' ? (
                        <AppointmentCard
                          key={ev.id}
                          appointment={ev.appointment!}
                          onCall={() => {
                            if (ev.appointment?.doctorPhone) {
                              Taro.makePhoneCall({ phoneNumber: ev.appointment!.doctorPhone });
                            }
                          }}
                          onNav={() => {
                            if (ev.appointment?.address) {
                              Taro.openLocation({
                                address: ev.appointment!.address,
                                latitude: ev.appointment!.latitude || 0,
                                longitude: ev.appointment!.longitude || 0,
                                name: ev.appointment!.hospital,
                              });
                            }
                          }}
                        />
                      ) : (
                        <TaskCard
                          key={ev.id}
                          task={ev.task!}
                          familyId={familyId}
                          isCompleting={completingTaskId === ev.task!.id}
                          onComplete={() => completeTask(ev.task!)}
                        />
                      )
                    )}
                  </View>
                </View>
              ))}
            </View>
          )}
          <View className="bottom-pad" />
        </ScrollView>
      )}

      {/* 添加弹层 */}
      {showAddSheet && (
        <View className="sheet-mask" onClick={() => setShowAddSheet(false)}>
          <View
            className="sheet-container"
            onClick={(e) => e.stopPropagation()}
          >
            <View className="sheet-handle" />
            <View className="sheet-title-row">
              <View
                className="add-option add-option-appt"
                onClick={() => {
                  setShowAddSheet(false);
                  Taro.navigateTo({ url: '/pages/appointment/add' });
                }}
              >
                <Text className="option-emoji">🏥</Text>
                <Text className="option-label option-label-appt">添加复诊</Text>
              </View>
              <View
                className="add-option add-option-task"
                onClick={() => {
                  setShowAddSheet(false);
                  Taro.navigateTo({ url: '/pages/family-task/add' });
                }}
              >
                <Text className="option-emoji">📝</Text>
                <Text className="option-label option-label-task">添加任务</Text>
              </View>
            </View>
          </View>
        </View>
      )}
    </View>
  );
}

/* ============================
   复诊卡片
   ============================ */

interface AppointmentCardProps {
  appointment: Appointment;
  onCall?: () => void;
  onNav?: () => void;
}

function AppointmentCard({ appointment, onCall, onNav }: AppointmentCardProps) {
  const { date, time } = getAppointmentDisplay(appointment);
  const wdIdx = (() => {
    if (!appointment.appointmentTime) return 0;
    const d = parseDate(appointment.appointmentTime);
    d.setHours(d.getHours() + 8);
    return (d.getDay() + 6) % 7;
  })();

  return (
    <View className="appt-card">
      {/* 日期时间行 */}
      <View className="appt-date-row">
        <Text className="appt-date">{date}（{WEEKDAY_LABELS[wdIdx]}）</Text>
        <View className="appt-time-badge">
          <Text className="appt-time">{time}</Text>
        </View>
      </View>

      {/* 内容 */}
      <View className="appt-body">
        <View className="appt-recipient-row">
          <Text className="recipient-emoji">{appointment.recipient?.avatarEmoji || '👤'}</Text>
          <Text className="recipient-name">{appointment.recipient?.name || ''}</Text>
          <View className="appt-type-badge">
            <Text className="appt-type-text">复诊</Text>
          </View>
        </View>

        <View className="appt-info-row">
          <Text className="appt-info-icon">🏥</Text>
          <Text className="appt-info-text">
            {appointment.hospital}
            {appointment.department ? ` · ${appointment.department}` : ''}
          </Text>
        </View>

        {appointment.doctorName && (
          <View className="appt-info-row">
            <Text className="appt-info-icon">👨‍⚕️</Text>
            <Text className="appt-info-text">{appointment.doctorName}</Text>
          </View>
        )}

        {/* 操作按钮 */}
        <View className="appt-actions">
          {appointment.doctorPhone && (
            <View className="action-btn action-btn-call" onClick={onCall}>
              <Text className="action-btn-text action-btn-text-call">📞 联系医生</Text>
            </View>
          )}
          {appointment.address && (
            <View className="action-btn action-btn-nav" onClick={onNav}>
              <Text className="action-btn-text action-btn-text-nav">📍 导航</Text>
            </View>
          )}
        </View>
      </View>
    </View>
  );
}

/* ============================
   任务卡片
   ============================ */

interface TaskCardProps {
  task: FamilyTask;
  familyId: string;
  isCompleting: boolean;
  onComplete: () => void;
}

function TaskCard({ task, isCompleting, onComplete }: TaskCardProps) {
  const isPending = task.status === 'pending';
  const isCompleted = task.status === 'completed';

  const statusColor = isPending ? '#4A90D9' : isCompleted ? '#B0ADAD' : '#E07B5D';
  const titleColor = isPending ? '#2C2C2C' : '#B0ADAD';

  return (
    <View className="task-card">
      {/* 左侧色条 */}
      <View className="task-bar" style={{ backgroundColor: statusColor }} />

      <View className="task-body">
        {/* 标题行 */}
        <View className="task-title-row">
          {task.recipient && (
            <Text className="task-recipient-emoji">{task.recipient.avatarEmoji || '👤'}</Text>
          )}
          <Text
            className="task-title"
            style={{
              color: titleColor,
              textDecoration: isCompleted ? 'line-through' : 'none',
            }}
          >
            {task.title}
          </Text>
          <View className="task-status-badge" style={{ backgroundColor: `${statusColor}1A` }}>
            <Text className="task-status-text" style={{ color: statusColor }}>
              {isCompleted ? '已完成' : (task.statusLabel || task.status)}
            </Text>
          </View>
        </View>

        {/* 描述 */}
        {task.description && task.description.length > 0 && (
          <Text className="task-desc" numberOfLines={1}>
            {task.description}
          </Text>
        )}

        {/* 标签行 */}
        <View className="task-meta-row">
          <View className="task-tag" style={{ backgroundColor: '#4A90D91A' }}>
            <Text className="task-tag-text" style={{ color: '#4A90D9' }}>
              {task.frequencyLabel || task.frequency}
            </Text>
          </View>
          {task.scheduledTime && (
            <Text className="task-time">⏰ {task.scheduledTime}</Text>
          )}
          {task.nextDueAt && (
            <Text className="task-due">
              {task.displayDueAt || task.nextDueAt.slice(5, 10)}
            </Text>
          )}
          {task.assignee && (
            <Text className="task-assignee">👤 {task.assignee.name}</Text>
          )}
        </View>
      </View>

      {/* 完成按钮 */}
      {isPending && (
        <View
          className={`task-complete-btn ${isCompleting ? 'task-complete-btn-loading' : ''}`}
          onClick={onComplete}
        >
          <Text className="task-complete-icon">✓</Text>
        </View>
      )}
    </View>
  );
}
