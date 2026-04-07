/**
 * 个人设置页
 * 对齐 Flutter profile_page.dart 布局
 * 用户卡片 / 账号设置 / 家庭管理 / 关于 / 退出登录
 */
import { View, Text, Image, Input, ScrollView } from '@tarojs/components';
import Taro, { useDidShow } from '@tarojs/taro';
import { useState, useEffect, useCallback } from 'react';
import { get, post, uploadFile } from '../../services/api';
import { Storage } from '../../services/storage';
import { getImageUrl } from '../../shared/utils/image';
import { store } from '../../store';
import { logout } from '../../services/auth.service';
import type { User } from '../../shared/models/user';
import type { Family } from '../../shared/models/family';
import './index.scss';

type SheetType = 'name' | 'password' | 'switchFamily' | 'joinFamily' | 'createFamily' | null;

interface ProfileState {
  user: User | null;
  loading: boolean;
  activeSheet: SheetType;
  families: Family[];
  selectedFamilyId: string | null;
  currentFamilyName: string;
}

export default function ProfilePage() {
  const [state, setState] = useState<ProfileState>({
    user: null,
    loading: true,
    activeSheet: null,
    families: [],
    selectedFamilyId: Storage.getCurrentFamilyId() || null,
    currentFamilyName: '我的家庭',
  });

  // Sheet 输入状态
  const [editName, setEditName] = useState('');
  const [oldPassword, setOldPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [inviteCode, setInviteCode] = useState('');
  const [newFamilyName, setNewFamilyName] = useState('');
  const [sheetLoading, setSheetLoading] = useState(false);
  const [nameError, setNameError] = useState('');
  const [passwordError, setPasswordError] = useState('');

  // 初始化：从 Redux store 读取用户
  useEffect(() => {
    const authUser = store.getState().auth.user;
    if (authUser) {
      setState((s) => ({ ...s, user: authUser, loading: false }));
    }
  }, []);

  // 每次页面显示时刷新用户数据
  useDidShow(() => {
    loadUser();
    loadFamilies();
  });

  const loadUser = useCallback(async () => {
    try {
      const user = await get<User>('/users/me');
      store.dispatch({ type: 'auth/setUser', payload: user });
      setState((s) => ({ ...s, user, loading: false }));
    } catch (err) {
      console.error('[profile] 加载用户失败:', err);
      setState((s) => ({ ...s, loading: false }));
    }
  }, []);

  const loadFamilies = useCallback(async () => {
    try {
      const res = await get<{ families: Family[] }>('/users/me/families');
      const families = res?.families ?? [];
      const currentFamilyId = Storage.getCurrentFamilyId();
      const currentFamily = families.find((f) => f.id === currentFamilyId);
      setState((s) => ({
        ...s,
        families: families || [],
        selectedFamilyId: currentFamilyId,
        currentFamilyName: currentFamily?.name || '我的家庭',
      }));
    } catch (err) {
      console.error('[profile] 加载家庭失败:', err);
    }
  }, []);

  // ─── 头像上传 ──────────────────────────────────────────────────────────────

  const handleAvatarClick = async () => {
    try {
      const res = await Taro.chooseImage({
        count: 1,
        sizeType: ['compressed'],
        sourceType: ['album', 'camera'],
      });

      const tempFilePath = res.tempFilePaths[0];

      Taro.showLoading({ title: '上传中...' });
      const uploadRes = await uploadFile('/upload/avatar', tempFilePath, 'file');
      Taro.hideLoading();
      const avatarUrl = uploadRes?.avatarUrl || uploadRes?.data?.avatarUrl || '';
      if (avatarUrl) {
        setState((s) => ({
          ...s,
          user: s.user ? { ...s.user, avatar: avatarUrl } : null,
        }));
        store.dispatch({ type: 'auth/setUser', payload: { ...store.getState().auth.user, avatar: avatarUrl } });
        Taro.showToast({ title: '头像已更新', icon: 'success', duration: 1500 });
      } else {
        Taro.showToast({ title: '上传失败', icon: 'none', duration: 2000 });
      }
    } catch (err: any) {
      Taro.hideLoading();
      console.error('[profile] 头像上传失败:', err);
      Taro.showToast({ title: err?.message || '上传失败', icon: 'none', duration: 2000 });
    }
  };

  // ─── 编辑昵称 ──────────────────────────────────────────────────────────────

  const openNameSheet = () => {
    setEditName(state.user?.name || '');
    setNameError('');
    setState((s) => ({ ...s, activeSheet: 'name' }));
  };

  const handleSaveName = async () => {
    const name = editName.trim();
    if (!name) {
      setNameError('昵称不能为空');
      return;
    }
    if (name.length > 20) {
      setNameError('昵称不能超过20个字符');
      return;
    }
    setSheetLoading(true);
    try {
      await put<User>('/users/me', { name });
      const updatedUser = { ...(state.user || {}), name };
      store.dispatch({ type: 'auth/setUser', payload: updatedUser });
      setState((s) => ({ ...s, user: updatedUser, activeSheet: null }));
      Taro.showToast({ title: '昵称已更新', icon: 'success', duration: 1500 });
    } catch (err: any) {
      setNameError(err.message || '更新失败');
    } finally {
      setSheetLoading(false);
    }
  };

  // ─── 修改密码 ──────────────────────────────────────────────────────────────

  const openPasswordSheet = () => {
    setOldPassword('');
    setNewPassword('');
    setConfirmPassword('');
    setPasswordError('');
    setState((s) => ({ ...s, activeSheet: 'password' }));
  };

  const handleChangePassword = async () => {
    const hasPassword = state.user?.hasPassword;

    if (hasPassword && !oldPassword) {
      setPasswordError('请输入旧密码');
      return;
    }
    if (!newPassword) {
      setPasswordError('请输入新密码');
      return;
    }
    if (newPassword.length < 6) {
      setPasswordError('新密码至少6位');
      return;
    }
    if (newPassword !== confirmPassword) {
      setPasswordError('两次密码不一致');
      return;
    }

    setSheetLoading(true);
    try {
      const payload: { oldPassword?: string; newPassword: string } = { newPassword };
      if (hasPassword) {
        payload.oldPassword = oldPassword;
      }
      await post('/auth/change-password', payload);
      setState((s) => ({ ...s, activeSheet: null }));
      Taro.showToast({ title: '密码已更新', icon: 'success', duration: 1500 });
    } catch (err: any) {
      setPasswordError(err.message || '操作失败');
    } finally {
      setSheetLoading(false);
    }
  };

  // ─── 切换家庭 ──────────────────────────────────────────────────────────────

  const openSwitchFamilySheet = () => {
    setState((s) => ({ ...s, activeSheet: 'switchFamily' }));
  };

  const handleSelectFamily = (familyId: string) => {
    setState((s) => ({ ...s, selectedFamilyId: familyId }));
  };

  const handleConfirmSwitchFamily = () => {
    if (!state.selectedFamilyId) {
      Taro.showToast({ title: '请选择家庭', icon: 'none' });
      return;
    }
    const family = state.families.find((f) => f.id === state.selectedFamilyId);
    Storage.setCurrentFamilyId(state.selectedFamilyId);
    setState((s) => ({
      ...s,
      activeSheet: null,
      currentFamilyName: family?.name || '我的家庭',
    }));
    Taro.showToast({ title: `已切换至「${family?.name}」`, icon: 'success', duration: 1500 });
  };

  // ─── 加入新家庭 ────────────────────────────────────────────────────────────

  const openJoinFamilySheet = () => {
    setInviteCode('');
    setState((s) => ({ ...s, activeSheet: 'joinFamily' }));
  };

  const handleJoinFamily = async () => {
    const code = inviteCode.trim();
    if (!code) {
      Taro.showToast({ title: '请输入邀请码', icon: 'none' });
      return;
    }
    setSheetLoading(true);
    try {
      await post<{ id: string }>('/families/join', { inviteCode: code });
      await loadFamilies();
      setState((s) => ({ ...s, activeSheet: null }));
      Taro.showToast({ title: '加入成功', icon: 'success', duration: 1500 });
    } catch (err: any) {
      Taro.showToast({ title: err.message || '邀请码无效', icon: 'none', duration: 2000 });
    } finally {
      setSheetLoading(false);
    }
  };

  // ─── 创建新家庭 ────────────────────────────────────────────────────────────

  const openCreateFamilySheet = () => {
    setNewFamilyName('');
    setState((s) => ({ ...s, activeSheet: 'createFamily' }));
  };

  const handleCreateFamily = async () => {
    const name = newFamilyName.trim();
    if (!name) {
      Taro.showToast({ title: '请输入家庭名称', icon: 'none' });
      return;
    }
    if (name.length > 20) {
      Taro.showToast({ title: '家庭名称不能超过20字符', icon: 'none' });
      return;
    }
    setSheetLoading(true);
    try {
      await post<{ id: string }>('/families', { name });
      await loadFamilies();
      setState((s) => ({ ...s, activeSheet: null }));
      Taro.showToast({ title: '家庭创建成功', icon: 'success', duration: 1500 });
    } catch (err: any) {
      Taro.showToast({ title: err.message || '创建失败', icon: 'none', duration: 2000 });
    } finally {
      setSheetLoading(false);
    }
  };

  // ─── 关于链接（复制到剪贴板） ──────────────────────────────────────────────

  const handleCopyLink = (title: string, url: string) => {
    Taro.setClipboardData({
      data: url,
      success: () => {
        Taro.showToast({ title: `${title}链接已复制，请在浏览器打开`, icon: 'none', duration: 2500 });
      },
    });
  };

  // ─── 退出登录 ──────────────────────────────────────────────────────────────

  const handleLogout = () => {
    Taro.showModal({
      title: '退出登录',
      content: '确定要退出当前账号吗？',
      confirmColor: '#E07B5D',
      success: (res) => {
        if (res.confirm) {
          logout();
        }
      },
    });
  };

  // ─── 关闭 Sheet ────────────────────────────────────────────────────────────

  const closeSheet = () => {
    setState((s) => ({ ...s, activeSheet: null }));
  };

  // ─── 辅助函数 ──────────────────────────────────────────────────────────────

  /** 手机号脱敏 */
  const maskPhone = (phone: string | null): string => {
    if (!phone || phone.length < 11) return '';
    return phone.replace(/(\d{3})\d{4}(\d{4})/, '$1****$2');
  };

  /** 获取首字用于无头像时的展示 */
  const getInitial = (): string => {
    const name = state.user?.name;
    if (name) return name.slice(0, 1).toUpperCase();
    const phone = state.user?.phone;
    if (phone) return phone.slice(0, 1);
    return '我';
  };

  /** 渲染用户头像 */
  const renderAvatar = () => {
    if (state.user?.avatar) {
      return (
        <Image
          className="avatar-img"
          src={getImageUrl(state.user.avatar || '')}
          mode="aspectFill"
        />
      );
    }
    return (
      <View className="avatar-placeholder">
        <Text className="avatar-initial">{getInitial()}</Text>
      </View>
    );
  };

  const { user, loading, activeSheet, families, selectedFamilyId, currentFamilyName } = state;

  // ─── 渲染主体 ──────────────────────────────────────────────────────────────

  return (
    <View className="profile-page">
      <ScrollView className="profile-scroll" scrollY>
        {/* ── 用户卡片 ─────────────────────────────────────────────── */}
        <View className="user-card">
          <View className="avatar-wrap" onClick={handleAvatarClick}>
            {renderAvatar()}
            <View className="avatar-edit-badge">
              <Text className="avatar-edit-icon">✎</Text>
            </View>
          </View>

          <View className="user-info">
            <View className="user-name-row" onClick={openNameSheet}>
              <Text className="user-name">{user?.name || '点击设置昵称'}</Text>
              <Text className="user-name-edit-hint">✎</Text>
            </View>
            <Text className="user-phone">{maskPhone(user?.phone || null)}</Text>
          </View>

          <View className="avatar-hint" onClick={handleAvatarClick}>
            <Text className="avatar-hint-text">编辑头像</Text>
          </View>
        </View>

        {/* ── 账号设置区块 ────────────────────────────────────────── */}
        <View className="section-title">账号设置</View>
        <View className="section-card">

          {/* 通知设置 */}
          <View
            className="setting-item"
            onClick={() => Taro.navigateTo({ url: '/pages/notification/index' })}
          >
            <View className="setting-left">
              <Image className="setting-icon" src={require('../../assets/icons/bell.png')} />
              <Text className="setting-label">通知设置</Text>
            </View>
            <View className="setting-right">
              <Text className="setting-chevron">›</Text>
            </View>
          </View>

          <View className="setting-divider" />

          {/* 修改密码 */}
          <View className="setting-item" onClick={openPasswordSheet}>
            <View className="setting-left">
              <Image className="setting-icon" src={require('../../assets/icons/key.png')} />
              <Text className="setting-label">{user?.hasPassword ? '修改密码' : '设置密码'}</Text>
            </View>
            <View className="setting-right">
              <Text className="setting-chevron">›</Text>
            </View>
          </View>
        </View>

        {/* ── 家庭区块 ────────────────────────────────────────────── */}
        <View className="section-title">家庭管理</View>
        <View className="section-card">

          {/* 切换家庭 */}
          <View className="setting-item" onClick={openSwitchFamilySheet}>
            <View className="setting-left">
              <Image className="setting-icon" src={require('../../assets/icons/swap.png')} />
              <View className="setting-text-wrap">
                <Text className="setting-label">切换家庭</Text>
                <Text className="setting-sublabel">{currentFamilyName}</Text>
              </View>
            </View>
            <View className="setting-right">
              <Text className="setting-chevron">›</Text>
            </View>
          </View>

          <View className="setting-divider" />

          {/* 加入新家庭 */}
          <View className="setting-item" onClick={openJoinFamilySheet}>
            <View className="setting-left">
              <Image className="setting-icon" src={require('../../assets/icons/person-plus.png')} />
              <Text className="setting-label">加入新家庭</Text>
            </View>
            <View className="setting-right">
              <Text className="setting-chevron">›</Text>
            </View>
          </View>

          <View className="setting-divider" />

          {/* 创建新家庭 */}
          <View className="setting-item" onClick={openCreateFamilySheet}>
            <View className="setting-left">
              <Image className="setting-icon" src={require('../../assets/icons/home-plus.png')} />
              <Text className="setting-label">创建新家庭</Text>
            </View>
            <View className="setting-right">
              <Text className="setting-chevron">›</Text>
            </View>
          </View>
        </View>

        {/* ── 关于区块 ────────────────────────────────────────────── */}
        <View className="section-title">关于</View>
        <View className="section-card">

          {/* 关于我们 */}
          <View
            className="setting-item"
            onClick={() => handleCopyLink('关于我们', 'http://8.163.69.199/')}
          >
            <View className="setting-left">
              <Image className="setting-icon" src={require('../../assets/icons/info.png')} />
              <Text className="setting-label">关于我们</Text>
            </View>
            <View className="setting-right">
              <Text className="setting-chevron">›</Text>
            </View>
          </View>

          <View className="setting-divider" />

          {/* 隐私政策 */}
          <View
            className="setting-item"
            onClick={() => handleCopyLink('隐私政策', 'http://8.163.69.199/privacy')}
          >
            <View className="setting-left">
              <Image className="setting-icon" src={require('../../assets/icons/doc.png')} />
              <Text className="setting-label">隐私政策</Text>
            </View>
            <View className="setting-right">
              <Text className="setting-chevron">›</Text>
            </View>
          </View>

          <View className="setting-divider" />

          {/* 用户协议 */}
          <View
            className="setting-item"
            onClick={() => handleCopyLink('用户协议', 'http://8.163.69.199/terms')}
          >
            <View className="setting-left">
              <Image className="setting-icon" src={require('../../assets/icons/doc.png')} />
              <Text className="setting-label">用户协议</Text>
            </View>
            <View className="setting-right">
              <Text className="setting-chevron">›</Text>
            </View>
          </View>
        </View>

        {/* 底部留白（给退出按钮和安全区域） */}
        <View className="bottom-pad" />
      </ScrollView>

      {/* ── 退出登录按钮 ─────────────────────────────────────────── */}
      <View className="logout-bar">
        <View className="logout-btn" onClick={handleLogout}>
          <Text className="logout-text">退出登录</Text>
        </View>
      </View>

      {/* ── 底部 Sheet 遮罩层 ─────────────────────────────────────── */}
      {activeSheet !== null && (
        <View className="sheet-overlay" onClick={closeSheet}>
          <View className="sheet-container" onClick={(e) => e.stopPropagation()}>

            {/* 昵称编辑 Sheet */}
            {activeSheet === 'name' && (
              <View className="sheet-content">
                <View className="sheet-header">
                  <Text className="sheet-title">修改昵称</Text>
                </View>
                <View className="sheet-body">
                  <View className="field-row">
                    <Input
                      className={`sheet-input ${nameError ? 'sheet-input-error' : ''}`}
                      placeholder="请输入昵称"
                      placeholder-class="sheet-placeholder"
                      value={editName}
                      maxLength={20}
                      onInput={(e) => { setEditName(e.detail.value); setNameError(''); }}
                    />
                  </View>
                  {nameError && <Text className="sheet-error">{nameError}</Text>}
                  <View className="sheet-actions">
                    <View className="sheet-btn-cancel" onClick={closeSheet}>
                      <Text className="sheet-btn-cancel-text">取消</Text>
                    </View>
                    <View
                      className={`sheet-btn-confirm ${sheetLoading ? 'sheet-btn-disabled' : ''}`}
                      onClick={handleSaveName}
                    >
                      <Text className="sheet-btn-confirm-text">{sheetLoading ? '保存中...' : '确定'}</Text>
                    </View>
                  </View>
                </View>
              </View>
            )}

            {/* 修改密码 Sheet */}
            {activeSheet === 'password' && (
              <View className="sheet-content">
                <View className="sheet-header">
                  <Text className="sheet-title">{user?.hasPassword ? '修改密码' : '设置密码'}</Text>
                </View>
                <View className="sheet-body">
                  {user?.hasPassword && (
                    <View className="field-row">
                      <Input
                        className="sheet-input"
                        password
                        placeholder="请输入旧密码"
                        placeholder-class="sheet-placeholder"
                        value={oldPassword}
                        onInput={(e) => setOldPassword(e.detail.value)}
                      />
                    </View>
                  )}
                  <View className="field-row">
                    <Input
                      className="sheet-input"
                      password
                      placeholder="请输入新密码（至少6位）"
                      placeholder-class="sheet-placeholder"
                      value={newPassword}
                      onInput={(e) => setNewPassword(e.detail.value)}
                    />
                  </View>
                  <View className="field-row">
                    <Input
                      className="sheet-input"
                      password
                      placeholder="请再次输入新密码"
                      placeholder-class="sheet-placeholder"
                      value={confirmPassword}
                      onInput={(e) => setConfirmPassword(e.detail.value)}
                    />
                  </View>
                  {passwordError && <Text className="sheet-error">{passwordError}</Text>}
                  <View className="sheet-actions">
                    <View className="sheet-btn-cancel" onClick={closeSheet}>
                      <Text className="sheet-btn-cancel-text">取消</Text>
                    </View>
                    <View
                      className={`sheet-btn-confirm ${sheetLoading ? 'sheet-btn-disabled' : ''}`}
                      onClick={handleChangePassword}
                    >
                      <Text className="sheet-btn-confirm-text">{sheetLoading ? '保存中...' : '确定'}</Text>
                    </View>
                  </View>
                </View>
              </View>
            )}

            {/* 切换家庭 Sheet */}
            {activeSheet === 'switchFamily' && (
              <View className="sheet-content">
                <View className="sheet-header">
                  <Text className="sheet-title">切换家庭</Text>
                </View>
                <View className="sheet-body">
                  {families.map((family) => (
                    <View
                      key={family.id}
                      className={`family-option ${selectedFamilyId === family.id ? 'family-option-selected' : ''}`}
                      onClick={() => handleSelectFamily(family.id)}
                    >
                      <View className="family-option-left">
                        <Text className="family-option-name">{family.name}</Text>
                        <Text className="family-option-count">{family.memberCount}位成员</Text>
                      </View>
                      <View className="family-option-check">
                        {selectedFamilyId === family.id && (
                          <Text className="family-option-check-text">✓</Text>
                        )}
                      </View>
                    </View>
                  ))}
                  {families.length === 0 && (
                    <View className="sheet-empty">
                      <Text className="sheet-empty-text">暂无可用家庭</Text>
                    </View>
                  )}
                  <View className="sheet-actions">
                    <View className="sheet-btn-cancel" onClick={closeSheet}>
                      <Text className="sheet-btn-cancel-text">取消</Text>
                    </View>
                    <View className="sheet-btn-confirm" onClick={handleConfirmSwitchFamily}>
                      <Text className="sheet-btn-confirm-text">确认切换</Text>
                    </View>
                  </View>
                </View>
              </View>
            )}

            {/* 加入新家庭 Sheet */}
            {activeSheet === 'joinFamily' && (
              <View className="sheet-content">
                <View className="sheet-header">
                  <Text className="sheet-title">加入新家庭</Text>
                </View>
                <View className="sheet-body">
                  <View className="field-row">
                    <Input
                      className="sheet-input"
                      placeholder="请输入邀请码"
                      placeholder-class="sheet-placeholder"
                      value={inviteCode}
                      onInput={(e) => setInviteCode(e.detail.value)}
                    />
                  </View>
                  <View className="sheet-actions">
                    <View className="sheet-btn-cancel" onClick={closeSheet}>
                      <Text className="sheet-btn-cancel-text">取消</Text>
                    </View>
                    <View
                      className={`sheet-btn-confirm ${sheetLoading ? 'sheet-btn-disabled' : ''}`}
                      onClick={handleJoinFamily}
                    >
                      <Text className="sheet-btn-confirm-text">{sheetLoading ? '加入中...' : '确认加入'}</Text>
                    </View>
                  </View>
                </View>
              </View>
            )}

            {/* 创建新家庭 Sheet */}
            {activeSheet === 'createFamily' && (
              <View className="sheet-content">
                <View className="sheet-header">
                  <Text className="sheet-title">创建新家庭</Text>
                </View>
                <View className="sheet-body">
                  <View className="field-row">
                    <Input
                      className="sheet-input"
                      placeholder="请输入家庭名称"
                      placeholder-class="sheet-placeholder"
                      value={newFamilyName}
                      maxLength={20}
                      onInput={(e) => setNewFamilyName(e.detail.value)}
                    />
                  </View>
                  <View className="sheet-actions">
                    <View className="sheet-btn-cancel" onClick={closeSheet}>
                      <Text className="sheet-btn-cancel-text">取消</Text>
                    </View>
                    <View
                      className={`sheet-btn-confirm ${sheetLoading ? 'sheet-btn-disabled' : ''}`}
                      onClick={handleCreateFamily}
                    >
                      <Text className="sheet-btn-confirm-text">{sheetLoading ? '创建中...' : '确认创建'}</Text>
                    </View>
                  </View>
                </View>
              </View>
            )}

          </View>
        </View>
      )}
    </View>
  );
}
