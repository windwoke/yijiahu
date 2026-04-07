/**
 * 家庭引导页
 * 首次登录后无家庭时，必须先创建或加入家庭才能进入首页
 * 样式对齐 Flutter family_onboarding.dart
 */
import { View, Text, Input, Image } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { useState, useEffect } from 'react';
import { get, post } from '../../../services/api';
import { Storage } from '../../../services/storage';
import type { Family } from '../../../shared/models/family';
import './index.scss';

type OnboardingMode = 'loading' | 'main' | 'join';

export default function OnboardingPage() {
  const [mode, setMode] = useState<OnboardingMode>('loading');
  const [familyName, setFamilyName] = useState('');
  const [inviteCode, setInviteCode] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [showCreateSheet, setShowCreateSheet] = useState(false);

  useEffect(() => {
    checkFamilies();
  }, []);

  const checkFamilies = async () => {
    try {
      const res = await get<{ families: Family[] }>('/users/me/families');
      const families = res?.families ?? [];
      if (families && families.length > 0) {
        Storage.setCurrentFamilyId(families[0].id);
        Taro.switchTab({ url: '/pages/home/index' });
      } else {
        setMode('main');
      }
    } catch {
      setMode('main');
    }
  };

  const handleCreateFamily = async () => {
    const name = familyName.trim();
    if (!name) {
      setError('请输入家庭名称');
      return;
    }
    if (name.length < 2) {
      setError('家庭名称至少2个字');
      return;
    }
    if (name.length > 20) {
      setError('家庭名称不能超过20个字符');
      return;
    }
    setLoading(true);
    setError('');
    try {
      const res = await post<{ id: string }>('/families', { name });
      Storage.setCurrentFamilyId(res.id);
      Taro.showToast({ title: '创建成功', icon: 'success', duration: 1500 });
      setTimeout(() => Taro.switchTab({ url: '/pages/home/index' }), 1500);
    } catch (err: any) {
      setError(err.message || '创建失败');
      setLoading(false);
    }
  };

  const handleJoinFamily = async () => {
    const code = inviteCode.trim();
    if (!code) {
      setError('请输入邀请码');
      return;
    }
    setLoading(true);
    setError('');
    try {
      await post('/families/join', { inviteCode: code });
      const res = await get<{ families: Family[] }>('/users/me/families');
      const families = res?.families ?? [];
      if (families && families.length > 0) {
        Storage.setCurrentFamilyId(families[0].id);
      }
      Taro.showToast({ title: '加入成功', icon: 'success', duration: 1500 });
      setTimeout(() => Taro.switchTab({ url: '/pages/home/index' }), 1500);
    } catch (err: any) {
      setError(err.message || '邀请码无效');
      setLoading(false);
    }
  };

  // ─── 主视图 ──────────────────────────────────────────────────────────────
  const renderMain = () => (
    <>
      {/* 图标 */}
      <View className="onboard-icon-wrap">
        <Text className="onboard-icon">👨‍👩‍👧‍👦</Text>
      </View>

      {/* 标题 */}
      <Text className="onboard-title">欢迎使用一家护</Text>
      <Text className="onboard-subtitle">创建或加入一个家庭，开始使用</Text>

      {/* 一行两按钮 */}
      <View className="onboard-actions">
        {/* 创建新家庭 */}
        <View
          className="onboard-action-btn onboard-action-create"
          onClick={() => setShowCreateSheet(true)}
        >
          <Text className="onboard-action-emoji">🏠</Text>
          <Text className="onboard-action-label">创建新家庭</Text>
        </View>

        {/* 输入邀请码加入 */}
        <View
          className="onboard-action-btn onboard-action-join"
          onClick={() => setMode('join')}
        >
          <Text className="onboard-action-emoji">🔗</Text>
          <Text className="onboard-action-label">输入邀请码加入</Text>
        </View>
      </View>
    </>
  );

  // ─── 加入视图 ────────────────────────────────────────────────────────────
  const renderJoin = () => (
    <>
      <Text className="onboard-title">输入家庭邀请码</Text>

      <Input
        className={`onboard-input ${error ? 'onboard-input-error' : ''}`}
        placeholder="请输入 8 位邀请码"
        placeholder-class="onboard-placeholder"
        value={inviteCode}
        onInput={(e) => { setInviteCode(e.detail.value); setError(''); }}
      />
      {error && <Text className="onboard-error">{error}</Text>}

      <View className="onboard-join-actions">
        <View className="onboard-btn-cancel" onClick={() => setMode('main')}>
          <Text className="onboard-btn-cancel-text">返回</Text>
        </View>
        <View
          className={`onboard-btn-confirm ${loading ? 'onboard-btn-disabled' : ''}`}
          onClick={loading ? undefined : handleJoinFamily}
        >
          <Text className="onboard-btn-confirm-text">
            {loading ? '加入中...' : '确认加入'}
          </Text>
        </View>
      </View>
    </>
  );

  return (
    <View className="onboarding-page">
      {/* 遮罩背景 */}
      <View className="onboard-overlay">
        {/* 居中卡片 */}
        <View className="onboard-card">
          {mode === 'loading' ? (
            <Text className="onboard-loading-text">正在检查...</Text>
          ) : mode === 'main' ? renderMain() : renderJoin()}
        </View>
      </View>

      {/* 创建家庭底部 Sheet */}
      {showCreateSheet && (
        <View className="create-sheet-overlay" onClick={() => setShowCreateSheet(false)}>
          <View className="create-sheet" onClick={(e) => e.stopPropagation()}>
            <View className="create-sheet-handle" />
            <Text className="create-sheet-title">创建新家庭</Text>
            <Text className="create-sheet-subtitle">为你的家庭起个名字</Text>
            <Input
              className={`create-sheet-input ${error ? 'create-sheet-input-error' : ''}`}
              placeholder="例如：老张家、老王家"
              placeholder-class="create-sheet-placeholder"
              value={familyName}
              maxLength={20}
              onInput={(e) => { setFamilyName(e.detail.value); setError(''); }}
            />
            {error && <Text className="create-sheet-error">{error}</Text>}
            <View
              className={`create-sheet-btn ${loading ? 'create-sheet-btn-disabled' : ''}`}
              onClick={loading ? undefined : handleCreateFamily}
            >
              <Text className="create-sheet-btn-text">
                {loading ? '创建中...' : '创建'}
              </Text>
            </View>
            <Text className="create-sheet-cancel" onClick={() => setShowCreateSheet(false)}>
              取消
            </Text>
          </View>
        </View>
      )}
    </View>
  );
}
