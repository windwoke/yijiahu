import { useState } from 'react';
import { View, Text, Input, Button, Image } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { wechatLogin, phoneLogin, sendCode } from '../../../services/auth.service';
import { isValidPhone } from '../../../shared/utils/phone';
import './index.scss';

/** 登录页
 * 与 Flutter login_page.dart 风格对齐
 * 默认微信登录，可切换到手机号登录
 */

// PNG 图标（对应 Flutter prefixIcon）
const PhoneIcon = () => (
  <Image className="field-icon-img" src={require('../../../assets/icons/phone.png')} />
);

const KeyIcon = () => (
  <Image className="field-icon-img" src={require('../../../assets/icons/key.png')} />
);

export default function LoginPage() {
  const [mode, setMode] = useState<'wechat' | 'phone'>('wechat');
  const [phone, setPhone] = useState('');
  const [code, setCode] = useState('');
  const [countdown, setCountdown] = useState(0);
  const [loading, setLoading] = useState(false);
  const [phoneError, setPhoneError] = useState('');
  const [codeError, setCodeError] = useState('');

  const handleWechatLogin = async () => {
    if (loading) return; // 防止重复点击
    setLoading(true);
    try {
      await wechatLogin();
    } catch (err: any) {
      console.error('[login] 微信登录失败:', err);
      Taro.showToast({ title: err.message || '登录失败', icon: 'none' });
    } finally {
      setLoading(false);
    }
  };

  const handleSendCode = async () => {
    if (!isValidPhone(phone)) {
      setPhoneError('请输入正确的手机号');
      return;
    }
    setPhoneError('');
    try {
      const res = await sendCode(phone);
      if (res.mockCode) {
        // 开发/测试模式：直接显示虚拟验证码
        Taro.showModal({
          title: '测试验证码',
          content: `验证码：${res.mockCode}`,
          showCancel: false,
        });
      } else {
        Taro.showToast({ title: '验证码已发送', icon: 'success' });
      }
      setCountdown(60);
      const timer = setInterval(() => {
        setCountdown((c) => {
          if (c <= 1) { clearInterval(timer); return 0; }
          return c - 1;
        });
      }, 1000);
    } catch (err: any) {
      Taro.showToast({ title: err.message || '发送失败', icon: 'none' });
    }
  };

  const handlePhoneLogin = async () => {
    if (!isValidPhone(phone)) {
      setPhoneError('请输入正确的手机号');
      return;
    }
    if (code.length !== 6) {
      setCodeError('请输入6位验证码');
      return;
    }
    setLoading(true);
    try {
      await phoneLogin(phone, code);
    } catch (err: any) {
      console.error('[login] 手机号登录失败:', err);
      Taro.showToast({ title: err.message || '登录失败', icon: 'none' });
    } finally {
      setLoading(false);
    }
  };

  return (
    <View className="login-page">
      {/* 背景 */}
      <View className="bg-gradient" />
      <View className="bg-circle-top" />
      <View className="bg-circle-bottom" />

      <View className="login-content">
        {/* Logo 区域 */}
        <View className="logo-area">
          <View className="logo-icon-wrap">
            <Image className="logo-heart" src={require('../../../assets/icons/heart-white.png')} />
          </View>
          <Text className="logo-name">一家护</Text>
          <Text className="logo-slogan">家庭照护，从容有爱</Text>
        </View>

        {/* 微信登录面板（默认展示） */}
        {mode === 'wechat' && (
          <View className="panel">
            <Button
              className="btn-wechat-primary"
              onClick={handleWechatLogin}
              disabled={loading}
            >
              <Text className="btn-wechat-text">微信一键登录</Text>
            </Button>

            <Button
              className="btn-ghost"
              onClick={() => setMode('phone')}
            >
              使用手机号登录
            </Button>
          </View>
        )}

        {/* 手机号登录面板 */}
        {mode === 'phone' && (
          <View className="panel">
            <View className="field-row">
              <PhoneIcon />
              <Input
                className={`field-input ${phoneError ? 'field-error' : ''}`}
                type="number"
                maxLength={11}
                placeholder="请输入手机号"
                placeholder-class="field-placeholder"
                value={phone}
                onInput={(e) => { setPhone(e.detail.value); setPhoneError(''); }}
              />
            </View>
            {phoneError && <Text className="field-error-msg">{phoneError}</Text>}

            <View className="code-row">
              <View className="field-row code-field">
                <KeyIcon />
                <Input
                  className={`field-input ${codeError ? 'field-error' : ''}`}
                  type="number"
                  maxLength={6}
                  placeholder="请输入验证码"
                  placeholder-class="field-placeholder"
                  value={code}
                  onInput={(e) => { setCode(e.detail.value); setCodeError(''); }}
                />
              </View>
              <Button
                className={`btn-code ${countdown > 0 ? 'btn-code-disabled' : ''}`}
                onClick={handleSendCode}
                disabled={countdown > 0 || !isValidPhone(phone)}
              >
                <Text style={{ color: countdown > 0 ? '#2C2C2C' : '#FFFFFF', fontSize: '26rpx', fontWeight: '500' }}>
                  {countdown > 0 ? `${countdown}s` : '获取验证码'}
                </Text>
              </Button>
            </View>
            {codeError && <Text className="field-error-msg">{codeError}</Text>}

            <Button
              className={`btn-primary ${loading ? 'btn-disabled' : ''}`}
              onClick={handlePhoneLogin}
              disabled={loading}
            >
              {loading ? '登录中...' : '登录'}
            </Button>

            <Button
              className="btn-ghost"
              onClick={() => setMode('wechat')}
            >
              使用微信登录
            </Button>
          </View>
        )}

        {/* 底部协议 */}
        <View className="disclaimer-wrap">
          <Text className="disclaimer">登录即表示同意</Text>
          <Text className="link">《用户协议》</Text>
          <Text className="disclaimer">和</Text>
          <Text className="link">《隐私政策》</Text>
        </View>
      </View>
    </View>
  );
}
