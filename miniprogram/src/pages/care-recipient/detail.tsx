/**
 * 照护对象详情页
 */

import { useState, useEffect, useCallback } from 'react';
import { View, Text, ScrollView, Image, Input } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { get, post, del } from '../../services/api';
import { Storage } from '../../services/storage';
import type { CareRecipient } from '../../shared/models/care-recipient';
import type { Medication } from '../../shared/models/medication';
import type { CaregiverRecord } from '../../shared/models/caregiver-record';
import type { FamilyMember } from '../../shared/models/family';
import { getImageUrl } from '../../shared/utils/image';
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

/** 格式化照护时间段标签 */
function formatPeriodLabel(start: string, end?: string | null): string {
  const fmt = (d: string) => {
    const parts = d.substring(0, 10).split('-');
    if (parts.length < 3) return d;
    return `${parts[0]}年${parseInt(parts[1])}月${parseInt(parts[2])}日`;
  };
  if (!end) return `${fmt(start)} - 今`;
  return `${fmt(start)} - ${fmt(end)}`;
}

export default function CareRecipientDetailPage() {
  const params = (Taro.getCurrentInstance().router?.params as any) || {};
  const { id } = params;
  const familyId = Storage.getCurrentFamilyId();

  const [recipient, setRecipient] = useState<CareRecipient | null>(null);
  const [medications, setMedications] = useState<Medication[]>([]);
  const [loading, setLoading] = useState(true);

  // 照护人
  const [currentCaregiver, setCurrentCaregiver] = useState<CaregiverRecord | null>(null);
  const [caregiverRecords, setCaregiverRecords] = useState<CaregiverRecord[]>([]);
  const [showCaregiverSheet, setShowCaregiverSheet] = useState(false);
  const [caregiverMembers, setCaregiverMembers] = useState<FamilyMember[]>([]);
  const [selectedCaregiverId, setSelectedCaregiverId] = useState('');
  const [caregiverNote, setCaregiverNote] = useState('');
  const [switching, setSwitching] = useState(false);

  const load = useCallback(async () => {
    if (!id) { setLoading(false); return; }
    try {
      const [rRes, mRes, cgRes, cgRecordsRes] = await Promise.allSettled([
        get<CareRecipient>(`/care-recipients/${id}`, { familyId }),
        get<Medication[]>(`/medications`, { recipientId: id, familyId }),
        get<CaregiverRecord>(`/caregiver-records/current`, { careRecipientId: id, familyId }).catch(() => null),
        get<CaregiverRecord[]>(`/caregiver-records`, { careRecipientId: id, familyId }).catch(() => []),
      ]);
      if (rRes.status === 'fulfilled') setRecipient(rRes.value);
      if (mRes.status === 'fulfilled') setMedications(Array.isArray(mRes.value) ? mRes.value : []);
      if (cgRes.status === 'fulfilled' && cgRes.value) setCurrentCaregiver(cgRes.value as CaregiverRecord);
      if (cgRecordsRes.status === 'fulfilled') setCaregiverRecords((cgRecordsRes.value as CaregiverRecord[]) || []);
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

  /** 打开照护人切换弹层 */
  const openCaregiverSheet = async () => {
    // 加载家庭成员列表
    try {
      const members = await get<FamilyMember[]>(`/families/${familyId}/members`);
      setCaregiverMembers(Array.isArray(members) ? members : []);
      if (members && members.length > 0) {
        setSelectedCaregiverId(members[0].userId || '');
      }
    } catch {
      setCaregiverMembers([]);
    }
    setCaregiverNote('');
    setShowCaregiverSheet(true);
  };

  /** 切换照护人 */
  const handleSwitchCaregiver = async () => {
    if (!selectedCaregiverId) {
      Taro.showToast({ title: '请选择照护人', icon: 'none' });
      return;
    }
    setSwitching(true);
    try {
      const today = new Date();
      const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
      await post('/caregiver-records', {
        careRecipientId: id,
        caregiverId: selectedCaregiverId,
        periodStart: todayStr,
        note: caregiverNote.trim() || undefined,
      });
      Taro.showToast({ title: '切换成功', icon: 'success' });
      setShowCaregiverSheet(false);
      // 重新加载
      const [cgRes, cgRecordsRes] = await Promise.all([
        get<CaregiverRecord>(`/caregiver-records/current`, { careRecipientId: id, familyId }).catch(() => null),
        get<CaregiverRecord[]>(`/caregiver-records`, { careRecipientId: id, familyId }).catch(() => []),
      ]);
      if (cgRes) setCurrentCaregiver(cgRes as CaregiverRecord);
      if (cgRecordsRes) setCaregiverRecords((cgRecordsRes as CaregiverRecord[]) || []);
    } catch (e: any) {
      Taro.showToast({ title: e?.message || '切换失败', icon: 'none' });
    } finally {
      setSwitching(false);
    }
  };

  /** 删除照护记录 */
  const handleDeleteCaregiverRecord = async (recordId: string) => {
    const res = await Taro.showModal({ title: '确认删除', content: '确定要删除该照护记录吗？', confirmColor: '#E07B5D' });
    if (!res.confirm) return;
    try {
      await del(`/caregiver-records/${recordId}`, { params: { familyId } });
      Taro.showToast({ title: '已删除', icon: 'success' });
      // 重新加载
      const [cgRes, cgRecordsRes] = await Promise.all([
        get<CaregiverRecord>(`/caregiver-records/current`, { careRecipientId: id, familyId }).catch(() => null),
        get<CaregiverRecord[]>(`/caregiver-records`, { careRecipientId: id, familyId }).catch(() => []),
      ]);
      if (cgRes) setCurrentCaregiver(cgRes as CaregiverRecord);
      else setCurrentCaregiver(null);
      if (cgRecordsRes) setCaregiverRecords((cgRecordsRes as CaregiverRecord[]) || []);
    } catch {
      Taro.showToast({ title: '删除失败', icon: 'none' });
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

        {/* 当前照护人卡片 */}
        <View className="section" style={{ marginTop: '24rpx' }}>
          <View className="cg-card" onClick={openCaregiverSheet}>
            <View className="cg-card-header">
              <Text className="cg-card-label">当前主要照护人</Text>
              <View className="cg-switch-btn">
                <Text className="cg-switch-text">切换照护人 ›</Text>
              </View>
            </View>
            {currentCaregiver ? (
              <View className="cg-card-body">
                <View className="cg-avatar">
                  {currentCaregiver.caregiverAvatar ? (
                    <Image
                      className="cg-avatar-img"
                      src={getImageUrl(currentCaregiver.caregiverAvatar)}
                      mode="aspectFill"
                    />
                  ) : (
                    <Text className="cg-avatar-text">{(currentCaregiver.caregiverNickname || '?')[0]}</Text>
                  )}
                </View>
                <View className="cg-info">
                  <Text className="cg-name">{currentCaregiver.caregiverNickname || '家庭成员'}</Text>
                  <Text className="cg-period">照护时间：{formatPeriodLabel(currentCaregiver.periodStart, currentCaregiver.periodEnd)}</Text>
                  {currentCaregiver.note && <Text className="cg-note">备注：{currentCaregiver.note}</Text>}
                </View>
                <Text className="cg-arrow">›</Text>
              </View>
            ) : (
              <View className="cg-card-empty">
                <Text className="cg-empty-text">暂未指定主要照护人</Text>
                <Text className="cg-arrow">›</Text>
              </View>
            )}
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

      {/* 照护人切换底部弹层 */}
      {showCaregiverSheet && (
        <>
          <View className="sheet-mask" onClick={() => setShowCaregiverSheet(false)} />
          <View className="cg-sheet">
            <View className="sheet-handle" />
            <View className="sheet-title-row">
              <Text className="sheet-title-lg">照护人记录</Text>
              <View className="sheet-add-btn" onClick={() => {
                setShowCaregiverSheet(false);
                setTimeout(() => openCaregiverSheet(), 100);
              }}>
                <Text className="sheet-add-btn-text">+ 添加记录</Text>
              </View>
            </View>

            {/* 历史记录列表 */}
            <ScrollView className="cg-history-scroll" scrollY>
              {caregiverRecords.length === 0 ? (
                <View className="cg-empty">
                  <Text className="cg-empty-icon">📋</Text>
                  <Text className="cg-empty-desc">暂无照护记录</Text>
                </View>
              ) : (
                caregiverRecords.map((record) => (
                  <View key={record.id} className="cg-record-item">
                    <View className="cg-record-avatar">
                      {record.caregiverAvatar ? (
                        <Image
                          className="cg-record-avatar-img"
                          src={getImageUrl(record.caregiverAvatar)}
                          mode="aspectFill"
                        />
                      ) : (
                        <Text className="cg-record-avatar-text">{(record.caregiverNickname || '?')[0]}</Text>
                      )}
                    </View>
                    <View className="cg-record-info">
                      <View className="cg-record-name-row">
                        <Text className="cg-record-name">{record.caregiverNickname || '家庭成员'}</Text>
                        {!record.periodEnd && (
                          <View className="cg-current-badge">
                            <Text className="cg-current-text">当前</Text>
                          </View>
                        )}
                      </View>
                      <Text className="cg-record-period">{formatPeriodLabel(record.periodStart, record.periodEnd)}</Text>
                      {record.note && <Text className="cg-record-note">{record.note}</Text>}
                    </View>
                    {!record.periodEnd && caregiverRecords.length > 1 && (
                      <Text
                        className="cg-record-delete"
                        onClick={() => handleDeleteCaregiverRecord(record.id)}
                      >删除</Text>
                    )}
                  </View>
                ))
              )}
            </ScrollView>

            {/* 添加新照护人 */}
            <View className="cg-add-form">
              <Text className="cg-add-title">添加照护人</Text>
              <View className="cg-member-list">
                {caregiverMembers.map((m) => (
                  <View
                    key={m.userId}
                    className={`cg-member-item ${selectedCaregiverId === m.userId ? 'selected' : ''}`}
                    onClick={() => setSelectedCaregiverId(m.userId || '')}
                  >
                    <View className="cg-member-avatar">
                      {m.avatarUrl ? (
                        <Image className="cg-member-avatar-img" src={getImageUrl(m.avatarUrl)} mode="aspectFill" />
                      ) : (
                        <Text className="cg-member-avatar-text">{(m.nickname || '?')[0]}</Text>
                      )}
                    </View>
                    <Text className="cg-member-name">{m.nickname || '成员'}</Text>
                    {selectedCaregiverId === m.userId && <Text className="cg-member-check">✓</Text>}
                  </View>
                ))}
              </View>
              <View className="cg-note-wrap">
                <Input
                  className="cg-note-input"
                  placeholder="备注（选填）"
                  value={caregiverNote}
                  onInput={(e: any) => setCaregiverNote(e.detail.value)}
                  maxLength={200}
                />
              </View>
              <View
                className={`cg-save-btn ${switching ? 'disabled' : ''}`}
                onClick={switching ? undefined : handleSwitchCaregiver}
              >
                <Text className="cg-save-btn-text">{switching ? '保存中...' : '保存'}</Text>
              </View>
            </View>
          </View>
        </>
      )}
    </View>
  );
}
