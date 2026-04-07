/**
 * 家庭页 - 与 Flutter family_page.dart 完全对齐
 * 家庭信息卡片 + 成员列表 + 贡献统计 + 添加按钮
 */

import { useState, useEffect, useCallback } from 'react';
import { View, Text, ScrollView, Image } from '@tarojs/components';
import Taro, { useDidShow } from '@tarojs/taro';
import { get, post, put, del } from '../../services/api';
import { Storage } from '../../services/storage';
import { getImageUrl } from '../../shared/utils/image';
import type { Family, FamilyMemberDetail, FamilyMemberRole } from '../../shared/models/family';
import type { CareRecipient } from '../../shared/models/care-recipient';
import './index.scss';

/* ============================
   常量
   ============================ */

const ROLE_LABELS: Record<string, string> = {
  owner: '管理员',
  coordinator: '协调管理员',
  caregiver: '照护人',
  guest: '访客',
};

const ROLE_COLORS: Record<string, string> = {
  owner: '#7B9E87',
  coordinator: '#4A90D9',
  caregiver: '#6B6B6B',
  guest: '#B0ADAD',
};

/** 角色功能描述 */
const ROLE_DESCRIPTIONS: Record<string, string> = {
  owner: '创建者，拥有最高权限',
  coordinator: '协调管理员：可添加任务/复诊、管理成员和照护对象',
  caregiver: '照护人：记录日志、完成分配的任务，不能新建任务',
  guest: '访客：仅查看和记录日志',
};

const SELECTABLE_ROLES: Array<{ value: string; label: string }> = [
  { value: 'coordinator', label: '协调管理员' },
  { value: 'caregiver', label: '照护人' },
  { value: 'guest', label: '访客' },
];

/* ============================
   类型
   ============================ */

/** 贡献统计条目 */
interface ContributionItem {
  userId: string;
  name: string;
  careLogs: number;
  medCheckins: number;
}

/* ============================
   工具函数
   ============================ */

function parseLocalDate(isoStr: string): Date {
  const d = new Date(isoStr.replace(/-/g, '/'));
  d.setHours(d.getHours() + 8);
  return d;
}

function formatDate(isoStr: string): string {
  const d = parseLocalDate(isoStr);
  return `${d.getMonth() + 1}月${d.getDate()}日`;
}

function maskPhone(phone: string): string {
  if (!phone || phone.length <= 7) return phone;
  return `${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}`;
}

function canManageMembers(role: FamilyMemberRole): boolean {
  return role === 'owner' || role === 'coordinator';
}

function canManageFamily(role: FamilyMemberRole): boolean {
  return role === 'owner';
}

function isElevatedRole(role: FamilyMemberRole): boolean {
  return role === 'owner' || role === 'coordinator';
}

/* ============================
   主组件
   ============================ */

export default function FamilyPage() {
  const [family, setFamily] = useState<Family | null>(null);
  const [members, setMembers] = useState<FamilyMemberDetail[]>([]);
  const [recipients, setRecipients] = useState<CareRecipient[]>([]);
  const [contributions, setContributions] = useState<ContributionItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [contributionLoading, setContributionLoading] = useState(false);

  // Sheet 状态
  const [activeSheet, setActiveSheet] = useState<
    'addMember' | 'addRecipient' | 'editMember' | 'editFamily' | null
  >(null);
  const [selectedMember, setSelectedMember] = useState<FamilyMemberDetail | null>(null);

  // 表单状态
  const [addPhone, setAddPhone] = useState('');
  const [addRole, setAddRole] = useState<string>('caregiver');
  const [submitting, setSubmitting] = useState(false);

  // 添加照护对象表单
  const [addRecipientName, setAddRecipientName] = useState('');
  const [addRecipientPhone, setAddRecipientPhone] = useState('');
  const [addRecipientEmergency, setAddRecipientEmergency] = useState('');

  // 编辑家庭
  const [editFamilyName, setEditFamilyName] = useState('');

  // 编辑成员表单
  const [editMemberNickname, setEditMemberNickname] = useState('');
  const [editMemberRole, setEditMemberRole] = useState<string>('caregiver');

  const familyId = Storage.getCurrentFamilyId();
  const currentUserId = Storage.getUserId();

  /* ─── 数据加载 ─── */
  const loadFamily = useCallback(async () => {
    if (!familyId) return;
    try {
      const data = await get<Family>(`/families/${familyId}`);
      setFamily(data);
      setEditFamilyName(data.name);
    } catch (err) {
      console.error('加载家庭信息失败', err);
    }
  }, [familyId]);

  const loadMembers = useCallback(async () => {
    if (!familyId) return;
    try {
      const data = await get<FamilyMemberDetail[]>(`/families/${familyId}/members`);
      setMembers(data ?? []);
    } catch (err) {
      console.error('加载成员列表失败', err);
    }
  }, [familyId]);

  const loadRecipients = useCallback(async () => {
    if (!familyId) return;
    try {
      const data = await get<CareRecipient[]>(`/care-recipients?familyId=${familyId}`);
      setRecipients(data ?? []);
    } catch (err) {
      console.error('加载照护对象失败', err);
    }
  }, [familyId]);

  const loadContributions = useCallback(async () => {
    if (!familyId) return;
    setContributionLoading(true);
    try {
      const [careLogsRes, medLogsRes] = await Promise.allSettled([
        get<any[]>('/care-logs', { familyId, limit: 100 }),
        get<any[]>('/medication-logs/timeline', { familyId, days: 45 }),
      ]);

      const now = new Date();
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
      const statsMap = new Map<string, ContributionItem>();

      // 护理日志（仅当月数据）
      if (careLogsRes.status === 'fulfilled') {
        const logs = Array.isArray(careLogsRes.value) ? careLogsRes.value : [];
        for (const log of logs) {
          const createdAt = new Date(log.createdAt?.replace(/-/g, '/') ?? '');
          if (!log.authorId || createdAt < monthStart) continue;
          if (!statsMap.has(log.authorId)) {
            statsMap.set(log.authorId, {
              userId: log.authorId,
              name: log.authorName ?? '未知',
              careLogs: 0,
              medCheckins: 0,
            });
          }
          statsMap.get(log.authorId)!.careLogs += 1;
        }
      }

      // 用药打卡（仅当月数据）
      if (medLogsRes.status === 'fulfilled') {
        const medLogs = medLogsRes.value;
        const items = Array.isArray(medLogs) ? medLogs : (medLogs?.items ?? []);
        for (const log of items) {
          const createdAt = new Date(log.takenAt?.replace(/-/g, '/') ?? '');
          const authorId = log.takenBy?.id;
          if (!authorId || createdAt < monthStart) continue;
          if (!statsMap.has(authorId)) {
            statsMap.set(authorId, {
              userId: authorId,
              name: log.takenBy?.name ?? '未知',
              careLogs: 0,
              medCheckins: 0,
            });
          }
          statsMap.get(authorId)!.medCheckins += 1;
        }
      }

      const sorted = Array.from(statsMap.values())
        .sort((a, b) => (b.careLogs + b.medCheckins) - (a.careLogs + a.medCheckins))
        .slice(0, 6);

      setContributions(sorted);
    } catch (err) {
      console.error('加载贡献统计失败', err);
    } finally {
      setContributionLoading(false);
    }
  }, [familyId]);

  const loadAll = useCallback(async () => {
    setLoading(true);
    await Promise.all([loadFamily(), loadMembers(), loadRecipients()]);
    await loadContributions();
    setLoading(false);
  }, [loadFamily, loadMembers, loadRecipients, loadContributions]);

  useEffect(() => {
    loadAll();
  }, [loadAll]);

  useDidShow(() => {
    if (familyId) loadAll();
  });

  /* ─── 复制邀请码 ─── */
  const handleCopyInviteCode = async () => {
    if (!family?.inviteCode) return;
    try {
      await Taro.setClipboardData({ data: family.inviteCode });
      Taro.showToast({ title: '已复制', icon: 'success', duration: 1500 });
    } catch {
      Taro.showToast({ title: '复制失败', icon: 'none', duration: 1500 });
    }
  };

  /* ─── 添加成员 ─── */
  const handleAddMember = async () => {
    if (!addPhone.trim()) {
      Taro.showToast({ title: '请输入手机号', icon: 'none' });
      return;
    }
    if (!/^1[3-9]\d{9}$/.test(addPhone.trim())) {
      Taro.showToast({ title: '手机号格式不正确', icon: 'none' });
      return;
    }
    if (!familyId) return;

    setSubmitting(true);
    try {
      await post(`/families/${familyId}/members`, {
        phone: addPhone.trim(),
        role: addRole as FamilyMemberRole,
      });
      Taro.showToast({ title: '添加成功', icon: 'success', duration: 1500 });
      setActiveSheet(null);
      setAddPhone('');
      setAddRole('caregiver');
      await loadMembers();
    } catch (err) {
      console.error('添加成员失败', err);
      Taro.showToast({ title: '添加失败，请检查手机号', icon: 'none', duration: 2000 });
    } finally {
      setSubmitting(false);
    }
  };

  /* ─── 保存成员编辑 ─── */
  const handleSaveMember = async () => {
    if (!familyId || !selectedMember) return;
    setSubmitting(true);
    try {
      const data: Record<string, string> = {};
      const trimmedNick = editMemberNickname.trim();
      if (trimmedNick && trimmedNick !== selectedMember.nickname) {
        data.nickname = trimmedNick;
      }
      if (editMemberRole !== selectedMember.role) {
        data.role = editMemberRole;
      }
      if (Object.keys(data).length === 0) {
        setActiveSheet(null);
        setSelectedMember(null);
        return;
      }
      await put(`/families/${familyId}/members/${selectedMember.id}`, data);
      Taro.showToast({ title: '已保存', icon: 'success', duration: 1500 });
      setActiveSheet(null);
      setSelectedMember(null);
      await loadMembers();
    } catch (err) {
      console.error('保存成员失败', err);
      Taro.showToast({ title: '保存失败', icon: 'none', duration: 2000 });
    } finally {
      setSubmitting(false);
    }
  };

  /* ─── 移除成员 ─── */
  const handleRemoveMember = async (memberId: string) => {
    if (!familyId) return;
    const res = await Taro.showModal({
      title: '移除成员',
      content: '确定要移除该成员吗？移除后可通过邀请码重新加入。',
      confirmText: '移除',
      confirmColor: '#E07B5D',
      cancelText: '取消',
    });
    if (res.confirm !== true) return;

    setSubmitting(true);
    try {
      await del(`/families/${familyId}/members/${memberId}`);
      Taro.showToast({ title: '已移除', icon: 'success', duration: 1500 });
      setActiveSheet(null);
      setSelectedMember(null);
      await loadMembers();
    } catch (err) {
      console.error('移除成员失败', err);
      Taro.showToast({ title: '移除失败', icon: 'none', duration: 2000 });
    } finally {
      setSubmitting(false);
    }
  };

  /* ─── 添加照护对象 ─── */
  const handleAddRecipient = async () => {
    if (!addRecipientName.trim()) {
      Taro.showToast({ title: '请输入照护对象姓名', icon: 'none' });
      return;
    }
    if (!familyId) return;

    setSubmitting(true);
    try {
      await post('/care-recipients', {
        familyId,
        name: addRecipientName.trim(),
        phone: addRecipientPhone.trim() || null,
        emergencyPhone: addRecipientEmergency.trim() || null,
      });
      Taro.showToast({ title: '添加成功', icon: 'success', duration: 1500 });
      setActiveSheet(null);
      setAddRecipientName('');
      setAddRecipientPhone('');
      setAddRecipientEmergency('');
      await loadRecipients();
    } catch (err) {
      console.error('添加照护对象失败', err);
      Taro.showToast({ title: '添加失败', icon: 'none', duration: 2000 });
    } finally {
      setSubmitting(false);
    }
  };

  /* ─── 编辑家庭名称 ─── */
  const handleUpdateFamilyName = async () => {
    if (!editFamilyName.trim() || !family) return;
    setSubmitting(true);
    try {
      await put(`/families/${family.id}`, { name: editFamilyName.trim() });
      Taro.showToast({ title: '已更新', icon: 'success', duration: 1500 });
      setActiveSheet(null);
      await loadFamily();
    } catch (err) {
      console.error('更新家庭名称失败', err);
      Taro.showToast({ title: '更新失败', icon: 'none', duration: 2000 });
    } finally {
      setSubmitting(false);
    }
  };

  /* ─── 合并列表 ─── */
  const listItems = [
    ...members.map((m) => ({ kind: 'member' as const, data: m })),
    ...recipients.map((r) => ({ kind: 'recipient' as const, data: r })),
  ];

  const myRole: FamilyMemberRole = (family?.myRole ?? 'guest') as FamilyMemberRole;
  const showManageButtons = canManageMembers(myRole);
  const showEditFamily = canManageFamily(myRole);
  const currentMonth = new Date().getMonth() + 1;

  /* ─── 贡献排行 ─── */
  const maxTotal = contributions.length > 0
    ? (contributions[0].careLogs + contributions[0].medCheckins)
    : 0;

  /* ─── 贡献条颜色（按排名递减）─── */
  const contributionColors = [
    '#7B9E87',
    'rgba(123, 158, 135, 0.7)',
    'rgba(123, 158, 135, 0.5)',
    'rgba(123, 158, 135, 0.35)',
    'rgba(123, 158, 135, 0.25)',
    'rgba(123, 158, 135, 0.15)',
  ];

  return (
    <View className="family-page">
      {/* ─── 顶部导航栏 ─── */}
      <View className="family-navbar">
        <View className="navbar-back" onClick={() => Taro.navigateBack()}>
          <Text className="navbar-back-icon">‹</Text>
        </View>
        <Text className="navbar-title">家庭成员</Text>
        {showEditFamily ? (
          <View className="navbar-edit" onClick={() => setActiveSheet('editFamily')}>
            <Text className="navbar-edit-text">编辑</Text>
          </View>
        ) : (
          <View style={{ width: '64rpx' }} />
        )}
      </View>

      {/* ─── 加载中 ─── */}
      {loading && (
        <View className="loading-row">
          <Text className="loading-text">加载中...</Text>
        </View>
      )}

      {/* ─── 无家庭 ─── */}
      {!loading && !familyId && (
        <View className="empty-state">
          <Text className="empty-emoji">🏠</Text>
          <Text className="empty-title">还没有加入家庭</Text>
          <Text className="empty-desc">在"我的"页面加入或创建家庭</Text>
        </View>
      )}

      {/* ─── 有家庭 ─── */}
      {!loading && familyId && (
        <ScrollView className="family-scroll" scrollY>
          {/* 家庭信息卡片（Flutter: border-radius 24, emoji + 名称 + 邀请码） */}
          {family && (
            <View className="family-card">
              <View className="family-card-header">
                <View className="family-avatar">
                  {family.avatarUrl ? (
                    <Image className="family-avatar-img" src={getImageUrl(family.avatarUrl || '')} mode="aspectFill" />
                  ) : (
                    <Text className="family-avatar-text">👨‍👩‍👧‍👦</Text>
                  )}
                </View>
                <View className="family-info">
                  <Text className="family-name">{family.name}</Text>
                  {family.description && (
                    <Text className="family-desc">{family.description}</Text>
                  )}
                  <View className="family-member-badge">
                    <Text className="family-member-badge-text">
                      {family.memberCount ?? members.length} 位成员
                    </Text>
                  </View>
                </View>
              </View>

              <View className="family-divider" />

              {/* 邀请码区域 */}
              <View className="invite-section">
                <View className="invite-left">
                  <Text className="invite-label">邀请码</Text>
                  <Text className="invite-code">{family.inviteCode}</Text>
                </View>
                <View className="copy-invite-btn" onClick={handleCopyInviteCode}>
                  <Text className="copy-invite-icon">📋</Text>
                  <Text className="copy-invite-text">复制邀请链接</Text>
                </View>
              </View>
            </View>
          )}

          {/* ─── 成员列表区域 ─── */}
          <View className="members-section">
            <View className="section-header-row">
              <Text className="section-title-text">成员与照护对象</Text>
              <Text className="section-count-text">{listItems.length} 人</Text>
            </View>

            {listItems.length === 0 ? (
              <View className="empty-list">
                <Text className="empty-list-text">暂无成员</Text>
              </View>
            ) : (
              listItems.map((item) => {
                if (item.kind === 'member') {
                  const m = item.data;
                  const roleColor = ROLE_COLORS[m.role] ?? '#B0ADAD';
                  const isMe = m.userId === currentUserId;

                  return (
                    <View
                      key={m.id}
                      className={`member-card`}
                      onClick={() => {
                        if (showManageButtons && !isMe) {
                          setSelectedMember(m);
                          setEditMemberNickname(m.nickname || '');
                          setEditMemberRole(m.role as string || 'caregiver');
                          setActiveSheet('editMember');
                        }
                      }}
                    >
                      {/* 头像 */}
                      <View className="member-avatar-wrap">
                        {m.avatarUrl ? (
                          <Image
                            className="member-avatar-img"
                            src={getImageUrl(m.avatarUrl || '')}
                            mode="aspectFill"
                          />
                        ) : (
                          <View className="member-avatar-placeholder">
                            <Text className="member-avatar-text">
                              {m.nickname ? m.nickname.slice(0, 1) : (m.phone ? m.phone.slice(-4) : '?')}
                            </Text>
                          </View>
                        )}
                        {m.isOnline && <View className="online-dot" />}
                      </View>

                      {/* 信息 */}
                      <View className="member-info">
                        <View className="member-name-row">
                          <Text className="member-name">
                            {m.nickname || '未命名'}
                            {m.userName && m.userName !== m.nickname ? `（${m.userName}）` : ''}
                          </Text>
                          {isMe && <Text className="member-me-tag">（我）</Text>}
                          <View
                            className={`member-role-badge ${isElevatedRole(m.role as FamilyMemberRole) ? 'member-role-badge-elevated' : ''}`}
                            style={{ backgroundColor: `${roleColor}1A` }}
                          >
                            {isElevatedRole(m.role as FamilyMemberRole) && (
                              <Text className="member-role-star">★</Text>
                            )}
                            <Text className="member-role-text" style={{ color: roleColor }}>
                              {ROLE_LABELS[m.role as string] ?? m.role}
                            </Text>
                          </View>
                        </View>
                        {m.phone && <Text className="member-phone">{maskPhone(m.phone)}</Text>}
                      </View>

                      {showManageButtons && !isMe && (
                        <Text className="member-arrow">›</Text>
                      )}
                    </View>
                  );
                } else {
                  const r = item.data;
                  return (
                    <View
                      key={r.id}
                      className="member-card member-card-recipient"
                      onClick={() => {
                        Taro.navigateTo({ url: `/pages/care-recipient/detail?id=${r.id}` });
                      }}
                    >
                      {/* 头像 */}
                      <View className="member-avatar-wrap">
                        {r.avatarUrl ? (
                          <Image
                            className="member-avatar-img"
                            src={getImageUrl(r.avatarUrl || '')}
                            mode="aspectFill"
                          />
                        ) : (
                          <View className="member-avatar-placeholder member-avatar-placeholder-recipient">
                            <Text className="member-avatar-text member-avatar-text-recipient">
                              {r.avatarEmoji ?? (r.name ? r.name.slice(0, 1) : '👤')}
                            </Text>
                          </View>
                        )}
                      </View>

                      {/* 信息 */}
                      <View className="member-info">
                        <View className="member-name-row">
                          <Text className="member-name">{r.name}</Text>
                          <View className="member-role-badge member-role-badge-recipient">
                            <Text className="member-role-text member-role-text-recipient">照护对象</Text>
                          </View>
                        </View>
                        {r.emergencyPhone && (
                          <View className="recipient-emergency-row">
                            <Text className="recipient-emergency-icon">📞</Text>
                            <Text className="recipient-emergency-phone">{r.emergencyPhone}</Text>
                          </View>
                        )}
                        {r.age && (
                          <Text className="member-phone">
                            {r.age}岁 · {r.gender === 'male' ? '男' : r.gender === 'female' ? '女' : ''}
                          </Text>
                        )}
                      </View>

                      <Text className="member-arrow">›</Text>
                    </View>
                  );
                }
              })
            )}
          </View>

          {/* ─── 本月照护贡献统计卡片 ─── */}
          <View className="stats-card">
            <View className="stats-header">
              <View className="stats-icon-wrap">
                <Text className="stats-icon">📊</Text>
              </View>
              <Text className="stats-title">本月照护贡献</Text>
              <View className="stats-month-badge">
                <Text className="stats-month-text">{currentMonth}月</Text>
              </View>
            </View>

            {contributionLoading ? (
              <View className="stats-loading">
                <Text className="stats-loading-text">加载中...</Text>
              </View>
            ) : contributions.length === 0 ? (
              <View>
                <View className="stats-empty-icon">
                  <View className="stats-empty-bar-wrap">
                    <Text className="stats-empty-bar-icon">📊</Text>
                  </View>
                </View>
                <Text className="stats-empty-text">暂无本月数据</Text>
              </View>
            ) : (
              <View className="stats-list">
                {contributions.map((item, idx) => {
                  const total = item.careLogs + item.medCheckins;
                  const fraction = maxTotal > 0 ? total / maxTotal : 0;
                  const barColor = contributionColors[idx] ?? contributionColors[contributionColors.length - 1];
                  return (
                    <View key={item.userId} className="stats-bar-row">
                      <View className="stats-bar-top">
                        <Text className="stats-bar-name">{item.name}</Text>
                        <Text className="stats-bar-count" style={{ color: barColor }}>
                          {total}
                        </Text>
                      </View>
                      <View className="stats-bar-track">
                        <View
                          className="stats-bar-fill"
                          style={{
                            width: `${fraction * 100}%`,
                            backgroundColor: barColor,
                          }}
                        />
                      </View>
                      <Text className="stats-bar-sub">
                        {item.careLogs}条日志 · {item.medCheckins}次打卡
                      </Text>
                    </View>
                  );
                })}
              </View>
            )}
          </View>

          {/* 底部间距 */}
          <View style={{ height: '24rpx' }} />
        </ScrollView>
      )}

      {/* ─── 底部操作按钮（Flutter: 固定在底部，图标 + 文字一行两个）─── */}
      {showManageButtons && familyId && (
        <View className="action-section">
          <View className="action-divider" />
          <View className="action-btn-row">
            <View
              className="action-btn"
              onClick={() => setActiveSheet('addMember')}
            >
              <Text className="action-btn-icon">👤</Text>
              <Text className="action-btn-text">添加成员</Text>
            </View>
            <View
              className="action-btn action-btn-recipient"
              onClick={() => {
                Taro.navigateTo({ url: '/pages/care-recipient/add' });
              }}
            >
              <Text className="action-btn-icon">🧓</Text>
              <Text className="action-btn-text action-btn-text-recipient">添加照护对象</Text>
            </View>
          </View>
        </View>
      )}

      {/* ─── Sheet: 添加成员 ─── */}
      {activeSheet === 'addMember' && (
        <View className="sheet-overlay" onClick={() => setActiveSheet(null)}>
          <View className="sheet-container" onClick={(e) => e.stopPropagation()}>
            <View className="sheet-handle" />
            <View className="sheet-header">
              <Text className="sheet-title">添加家庭成员</Text>
              <View
                className={`sheet-confirm-btn ${submitting ? 'disabled' : ''}`}
                onClick={handleAddMember}
              >
                <Text className="sheet-confirm-text">{submitting ? '添加中...' : '添加'}</Text>
              </View>
            </View>

            <View className="sheet-body">
              <Text className="sheet-label">手机号</Text>
              <View className="sheet-input-wrap">
                <input
                  className="sheet-input"
                  type="number"
                  placeholder="请输入成员手机号"
                  value={addPhone}
                  onInput={(e: any) => setAddPhone(e.detail.value)}
                  maxLength={11}
                />
              </View>

              <Text className="sheet-label">角色</Text>
              <View className="role-select-list">
                {SELECTABLE_ROLES.map((r) => (
                  <View
                    key={r.value}
                    className={`role-select-item ${addRole === r.value ? 'selected' : ''}`}
                    onClick={() => setAddRole(r.value)}
                  >
                    <View
                      className="role-select-dot"
                      style={{
                        backgroundColor: addRole === r.value
                          ? ROLE_COLORS[r.value as FamilyMemberRole]
                          : '#E0E0E0',
                      }}
                    />
                    <Text
                      className={`role-select-label ${addRole === r.value ? 'selected' : ''}`}
                      style={addRole === r.value ? { color: ROLE_COLORS[r.value as FamilyMemberRole] } : {}}
                    >
                      {r.label}
                    </Text>
                    {addRole === r.value && (
                      <Text className="role-select-check">✓</Text>
                    )}
                  </View>
                ))}
              </View>
            </View>
          </View>
        </View>
      )}

      {/* ─── Sheet: 添加照护对象 ─── */}
      {activeSheet === 'addRecipient' && (
        <View className="sheet-overlay" onClick={() => setActiveSheet(null)}>
          <View className="sheet-container" onClick={(e) => e.stopPropagation()}>
            <View className="sheet-handle" />
            <View className="sheet-header">
              <Text className="sheet-title">添加照护对象</Text>
              <View
                className={`sheet-confirm-btn ${submitting ? 'disabled' : ''}`}
                onClick={handleAddRecipient}
              >
                <Text className="sheet-confirm-text">{submitting ? '添加中...' : '添加'}</Text>
              </View>
            </View>

            <View className="sheet-body">
              <Text className="sheet-label">姓名 *</Text>
              <View className="sheet-input-wrap">
                <input
                  className="sheet-input"
                  placeholder="请输入照护对象姓名"
                  value={addRecipientName}
                  onInput={(e: any) => setAddRecipientName(e.detail.value)}
                  maxLength={50}
                />
              </View>

              <Text className="sheet-label">联系电话</Text>
              <View className="sheet-input-wrap">
                <input
                  className="sheet-input"
                  type="number"
                  placeholder="选填"
                  value={addRecipientPhone}
                  onInput={(e: any) => setAddRecipientPhone(e.detail.value)}
                  maxLength={11}
                />
              </View>

              <Text className="sheet-label">紧急联系电话</Text>
              <View className="sheet-input-wrap">
                <input
                  className="sheet-input"
                  type="number"
                  placeholder="选填，用于 SOS 场景"
                  value={addRecipientEmergency}
                  onInput={(e: any) => setAddRecipientEmergency(e.detail.value)}
                  maxLength={11}
                />
              </View>
            </View>
          </View>
        </View>
      )}

      {/* ─── Sheet: 成员管理 ─── */}
      {activeSheet === 'editMember' && selectedMember && (() => {
        const isOwnCard = selectedMember.userId === currentUserId;
        const canEdit = isOwnCard || showManageButtons;
        const canChangeRole = showManageButtons && !isOwnCard && selectedMember.role !== 'owner';
        const isElevated = isElevatedRole(selectedMember.role as FamilyMemberRole);
        const roleColor = ROLE_COLORS[selectedMember.role as string] ?? '#B0ADAD';

        return (
          <View className="sheet-overlay" onClick={() => { setActiveSheet(null); setSelectedMember(null); }}>
            <View className="sheet-container" onClick={(e) => e.stopPropagation()}>
              <View className="sheet-handle" />
              <View className="sheet-header">
                <Text className="sheet-title">{isOwnCard ? '编辑我的信息' : '编辑成员'}</Text>
                <View
                  className="sheet-close-btn"
                  onClick={() => { setActiveSheet(null); setSelectedMember(null); }}
                >
                  <Text className="sheet-close-text">关闭</Text>
                </View>
              </View>

              <View className="sheet-body">
                {/* 成员信息 */}
                <View className="edit-member-info">
                  <View className="member-avatar-wrap">
                    {selectedMember.avatarUrl ? (
                      <Image className="member-avatar-img" src={getImageUrl(selectedMember.avatarUrl || '')} mode="aspectFill" />
                    ) : (
                      <View className="member-avatar-placeholder">
                        <Text className="member-avatar-text">
                          {selectedMember.nickname ? selectedMember.nickname.slice(0, 1) : (selectedMember.phone ? selectedMember.phone.slice(-4) : '?')}
                        </Text>
                      </View>
                    )}
                  </View>
                  <View>
                    <Text className="edit-member-name">{selectedMember.nickname || '未命名'}</Text>
                    <View className="edit-member-role-row">
                      <View
                        className={`member-role-badge ${isElevated ? 'member-role-badge-elevated' : ''}`}
                        style={{ backgroundColor: `${roleColor}1A` }}
                      >
                        {isElevated && <Text className="member-role-star">★</Text>}
                        <Text className="member-role-text" style={{ color: roleColor }}>
                          {ROLE_LABELS[selectedMember.role as string] ?? selectedMember.role}
                        </Text>
                      </View>
                    </View>
                  </View>
                </View>

                {/* 昵称修改 */}
                {canEdit && (
                  <>
                    <Text className="sheet-label">家庭昵称</Text>
                    <View className="sheet-input-wrap">
                      <input
                        className="sheet-input"
                        placeholder="如 爸爸 大嫂"
                        value={editMemberNickname}
                        onInput={(e: any) => setEditMemberNickname(e.detail.value)}
                        maxLength={20}
                      />
                    </View>
                  </>
                )}

                {/* 角色变更 */}
                {canChangeRole && (
                  <>
                    <Text className="sheet-label">成员角色</Text>
                    <View className="role-select-list">
                      {SELECTABLE_ROLES.map((r) => (
                        <View
                          key={r.value}
                          className={`role-select-item ${editMemberRole === r.value ? 'selected' : ''}`}
                          onClick={() => setEditMemberRole(r.value)}
                        >
                          <View
                            className="role-select-dot"
                            style={{
                              backgroundColor: editMemberRole === r.value
                                ? ROLE_COLORS[r.value]
                                : '#E0E0E0',
                            }}
                          />
                          <Text
                            className={`role-select-label ${editMemberRole === r.value ? 'selected' : ''}`}
                            style={editMemberRole === r.value ? { color: ROLE_COLORS[r.value] } : {}}
                          >
                            {r.label}
                          </Text>
                          {editMemberRole === r.value && (
                            <Text className="role-select-check">✓</Text>
                          )}
                        </View>
                      ))}
                    </View>

                    {/* 角色说明 */}
                    {ROLE_DESCRIPTIONS[editMemberRole] && (
                      <View className="role-desc-box">
                        <Text className="role-desc-icon">ℹ</Text>
                        <Text className="role-desc-text">{ROLE_DESCRIPTIONS[editMemberRole]}</Text>
                      </View>
                    )}
                  </>
                )}

                {/* 保存按钮 */}
                {canEdit && (
                  <View
                    className={`cg-save-btn ${submitting ? 'disabled' : ''}`}
                    onClick={submitting ? undefined : handleSaveMember}
                  >
                    <Text className="cg-save-btn-text">{submitting ? '保存中...' : '保存'}</Text>
                  </View>
                )}

                {/* 移除按钮 */}
                {myRole === 'owner' && selectedMember.role !== 'owner' && !isOwnCard && (
                  <View
                    className="remove-member-btn"
                    onClick={() => handleRemoveMember(selectedMember.id)}
                  >
                    <Text className="remove-member-btn-text">
                      {submitting ? '移除中...' : '移除该成员'}
                    </Text>
                  </View>
                )}
              </View>
            </View>
          </View>
        );
      })()}

      {/* ─── Sheet: 编辑家庭 ─── */}
      {activeSheet === 'editFamily' && (
        <View className="sheet-overlay" onClick={() => setActiveSheet(null)}>
          <View className="sheet-container" onClick={(e) => e.stopPropagation()}>
            <View className="sheet-handle" />
            <View className="sheet-header">
              <Text className="sheet-title">编辑家庭</Text>
              <View
                className={`sheet-confirm-btn ${submitting ? 'disabled' : ''}`}
                onClick={handleUpdateFamilyName}
              >
                <Text className="sheet-confirm-text">{submitting ? '保存中...' : '保存'}</Text>
              </View>
            </View>

            <View className="sheet-body">
              <Text className="sheet-label">家庭名称</Text>
              <View className="sheet-input-wrap">
                <input
                  className="sheet-input"
                  placeholder="请输入家庭名称"
                  value={editFamilyName}
                  onInput={(e: any) => setEditFamilyName(e.detail.value)}
                  maxLength={50}
                />
              </View>
            </View>
          </View>
        </View>
      )}
    </View>
  );
}
