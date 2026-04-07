/**
 * 照护对象详情页
 */

import { useState, useEffect, useCallback } from 'react';
import { View, Text, ScrollView } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { get, del } from '../../services/api';
import { Storage } from '../../services/storage';
import type { CareRecipient } from '../../shared/models/care-recipient';
import type { Medication } from '../../shared/models/medication';
import './detail.scss';

function maskPhone(phone: string): string {
  if (!phone || phone.length <= 7) return phone;
  return `${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}`;
}

function toArray(val: string | string[] | null | undefined): string[] {
  if (!val) return [];
  if (Array.isArray(val)) return val;
  return String(val).split(',').map((s) => s.trim()).filter(Boolean);
}

export default function CareRecipientDetailPage() {
  const params = (Taro.getCurrentInstance().router?.params as any) || {};
  const { id } = params;
  const familyId = Storage.getCurrentFamilyId();

  const [recipient, setRecipient] = useState<CareRecipient | null>(null);
  const [medications, setMedications] = useState<Medication[]>([]);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    if (!id) { setLoading(false); return; }
    try {
      const [rRes, mRes] = await Promise.allSettled([
        get<CareRecipient>(`/care-recipients/${id}`, { familyId }),
        get<Medication[]>(`/medications`, { recipientId: id, familyId }),
      ]);
      if (rRes.status === 'fulfilled') setRecipient(rRes.value);
      if (mRes.status === 'fulfilled') setMedications(Array.isArray(mRes.value) ? mRes.value : []);
    } catch (e) {
      console.error('[detail] load error', e);
    } finally {
      setLoading(false);
    }
  }, [id, familyId]);

  useEffect(() => { load(); }, [load]);

  const handleDelete = async () => {
    const res = await Taro.showModal({
      title: '确认删除',
      content: `确定要删除照护对象"${recipient?.name}"吗？此操作不可恢复。`,
      confirmColor: '#E07B5D',
    });
    if (!res.confirm) return;
    try {
      await del(`/care-recipients/${id}`, { params: { familyId } });
      Taro.showToast({ title: '已删除', icon: 'success' });
      setTimeout(() => Taro.navigateBack(), 1500);
    } catch (e: any) {
      Taro.showToast({ title: e?.message || '删除失败', icon: 'none' });
    }
  };

  if (loading) {
    return (
      <View className="detail-page loading-state">
        <Text className="loading-text">加载中...</Text>
      </View>
    );
  }

  if (!recipient) {
    return (
      <View className="detail-page empty-state">
        <Text className="empty-emoji">❓</Text>
        <Text className="empty-title">未找到该照护对象</Text>
      </View>
    );
  }

  const ageStr = recipient.birthDate
    ? `${new Date().getFullYear() - new Date(recipient.birthDate).getFullYear()}岁`
    : null;
  const genderLabel = recipient.gender === 'male' ? '男' : recipient.gender === 'female' ? '女' : '其他';

  return (
    <View className="detail-page">
      {/* 顶部导航栏 */}
      <View className="detail-navbar">
        <View className="navbar-left" onClick={() => Taro.navigateBack()}>
          <Text className="navbar-back">‹</Text>
        </View>
        <Text className="navbar-title">{recipient.name}</Text>
        <View className="navbar-right">
          <Text className="navbar-edit" onClick={() => Taro.navigateTo({ url: `/pages/care-recipient/add?id=${id}` })}>编辑</Text>
          <Text className="navbar-delete" onClick={handleDelete}>删除</Text>
        </View>
      </View>

      <ScrollView className="detail-scroll" scrollY>

        {/* 头部卡片 */}
        <View className="header-card">
          <View className="header-avatar">
            <Text className="header-avatar-text">{recipient.avatarEmoji || '👤'}</Text>
          </View>
          <View className="header-info">
            <Text className="header-name">{recipient.name}</Text>
            <View className="header-tags">
              {recipient.bloodType && (
                <View className="tag tag-blood">
                  <Text className="tag-text">🩸 {recipient.bloodType}型</Text>
                </View>
              )}
              {ageStr && (
                <View className="tag">
                  <Text className="tag-text">{ageStr}</Text>
                </View>
              )}
              {recipient.gender && (
                <View className="tag">
                  <Text className="tag-text">{genderLabel}</Text>
                </View>
              )}
            </View>
          </View>
        </View>

        {/* 健康警示 */}
        {(toArray(recipient.allergies).length > 0 || recipient.medicalHistory || toArray(recipient.chronicConditions).length > 0) && (
          <View className="section">
            <View className="section-title-row">
              <Text className="section-title">健康信息</Text>
            </View>
            <View className="alert-card">
              {toArray(recipient.allergies).length > 0 && (
                <View className="alert-row alert-row-warning">
                  <Text className="alert-icon">⚠️</Text>
                  <Text className="alert-label">过敏</Text>
                  <Text className="alert-value">{toArray(recipient.allergies).join('、')}</Text>
                </View>
              )}
              {toArray(recipient.chronicConditions).length > 0 && (
                <View className="alert-row">
                  <Text className="alert-icon">🩺</Text>
                  <Text className="alert-label">慢病</Text>
                  <Text className="alert-value">{toArray(recipient.chronicConditions).join('、')}</Text>
                </View>
              )}
              {recipient.medicalHistory && (
                <View className="alert-row">
                  <Text className="alert-icon">📋</Text>
                  <Text className="alert-label">病史</Text>
                  <Text className="alert-value">{recipient.medicalHistory}</Text>
                </View>
              )}
            </View>
          </View>
        )}

        {/* 基本信息 */}
        <View className="section">
          <Text className="section-title">基本信息</Text>
          <View className="info-card">
            {recipient.phone && (
              <View className="info-row">
                <Text className="info-label">联系电话</Text>
                <Text className="info-value">{maskPhone(recipient.phone)}</Text>
              </View>
            )}
            {recipient.currentAddress && (
              <View className="info-row">
                <Text className="info-label">现居地址</Text>
                <Text className="info-value">{recipient.currentAddress}</Text>
              </View>
            )}
            {recipient.emergencyContact && (
              <View className="info-row">
                <Text className="info-label">紧急联系人</Text>
                <Text className="info-value">
                  {recipient.emergencyContact}
                  {recipient.emergencyPhone ? `  ${maskPhone(recipient.emergencyPhone)}` : ''}
                </Text>
              </View>
            )}
            {!recipient.phone && !recipient.currentAddress && !recipient.emergencyContact && (
              <Text className="info-empty">暂无基本信息</Text>
            )}
          </View>
        </View>

        {/* 就医信息 */}
        {(recipient.hospital || recipient.doctorName || recipient.doctorPhone) && (
          <View className="section">
            <Text className="section-title">就医信息</Text>
            <View className="info-card">
              {recipient.hospital && (
                <View className="info-row">
                  <Text className="info-label">主治医院</Text>
                  <Text className="info-value">{recipient.hospital}{recipient.department ? ` · ${recipient.department}` : ''}</Text>
                </View>
              )}
              {recipient.doctorName && (
                <View className="info-row">
                  <Text className="info-label">主治医生</Text>
                  <Text className="info-value">{recipient.doctorName}</Text>
                </View>
              )}
              {recipient.doctorPhone && (
                <View className="info-row">
                  <Text className="info-label">医生电话</Text>
                  <Text
                    className="info-value info-value-link"
                    onClick={() => Taro.makePhoneCall({ phoneNumber: recipient.doctorPhone! })}
                  >
                    {maskPhone(recipient.doctorPhone)} ☏
                  </Text>
                </View>
              )}
            </View>
          </View>
        )}

        {/* 药品管理 */}
        <View className="section">
          <Text className="section-title">药品管理</Text>
          {medications.length > 0 ? (
            <View className="med-list">
              {medications.map((med) => (
                <View key={med.id} className="med-card">
                  <View className="med-card-left">
                    <Text className="med-card-name">{med.name}</Text>
                    {med.dosage && <Text className="med-card-dose">{med.dosage}</Text>}
                  </View>
                  <View className="med-card-right">
                    <Text className="med-card-freq">
                      {med.frequency === 'daily' ? '每日' : med.frequency === 'weekly' ? '每周' : med.frequency === 'as_needed' ? '必要时' : '单次'}
                    </Text>
                  </View>
                </View>
              ))}
            </View>
          ) : (
            <View className="empty-card">
              <Text className="empty-card-text">暂无药品</Text>
            </View>
          )}
        </View>

        <View className="bottom-pad" />
        <View className="bottom-pad-for-fab" />
      </ScrollView>

      {/* 右下角添加药品按钮 */}
      <View
        className="fab-add-med"
        onClick={() => Taro.navigateTo({ url: `/pages/medication/index?addForRecipientId=${id}` })}
      >
        <Text className="fab-add-med-icon">+</Text>
        <Text className="fab-add-med-label">添加药品</Text>
      </View>
    </View>
  );
}
