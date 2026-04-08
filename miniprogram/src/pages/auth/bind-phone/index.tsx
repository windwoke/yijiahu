/**
 * 绑定手机号页
 * 通过手机号+短信验证码绑定微信账号
 * 绑定后可与 App 端账号互通
 */
import { useState } from 'react';
import { View, Text, Image, Input } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { post } from '../../../services/api';
import { store } from '../../../store';
import { isValidPhone } from '../../../shared/utils/phone';
import './index.scss';

export default function BindPhonePage() {
  const [phone, setPhone] = useState('');
  const [code, setCode] = useState('');
  const [countdown, setCountdown] = useState(0);
  const [loading, setLoading] = useState(false);
  const [phoneError, setPhoneError] = useState('');
  const [codeError, setCodeError] = useState('');

  const handleSendCode = async () => {
    if (!isValidPhone(phone)) {
      setPhoneError('请输入正确的手机号');
      return;
    }
    setPhoneError('');
    try {
      const res = await post<{ mockCode?: string }>('/auth/send-code', { phone });
      Taro.showToast({
        title: res?.mockCode ? `测试验证码：${res.mockCode}` : '验证码已发送',
        icon: 'none',
        duration: 3000,
      });
      setCountdown(60);
      const timer = setInterval(() => {
        setCountdown((c) => {
          if (c <= 1) { clearInterval(timer); return 0; }
          return c - 1;
        });
      }, 1000);
    } catch (err: any) {
      Taro.showToast({ title: err?.message || '发送失败', icon: 'none' });
    }
  };

  const handleBind = async () => {
    if (!isValidPhone(phone)) {
      setPhoneError('请输入正确的手机号');
      return;
    }
    if (code.length !== 6) {
      setCodeError('请输入6位验证码');
      return;
    }
    setPhoneError('');
    setCodeError('');
    setLoading(true);
    try {
      const result = await post<{ success: boolean; phone: string }>('/auth/bind-phone', {
        phone,
        code,
      });

      if (result.success) {
        Taro.showToast({ title: '绑定成功', icon: 'success', duration: 1500 });

        // 更新 Redux 中的用户信息
        const currentUser = store.getState().auth.user;
        if (currentUser) {
          store.dispatch({
            type: 'auth/setUser',
            payload: { ...currentUser, phone: result.phone, isBound: true },
          });
        }

        setTimeout(() => {
          Taro.switchTab({ url: '/pages/home/index' });
        }, 1500);
      }
    } catch (err: any) {
      console.error('[bind-phone] 绑定失败:', err);
      Taro.showToast({ title: err?.message || '绑定失败', icon: 'none', duration: 2500 });
    } finally {
      setLoading(false);
    }
  };

  return (
    <View className="bp-page">
      {/* 顶部装饰 */}
      <View className="bp-header">
        <View className="bp-icon-wrap">
          <Image className="bp-icon" src={require('../../../assets/icons/phone.png')} />
        </View>
        <Text className="bp-title">绑定手机号</Text>
        <Text className="bp-subtitle">绑定后可在 App 端使用同一账号登录</Text>
      </View>

      {/* 表单 */}
      <View className="bp-form">
        <View className="bp-field-row">
          <Image className="bp-field-icon" src={require('../../../assets/icons/phone.png')} />
          <Input
            className={`bp-input ${phoneError ? 'bp-input-error' : ''}`}
            type="number"
            maxLength={11}
            placeholder="请输入手机号"
            placeholder-class="bp-placeholder"
            value={phone}
            onInput={(e) => { setPhone(e.detail.value); setPhoneError(''); }}
          />
        </View>
        {phoneError && <Text className="bp-error">{phoneError}</Text>}

        <View className="bp-field-row">
          <Image className="bp-field-icon" src={require('../../../assets/icons/key.png')} />
          <Input
            className={`bp-input bp-input-code ${codeError ? 'bp-input-error' : ''}`}
            type="number"
            maxLength={6}
            placeholder="请输入验证码"
            placeholder-class="bp-placeholder"
            value={code}
            onInput={(e) => { setCode(e.detail.value); setCodeError(''); }}
          />
          <View
            className={`bp-code-btn ${countdown > 0 || !isValidPhone(phone) ? 'bp-code-btn-disabled' : ''}`}
            onClick={handleSendCode}
          >
            <Text className="bp-code-btn-text">{countdown > 0 ? `${countdown}s` : '获取验证码'}</Text>
          </View>
        </View>
        {codeError && <Text className="bp-error">{codeError}</Text>}

        <View
          className={`bp-submit-btn ${loading ? 'bp-submit-disabled' : ''}`}
          onClick={handleBind}
        >
          <Text className="bp-submit-text">{loading ? '绑定中...' : '确认绑定'}</Text>
        </View>

        <View className="bp-skip" onClick={() => Taro.switchTab({ url: '/pages/home/index' })}>
          <Text className="bp-skip-text">暂不绑定</Text>
        </View>
      </View>

      {/* 底部声明 */}
      <View className="bp-footer">
        <Text className="bp-footer-text">绑定即表示同意《用户协议》和《隐私政策》</Text>
      </View>
    </View>
  );
}
