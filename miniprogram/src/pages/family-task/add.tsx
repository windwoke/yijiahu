/**
 * 添加任务页
 */

import { useState, useEffect } from 'react';
import { View, Text, Input, ScrollView, Picker } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { post, get } from '../../services/api';
import { Storage } from '../../services/storage';
import type { CareRecipient } from '../../shared/models/care-recipient';
import './add.scss';

const FREQ_OPTIONS = [
  { label: '单次', value: 'once' },
  { label: '每日', value: 'daily' },
  { label: '每周', value: 'weekly' },
  { label: '每月', value: 'monthly' },
];
const WEEKDAYS = ['一', '二', '三', '四', '五', '六', '日'];

export default function AddFamilyTaskPage() {
  const familyId = Storage.getCurrentFamilyId();

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [frequency, setFrequency] = useState('once');
  const [scheduledDate, setScheduledDate] = useState('');
  const [scheduledTime, setScheduledTime] = useState('09:00');
  const [scheduledDays, setScheduledDays] = useState<number[]>([]);
  const [note, setNote] = useState('');
  const [recipients, setRecipients] = useState<CareRecipient[]>([]);
  const [members, setMembers] = useState<any[]>([]);
  const [selectedRecipientId, setSelectedRecipientId] = useState('');
  const [selectedAssigneeId, setSelectedAssigneeId] = useState('');
  const [dataLoading, setDataLoading] = useState(true);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    const load = async () => {
      if (!familyId) { setDataLoading(false); return; }
      try {
        const [rRes, mRes] = await Promise.allSettled([
          get<CareRecipient[]>(`/care-recipients?familyId=${familyId}`),
          get<FamilyMember[]>(`/families/${familyId}/members`),
        ]);
        if (rRes.status === 'fulfilled') {
          const list = Array.isArray(rRes.value) ? rRes.value : [];
          setRecipients(list);
          if (list.length > 0) setSelectedRecipientId(list[0].id);
        }
        if (mRes.status === 'fulfilled') {
          const list = Array.isArray(mRes.value) ? mRes.value : [];
          setMembers(list);
          if (list.length > 0) setSelectedAssigneeId(list[0].userId);
        }
      } finally {
        setDataLoading(false);
      }
    };
    load();
  }, [familyId]);

  const toggleWeekday = (day: number) => {
    setScheduledDays((prev) =>
      prev.includes(day) ? prev.filter((d) => d !== day) : [...prev, day].sort()
    );
  };

  const toggleMonthDay = (day: number) => {
    setScheduledDays((prev) =>
      prev.includes(day) ? prev.filter((d) => d !== day) : [...prev, day].sort()
    );
  };

  const handleSubmit = async () => {
    if (!title.trim()) {
      Taro.showToast({ title: '请输入任务标题', icon: 'none' });
      return;
    }
    if (!selectedAssigneeId) {
      Taro.showToast({ title: '请选择负责人', icon: 'none' });
      return;
    }
    if (frequency !== 'once' && frequency !== 'daily' && scheduledDays.length === 0) {
      Taro.showToast({
        title: frequency === 'weekly' ? '请选择要执行的星期' : '请选择要执行的日期',
        icon: 'none',
      });
      return;
    }

    setIsLoading(true);
    try {
      const payload: Record<string, any> = {
        familyId,
        title: title.trim(),
        recipientId: selectedRecipientId || null,
        frequency,
        assigneeId: selectedAssigneeId,
        scheduledTime,
        note: note || null,
      };

      if (frequency === 'once') {
        payload.scheduledDate = scheduledDate;
      } else {
        payload.scheduledDay = scheduledDays;
      }

      await post('/family-tasks', payload);
      Taro.showToast({ title: '任务已添加', icon: 'success', duration: 1500 });
      setTimeout(() => Taro.navigateBack(), 1600);
    } catch (e: any) {
      Taro.showToast({ title: e?.message || '添加失败', icon: 'none' });
    } finally {
      setIsLoading(false);
    }
  };

  if (dataLoading) {
    return (
      <View className="task-add-page loading-state">
        <Text className="loading-text">加载中...</Text>
      </View>
    );
  }

  return (
    <View className="task-add-page">
      <ScrollView className="task-add-scroll" scrollY>
        {/* 任务信息 */}
        <View className="section">
          <Text className="section-title">任务信息</Text>

          <View className="field">
            <Text className="field-label">任务标题 *</Text>
            <Input
              className="field-input"
              placeholder="请输入任务标题"
              value={title}
              onInput={(e) => setTitle(e.detail.value)}
            />
          </View>

          <View className="field">
            <Text className="field-label">任务描述</Text>
            <Input
              className="field-input"
              placeholder="选填"
              value={description}
              onInput={(e) => setDescription(e.detail.value)}
            />
          </View>
        </View>

        {/* 关联照护对象 */}
        <View className="section">
          <Text className="section-title">关联照护对象（选填）</Text>
          {recipients.length > 0 ? (
            <View className="chip-select-row">
              <View
                className={`chip-select-item ${selectedRecipientId === '' ? 'selected' : ''}`}
                onClick={() => setSelectedRecipientId('')}
              >
                <Text className={`chip-select-text ${selectedRecipientId === '' ? 'selected' : ''}`}>不关联</Text>
              </View>
              {recipients.map((r) => (
                <View
                  key={r.id}
                  className={`chip-select-item ${selectedRecipientId === r.id ? 'selected' : ''}`}
                  onClick={() => setSelectedRecipientId(r.id)}
                >
                  <Text className={`chip-select-text ${selectedRecipientId === r.id ? 'selected' : ''}`}>
                    {r.avatarEmoji || '👤'} {r.name}
                  </Text>
                </View>
              ))}
            </View>
          ) : (
            <Text className="hint-text">暂无照护对象</Text>
          )}
        </View>

        {/* 重复频率 */}
        <View className="section">
          <Text className="section-title">重复频率</Text>
          <View className="freq-grid">
            {FREQ_OPTIONS.map((opt) => (
              <View
                key={opt.value}
                className={`freq-btn ${frequency === opt.value ? 'active' : ''}`}
                onClick={() => {
                  setFrequency(opt.value);
                  setScheduledDays([]);
                }}
              >
                <Text className={`freq-btn-text ${frequency === opt.value ? 'active' : ''}`}>{opt.label}</Text>
              </View>
            ))}
          </View>
        </View>

        {/* 单次任务日期/时间 */}
        {frequency === 'once' && (
          <>
            <View className="section">
              <Text className="section-title">到期日期</Text>
              <Picker mode="date" value={scheduledDate} onChange={(e) => setScheduledDate(e.detail.value)}>
                <View className="field-picker">
                  <Text className={scheduledDate ? 'field-picker-text' : 'field-picker-placeholder'}>
                    {scheduledDate || '选择到期日期'}
                  </Text>
                  <Text className="field-picker-arrow">›</Text>
                </View>
              </Picker>
            </View>

            <View className="section">
              <Text className="section-title">到期时间</Text>
              <Picker mode="time" value={scheduledTime} onChange={(e) => setScheduledTime(e.detail.value)}>
                <View className="field-picker">
                  <Text className="field-picker-text">{scheduledTime}</Text>
                  <Text className="field-picker-arrow">›</Text>
                </View>
              </Picker>
            </View>
          </>
        )}

        {/* 周期任务时间和日期选择 */}
        {frequency !== 'once' && (
          <>
            <View className="section">
              <Text className="section-title">执行时间</Text>
              <Picker mode="time" value={scheduledTime} onChange={(e) => setScheduledTime(e.detail.value)}>
                <View className="field-picker">
                  <Text className="field-picker-text">{scheduledTime}</Text>
                  <Text className="field-picker-arrow">›</Text>
                </View>
              </Picker>
            </View>

            {frequency === 'weekly' && (
              <View className="section">
                <Text className="section-title">选择星期</Text>
                <View className="weekday-row">
                  {WEEKDAYS.map((w, i) => {
                    const day = i + 1;
                    const selected = scheduledDays.includes(day);
                    return (
                      <View
                        key={day}
                        className={`weekday-chip ${selected ? 'selected' : ''}`}
                        onClick={() => toggleWeekday(day)}
                      >
                        <Text className={`weekday-chip-text ${selected ? 'selected' : ''}`}>{w}</Text>
                      </View>
                    );
                  })}
                </View>
              </View>
            )}

            {frequency === 'monthly' && (
              <View className="section">
                <Text className="section-title">选择日期（每月）</Text>
                <View className="month-day-grid">
                  {Array.from({ length: 31 }, (_, i) => {
                    const day = i + 1;
                    const selected = scheduledDays.includes(day);
                    return (
                      <View
                        key={day}
                        className={`month-day-chip ${selected ? 'selected' : ''}`}
                        onClick={() => toggleMonthDay(day)}
                      >
                        <Text className={`month-day-chip-text ${selected ? 'selected' : ''}`}>{day}</Text>
                      </View>
                    );
                  })}
                </View>
              </View>
            )}

            {frequency !== 'daily' && scheduledDays.length === 0 && (
              <View className="section">
                <View className="warn-box">
                  <Text className="warn-text">
                    {frequency === 'weekly' ? '请选择要执行的星期' : '请选择要执行的日期'}
                  </Text>
                </View>
              </View>
            )}
          </>
        )}

        {/* 负责人 */}
        <View className="section">
          <Text className="section-title">负责人 *</Text>
          {members.length > 0 ? (
            <View className="chip-select-row">
              {members.map((m) => (
                <View
                  key={m.id}
                  className={`chip-select-item ${selectedAssigneeId === m.userId ? 'selected' : ''}`}
                  onClick={() => setSelectedAssigneeId(m.userId)}
                >
                  <Text className={`chip-select-text ${selectedAssigneeId === m.userId ? 'selected' : ''}`}>
                    {m.avatarEmoji || m.displayAvatar || m.user?.name?.[0] || '👤'} {m.displayName || m.user?.name}
                  </Text>
                </View>
              ))}
            </View>
          ) : (
            <Text className="hint-text">家庭中暂无其他成员</Text>
          )}
        </View>

        {/* 备注 */}
        <View className="section">
          <Text className="section-title">备注</Text>
          <Input
            className="field-input"
            placeholder="选填"
            value={note}
            onInput={(e) => setNote(e.detail.value)}
          />
        </View>

        <View className="bottom-pad" />
      </ScrollView>

      {/* 底部提交按钮 */}
      <View className="task-add-submit-bar">
        <View
          className={`task-add-submit-btn ${isLoading ? 'loading' : ''}`}
          onClick={isLoading ? undefined : handleSubmit}
        >
          <Text className="task-add-submit-text">
            {isLoading ? '保存中...' : '保存'}
          </Text>
        </View>
      </View>
    </View>
  );
}
