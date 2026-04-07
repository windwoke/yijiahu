/**
 * 添加复诊页
 */

import { useState, useEffect } from 'react';
import { View, Text, Input, ScrollView, Picker } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { post, get } from '../../services/api';
import { Storage } from '../../services/storage';
import type { CareRecipient } from '../../shared/models/care-recipient';
import './add.scss';

export default function AddAppointmentPage() {
  const familyId = Storage.getCurrentFamilyId();

  const [recipients, setRecipients] = useState<CareRecipient[]>([]);
  const [members, setMembers] = useState<any[]>([]);
  const [selectedRecipientId, setSelectedRecipientId] = useState('');
  const [dataLoading, setDataLoading] = useState(true);

  const [hospital, setHospital] = useState('');
  const [department, setDepartment] = useState('');
  const [doctorName, setDoctorName] = useState('');
  const [doctorPhone, setDoctorPhone] = useState('');
  const [appointmentDate, setAppointmentDate] = useState('');
  const [appointmentTime, setAppointmentTime] = useState('09:00');
  const [appointmentNo, setAppointmentNo] = useState('');
  const [address, setAddress] = useState('');
  const [fee, setFee] = useState('');
  const [purpose, setPurpose] = useState('');
  const [selectedDriverId, setSelectedDriverId] = useState('');
  const [reminder48h, setReminder48h] = useState(true);
  const [reminder24h, setReminder24h] = useState(true);
  const [note, setNote] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  // 默认日期：明天
  useEffect(() => {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    setAppointmentDate(`${tomorrow.getFullYear()}-${String(tomorrow.getMonth() + 1).padStart(2, '0')}-${String(tomorrow.getDate()).padStart(2, '0')}`);
  }, []);

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
        }
      } finally {
        setDataLoading(false);
      }
    };
    load();
  }, [familyId]);

  const handleSubmit = async () => {
    if (!hospital.trim()) {
      Taro.showToast({ title: '请输入医院名称', icon: 'none' });
      return;
    }
    if (!appointmentDate) {
      Taro.showToast({ title: '请选择复诊日期', icon: 'none' });
      return;
    }
    if (recipients.length === 0) {
      Taro.showToast({ title: '请先添加照护对象', icon: 'none' });
      return;
    }

    setIsLoading(true);
    try {
      // 合并日期和时间
      const dateTime = `${appointmentDate} ${appointmentTime}:00`;

      const payload: Record<string, any> = {
        familyId,
        recipientId: selectedRecipientId,
        hospital: hospital.trim(),
        appointmentTime: dateTime,
        department: department || null,
        doctorName: doctorName || null,
        doctorPhone: doctorPhone || null,
        appointmentNo: appointmentNo || null,
        address: address || null,
        fee: fee ? parseFloat(fee) : null,
        purpose: purpose || null,
        assignedDriverId: selectedDriverId || null,
        reminder48h,
        reminder24h,
        note: note || null,
      };

      await post('/appointments', payload);
      Taro.showToast({ title: '复诊已添加', icon: 'success', duration: 1500 });
      setTimeout(() => Taro.navigateBack(), 1600);
    } catch (e: any) {
      Taro.showToast({ title: e?.message || '添加失败', icon: 'none' });
    } finally {
      setIsLoading(false);
    }
  };

  if (dataLoading) {
    return (
      <View className="appt-add-page loading-state">
        <Text className="loading-text">加载中...</Text>
      </View>
    );
  }

  if (recipients.length === 0) {
    return (
      <View className="appt-add-page empty-state">
        <Text className="empty-emoji">🏥</Text>
        <Text className="empty-title">请先添加照护对象</Text>
        <View className="empty-action" onClick={() => Taro.navigateTo({ url: '/pages/care-recipient/add' })}>
          <Text className="empty-action-text">去添加</Text>
        </View>
      </View>
    );
  }

  return (
    <View className="appt-add-page">
      <ScrollView className="appt-add-scroll" scrollY>
        {/* 必填信息 */}
        <View className="section">
          <Text className="section-title">必填信息</Text>

          <View className="field">
            <Text className="field-label">照护对象</Text>
            <View className="chip-select-row">
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
          </View>

          <View className="field">
            <Text className="field-label">医院名称 *</Text>
            <Input
              className="field-input"
              placeholder="请输入医院名称"
              value={hospital}
              onInput={(e) => setHospital(e.detail.value)}
            />
          </View>
        </View>

        {/* 复诊时间 */}
        <View className="section">
          <Text className="section-title">复诊时间</Text>
          <View className="date-time-row">
            <View className="date-time-picker">
              <Picker mode="date" value={appointmentDate} onChange={(e) => setAppointmentDate(e.detail.value)}>
                <View className="field-picker">
                  <Text className="field-picker-text date-picker-text">
                    {appointmentDate ? appointmentDate.replace(/^(\d{4})-(\d{2})-(\d{2})$/, '$2月$3日') : '选择日期'}
                  </Text>
                  <Text className="field-picker-arrow">›</Text>
                </View>
              </Picker>
            </View>
            <View className="date-time-sep">·</View>
            <View className="date-time-picker">
              <Picker mode="time" value={appointmentTime} onChange={(e) => setAppointmentTime(e.detail.value)}>
                <View className="field-picker">
                  <Text className="field-picker-text">{appointmentTime}</Text>
                  <Text className="field-picker-arrow">›</Text>
                </View>
              </Picker>
            </View>
          </View>
        </View>

        {/* 医生信息 */}
        <View className="section">
          <Text className="section-title">医生信息（选填）</Text>

          <View className="field">
            <Text className="field-label">科室</Text>
            <Input className="field-input" placeholder="选填" value={department} onInput={(e) => setDepartment(e.detail.value)} />
          </View>

          <View className="field">
            <Text className="field-label">医生姓名</Text>
            <Input className="field-input" placeholder="选填" value={doctorName} onInput={(e) => setDoctorName(e.detail.value)} />
          </View>

          <View className="field">
            <Text className="field-label">医生电话</Text>
            <Input className="field-input" placeholder="选填" type="phone" value={doctorPhone} onInput={(e) => setDoctorPhone(e.detail.value)} />
          </View>

          <View className="field">
            <Text className="field-label">就诊目的</Text>
            <Input className="field-input" placeholder="选填" value={purpose} onInput={(e) => setPurpose(e.detail.value)} />
          </View>
        </View>

        {/* 附加信息 */}
        <View className="section">
          <Text className="section-title">附加信息（选填）</Text>

          <View className="field">
            <Text className="field-label">挂号序号</Text>
            <Input className="field-input" placeholder="选填" value={appointmentNo} onInput={(e) => setAppointmentNo(e.detail.value)} />
          </View>

          <View className="field">
            <Text className="field-label">挂号费（元）</Text>
            <Input className="field-input" placeholder="选填" type="digit" value={fee} onInput={(e) => setFee(e.detail.value)} />
          </View>

          <View className="field">
            <Text className="field-label">医院地址</Text>
            <Input className="field-input" placeholder="选填" value={address} onInput={(e) => setAddress(e.detail.value)} />
          </View>
        </View>

        {/* 接送安排 */}
        <View className="section">
          <Text className="section-title">接送安排</Text>
          {members.length > 0 ? (
            <View className="chip-select-row">
              <View
                className={`chip-select-item ${selectedDriverId === '' ? 'selected' : ''}`}
                onClick={() => setSelectedDriverId('')}
              >
                <Text className={`chip-select-text ${selectedDriverId === '' ? 'selected' : ''}`}>不指定</Text>
              </View>
              {members.map((m) => (
                <View
                  key={m.id}
                  className={`chip-select-item ${selectedDriverId === m.userId ? 'selected' : ''}`}
                  onClick={() => setSelectedDriverId(m.userId)}
                >
                  <Text className={`chip-select-text ${selectedDriverId === m.userId ? 'selected' : ''}`}>
                    {m.avatarEmoji || m.displayAvatar || m.user?.name?.[0] || '👤'} {m.displayName || m.user?.name}
                  </Text>
                </View>
              ))}
            </View>
          ) : (
            <Text className="hint-text">家庭中暂无其他成员</Text>
          )}
        </View>

        {/* 提醒设置 */}
        <View className="section">
          <Text className="section-title">提醒设置</Text>
          <View className="reminder-row">
            <View
              className={`reminder-chip ${reminder48h ? 'active' : ''}`}
              onClick={() => setReminder48h(!reminder48h)}
            >
              <Text className={`reminder-chip-icon ${reminder48h ? 'active' : ''}`}>🔔</Text>
              <Text className={`reminder-chip-text ${reminder48h ? 'active' : ''}`}>48小时前提醒</Text>
            </View>
            <View
              className={`reminder-chip ${reminder24h ? 'active' : ''}`}
              onClick={() => setReminder24h(!reminder24h)}
            >
              <Text className={`reminder-chip-icon ${reminder24h ? 'active' : ''}`}>⏰</Text>
              <Text className={`reminder-chip-text ${reminder24h ? 'active' : ''}`}>24小时前提醒</Text>
            </View>
          </View>
        </View>

        {/* 备注 */}
        <View className="section">
          <Text className="section-title">备注</Text>
          <Input className="field-input" placeholder="选填" value={note} onInput={(e) => setNote(e.detail.value)} />
        </View>

        <View className="bottom-pad" />
      </ScrollView>

      {/* 底部提交按钮 */}
      <View className="appt-add-submit-bar">
        <View
          className={`appt-add-submit-btn ${isLoading ? 'loading' : ''}`}
          onClick={isLoading ? undefined : handleSubmit}
        >
          <Text className="appt-add-submit-text">
            {isLoading ? '保存中...' : '保存'}
          </Text>
        </View>
      </View>
    </View>
  );
}
