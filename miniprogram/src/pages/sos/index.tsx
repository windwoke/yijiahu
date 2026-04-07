/**
 * SOS 紧急求助页
 * 完整实现：长按3秒触发、GPS定位、紧急信息卡、拨打紧急电话、SOS取消
 */

import { useState, useEffect, useCallback, useRef } from 'react';
import { View, Text, ScrollView } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { get, post, del } from '../../services/api';
import { Storage } from '../../services/storage';
import './index.scss';

/* ============================
   数据类型
   ============================ */

interface CareRecipient {
  id: string;
  name: string;
  displayAvatar: string;
  avatarEmoji?: string;
  avatarUrl?: string | null;
  bloodType?: string | null;
  allergies: string[];
  chronicConditions: string[];
  medicalHistory?: string | null;
  hospital?: string | null;
  department?: string | null;
  doctorName?: string | null;
  doctorPhone?: string | null;
  emergencyPhone?: string | null;
  emergencyContact?: string | null;
  currentAddress?: string | null;
}

interface FamilyMember {
  id: string;
  name: string;
  avatar?: string | null;
  displayName?: string;
  displayAvatar?: string;
  avatarEmoji?: string;
  role: string;
  confirmedAt?: string | null;
}

interface SosAlert {
  id: string;
  recipientId?: string;
  address?: string;
  latitude?: number;
  longitude?: number;
  status: string;
}

/* ============================
   常量
   ============================ */

const COLOR_CORAL = '#E07B5D';

function maskPhone(phone: string): string {
  if (phone.length > 7) return `${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}`;
  return phone;
}

/* ============================
   紧急信息卡片
   ============================ */

function EmergencyInfoCard({ recipient, compact = false }: { recipient: CareRecipient; compact?: boolean }) {
  const hasAllergies = recipient.allergies && recipient.allergies.length > 0;
  const conditions = recipient.chronicConditions || [];

  return (
    <View className={`emergency-card ${compact ? 'compact' : ''}`}>
      {/* 头部：头像 + 姓名 + 血型 */}
      <View className="eic-header">
        <View className="eic-avatar">
          <Text className="eic-avatar-text">{recipient.avatarEmoji || recipient.displayAvatar || '👤'}</Text>
        </View>
        <Text className="eic-name">{recipient.name}</Text>
        {recipient.bloodType && (
          <View className="eic-blood-tag">
            <Text className="eic-blood-text">🩸 {recipient.bloodType}型</Text>
          </View>
        )}
      </View>

      {/* 过敏 */}
      {hasAllergies && (
        <View className="eic-row eic-row-alert">
          <Text className="eic-row-icon">⚠️</Text>
          <Text className="eic-row-text eic-alert-text">过敏：{(recipient.allergies || []).join('、')}</Text>
        </View>
      )}

      {/* 病史 */}
      {recipient.medicalHistory && (
        <View className="eic-row">
          <Text className="eic-row-icon">📋</Text>
          <Text className="eic-row-text">病史：{recipient.medicalHistory}</Text>
        </View>
      )}

      {/* 慢病 */}
      {conditions.length > 0 && (
        <View className="eic-row">
          <Text className="eic-row-icon">🩺</Text>
          <Text className="eic-row-text">慢病：{conditions.join('、')}</Text>
        </View>
      )}

      {/* 医院 */}
      {recipient.hospital && (
        <View className="eic-row">
          <Text className="eic-row-icon">🏥</Text>
          <Text className="eic-row-text">
            {recipient.hospital}{recipient.department ? ` · ${recipient.department}` : ''}
          </Text>
        </View>
      )}

      {/* 主治医生 */}
      {(recipient.doctorName || recipient.doctorPhone) && (
        <View className="eic-row">
          <Text className="eic-row-icon">👨‍⚕️</Text>
          <Text className="eic-row-text">
            主治医生：{recipient.doctorName || ''}
            {recipient.doctorPhone ? ` ${maskPhone(recipient.doctorPhone)}` : ''}
          </Text>
        </View>
      )}

      {/* 当前地址 */}
      {recipient.currentAddress && (
        <View className="eic-row">
          <Text className="eic-row-icon">📍</Text>
          <Text className="eic-row-text eic-address">{recipient.currentAddress}</Text>
        </View>
      )}
    </View>
  );
}

/* ============================
   主组件
   ============================ */

export default function SosPage() {
  const [isTriggered, setIsTriggered] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [isDataLoading, setIsDataLoading] = useState(true);
  const [isPressing, setIsPressing] = useState(false);
  const [pressProgress, setPressProgress] = useState(0);
  const [recipient, setRecipient] = useState<CareRecipient | null>(null);
  const [members, setMembers] = useState<FamilyMember[]>([]);
  const [activeAlert, setActiveAlert] = useState<SosAlert | null>(null);
  const [locationAddress, setLocationAddress] = useState('');

  const progressTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const familyId = Storage.getCurrentFamilyId();

  /* ─── 加载数据 ─── */
  const loadData = useCallback(async () => {
    if (!familyId) { setIsDataLoading(false); return; }
    try {
      const [alertRes, membersRes, recipientsRes] = await Promise.allSettled([
        get<any>('/sos-alerts/active', { familyId }),
        get<FamilyMember[]>(`/families/${familyId}/members`),
        get<CareRecipient[]>(`/care-recipients?familyId=${familyId}`),
      ]);

      if (membersRes.status === 'fulfilled') {
        setMembers(Array.isArray(membersRes.value) ? membersRes.value : []);
      }
      if (recipientsRes.status === 'fulfilled') {
        const list = Array.isArray(recipientsRes.value) ? recipientsRes.value : [];
        if (list.length > 0) setRecipient(list[0]);
      }
      if (alertRes.status === 'fulfilled' && alertRes.value) {
        setActiveAlert(alertRes.value);
        setLocationAddress(alertRes.value.address || '');
        setIsTriggered(true);
      }
    } catch (e) {
      console.error('[sos] load data error', e);
    } finally {
      setIsDataLoading(false);
    }
  }, [familyId]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  /* ─── 进度更新（递归） ─── */
  const tickProgress = useCallback(() => {
    progressTimer.current = setTimeout(() => {
      setPressProgress((prev) => {
        const next = prev + 0.033;
        if (next >= 1) {
          triggerSos();
          return 1;
        }
        tickProgress();
        return next;
      });
    }, 100);
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  /* ─── 开始按压 ─── */
  const startPress = () => {
    Taro.vibrateShort && Taro.vibrateShort({ type: 'heavy' });
    setIsPressing(true);
    setPressProgress(0);
    tickProgress();
  };

  /* ─── 结束按压（提前松开） ─── */
  const endPress = () => {
    if (progressTimer.current) {
      clearTimeout(progressTimer.current);
      progressTimer.current = null;
    }
    Taro.vibrateShort && Taro.vibrateShort({ type: 'light' });
    setIsPressing(false);
    setPressProgress(0);
  };

  /* ─── 触发 SOS ─── */
  const triggerSos = async () => {
    if (progressTimer.current) {
      clearTimeout(progressTimer.current);
      progressTimer.current = null;
    }
    setIsPressing(false);
    setIsLoading(true);
    Taro.vibrateShort && Taro.vibrateShort({ type: 'heavy' });

    // 获取 GPS 位置
    let lat: number | undefined;
    let lng: number | undefined;
    try {
      const loc = await Taro.getLocation({ type: 'gcj02', isHighAccuracy: true });
      lat = loc.latitude;
      lng = loc.longitude;
    } catch (e) {
      console.error('[sos] get location error', e);
    }

    try {
      const payload: Record<string, any> = {};
      if (recipient) payload.recipientId = recipient.id;
      if (lat !== undefined) payload.latitude = lat;
      if (lng !== undefined) payload.longitude = lng;
      if (locationAddress) payload.address = locationAddress;

      const alert = await post<SosAlert>('/sos-alerts', payload);
      setActiveAlert(alert);
      setIsTriggered(true);
      Taro.showToast({ title: 'SOS 已发出', icon: 'success', duration: 2000 });
    } catch (e: any) {
      console.error('[sos] trigger error', e);
      Taro.showToast({ title: e?.message || 'SOS 触发失败', icon: 'none', duration: 2000 });
      setIsLoading(false);
    }
  };

  /* ─── 取消 SOS ─── */
  const cancelSos = async () => {
    if (!activeAlert) return;
    const res = await Taro.showModal({
      title: '确认取消',
      content: '确定要取消此次 SOS 求助吗？',
      confirmColor: COLOR_CORAL,
    });
    if (!res.confirm) return;

    setIsLoading(true);
    try {
      await del(`/sos-alerts/${activeAlert.id}`, { params: { familyId } });
      Taro.showToast({ title: '已取消', icon: 'success' });
      Taro.navigateBack();
    } catch {
      Taro.showToast({ title: '取消失败', icon: 'none' });
      setIsLoading(false);
    }
  };

  /* ─── 拨打电话 ─── */
  const callNumber = (phone: string) => {
    Taro.makePhoneCall({ phoneNumber: phone });
  };

  /* ─── 加载中视图 ─── */
  if (isDataLoading) {
    return (
      <View className="sos-page sos-loading">
        <View className="loading-ring">
          <View className="loading-ring-inner" />
        </View>
      </View>
    );
  }

  // ─── 触发后视图 ───────────────────────────────────────────────────
  if (isTriggered) {
    return (
      <View className="sos-page sos-triggered">
        {/* 顶部状态 */}
        <View className="sos-triggered-header">
          <Text className="sos-triggered-icon">🚨</Text>
          <Text className="sos-triggered-title">SOS 已发出</Text>
          <Text className="sos-triggered-sub">紧急求助已通知所有家人</Text>
        </View>

        {/* 紧急信息卡 */}
        {recipient && (
          <View className="sos-triggered-info">
            <EmergencyInfoCard recipient={recipient} compact />
          </View>
        )}

        {/* 位置 */}
        {locationAddress && (
          <View className="sos-location-row">
            <Text className="sos-location-icon">📍</Text>
            <Text className="sos-location-text">{locationAddress}</Text>
          </View>
        )}

        {/* 拨打按钮 */}
        <ScrollView className="sos-call-scroll" scrollY>
          <View className="sos-call-buttons">
            <View className="sos-call-btn sos-call-btn-primary" onClick={() => callNumber('120')}>
              <Text className="sos-call-icon">🏥</Text>
              <Text className="sos-call-label">拨打 120 急救</Text>
            </View>
            <View className="sos-call-btn sos-call-btn-primary" onClick={() => callNumber('110')}>
              <Text className="sos-call-icon">🚔</Text>
              <Text className="sos-call-label">拨打 110 报警</Text>
            </View>
            {recipient?.doctorPhone && (
              <View className="sos-call-btn sos-call-btn-secondary" onClick={() => callNumber(recipient!.doctorPhone!)}>
                <Text className="sos-call-icon">👨‍⚕️</Text>
                <Text className="sos-call-label sos-call-label-secondary">
                  联系主治医生{recipient?.doctorName ? ` · ${recipient.doctorName}` : ''}
                </Text>
              </View>
            )}
            {recipient?.emergencyPhone && (
              <View className="sos-call-btn sos-call-btn-secondary" onClick={() => callNumber(recipient!.emergencyPhone!)}>
                <Text className="sos-call-icon">📞</Text>
                <Text className="sos-call-label sos-call-label-secondary">
                  紧急联系人{recipient?.emergencyContact ? ` · ${recipient.emergencyContact}` : ''}
                </Text>
              </View>
            )}

            {/* 家庭成员确认 */}
            {members.length > 0 && (
              <View className="sos-members-section">
                <Text className="sos-members-title">已通知家人</Text>
                {members.map((m) => (
                  <View key={m.id} className="sos-member-item">
                    <View className="sos-member-avatar">
                      <Text className="sos-member-avatar-text">
                        {m.avatarEmoji || m.displayAvatar || m.name?.[0] || '?'}
                      </Text>
                    </View>
                    <Text className="sos-member-name">{m.displayName || m.name}</Text>
                    <Text className="sos-member-status">已通知</Text>
                  </View>
                ))}
              </View>
            )}
          </View>
        </ScrollView>

        {/* 底部取消按钮 */}
        <View className="sos-cancel-bar">
          <Text
            className={`sos-cancel-btn ${isLoading ? 'disabled' : ''}`}
            onClick={isLoading ? undefined : cancelSos}
          >
            {isLoading ? '取消中...' : '取消 SOS'}
          </Text>
        </View>
      </View>
    );
  }

  // ─── 触发前视图 ───────────────────────────────────────────────────
  const pressSeconds = Math.round(3 * pressProgress);

  return (
    <View className="sos-page sos-pre">
      {/* 关闭按钮 */}
      <View className="sos-pre-header">
        <View className="sos-close-btn" onClick={() => Taro.navigateBack()}>
          <Text className="sos-close-icon">✕</Text>
        </View>
      </View>

      <View className="sos-pre-content">
        {/* 标题 */}
        <Text className="sos-pre-icon">⚠️</Text>
        <Text className="sos-pre-title">紧急求助</Text>
        <Text className="sos-pre-desc">长按下方按钮 3 秒{'\n'}将通知所有家人</Text>

        {/* SOS 圆形按钮 */}
        <View
          className={`sos-circle-btn ${isPressing ? 'pressing' : ''}`}
          onLongPress={startPress}
          onTouchEnd={endPress}
          onTouchCancel={endPress}
        >
          <View className="sos-circle-inner">
            <Text className="sos-circle-text">SOS</Text>
          </View>
          {/* 脉冲圈 */}
          {isPressing && (
            <>
              <View className="sos-ring sos-ring-1" />
              <View className="sos-ring sos-ring-2" />
            </>
          )}
        </View>

        {/* 按压进度文本 */}
        <Text className="sos-press-hint">
          {isPressing ? `保持按压中... ${pressSeconds} 秒` : '长按 3 秒触发'}
        </Text>

        {/* 进度条 */}
        {isPressing && (
          <View className="sos-progress-bar">
            <View className="sos-progress-fill" style={{ width: `${Math.round(pressProgress * 100)}%` }} />
          </View>
        )}
      </View>

      {/* 紧急信息卡 */}
      {recipient && (
        <View className="sos-pre-info">
          <EmergencyInfoCard recipient={recipient} />
        </View>
      )}
    </View>
  );
}
