import { useState } from 'react';
import { View, Text, /*Input,*/ Button, Image } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { wechatLogin /*, phoneLogin, sendCode*/ } from '../../../services/auth.service';
// import { isValidPhone } from '../../../shared/utils/phone';
import './index.scss';

/** 登录页（当前仅开放微信一键登录，手机号验证码登录已注释） */

// PNG 图标（对应 Flutter prefixIcon）
// const PhoneIcon = () => (
//   <Image className="field-icon-img" src={require('../../../assets/icons/phone.png')} />
// );
//
// const KeyIcon = () => (
//   <Image className="field-icon-img" src={require('../../../assets/icons/key.png')} />
// );

export default function LoginPage() {
  // const [mode, setMode] = useState<'wechat' | 'phone'>('wechat');
  const [loading, setLoading] = useState(false);
  const [agreed, setAgreed] = useState(false); // 用户协议勾选
  // const [phone, setPhone] = useState('');
  // const [code, setCode] = useState('');
  // const [countdown, setCountdown] = useState(0);
  // const [phoneError, setPhoneError] = useState('');
  // const [codeError, setCodeError] = useState('');

  const handleWechatLogin = async () => {
    if (!agreed) {
      Taro.showToast({ title: '请先阅读并同意用户协议和隐私政策', icon: 'none' });
      return;
    }
    if (loading) return;
    setLoading(true);
    try {
      await wechatLogin();
      // wechatLogin 内部已处理跳转，加个保险防止 switchTab 静默失败
      setTimeout(() => {
        Taro.switchTab({ url: '/pages/home/index' });
      }, 1000);
    } catch (err: any) {
      console.error('[login] 微信登录失败:', err);
      Taro.showToast({ title: err.message || '登录失败', icon: 'none' });
    } finally {
      setLoading(false);
    }
  };

  // const handleSendCode = async () => {
  //   if (!isValidPhone(phone)) {
  //     setPhoneError('请输入正确的手机号');
  //     return;
  //   }
  //   setPhoneError('');
  //   try {
  //     const res = await sendCode(phone);
  //     if (res.mockCode) {
  //       Taro.showModal({
  //         title: '测试验证码',
  //         content: `验证码：${res.mockCode}`,
  //         showCancel: false,
  //       });
  //     } else {
  //       Taro.showToast({ title: '验证码已发送', icon: 'success' });
  //     }
  //     setCountdown(60);
  //     const timer = setInterval(() => {
  //       setCountdown((c) => {
  //         if (c <= 1) { clearInterval(timer); return 0; }
  //         return c - 1;
  //       });
  //     }, 1000);
  //   } catch (err: any) {
  //     Taro.showToast({ title: err.message || '发送失败', icon: 'none' });
  //   }
  // };

  // const handlePhoneLogin = async () => {
  //   if (!isValidPhone(phone)) {
  //     setPhoneError('请输入正确的手机号');
  //     return;
  //   }
  //   if (code.length !== 6) {
  //     setCodeError('请输入6位验证码');
  //     return;
  //   }
  //   setLoading(true);
  //   try {
  //     await phoneLogin(phone, code);
  //   } catch (err: any) {
  //     console.error('[login] 手机号登录失败:', err);
  //     Taro.showToast({ title: err.message || '登录失败', icon: 'none' });
  //   } finally {
  //     setLoading(false);
  //   }
  // };

  return (
    <View className="login-page">
      <View className="bg-gradient" />
      <View className="bg-circle-top" />
      <View className="bg-circle-bottom" />

      <View className="login-content">
        <View className="logo-area">
          <View className="logo-icon-wrap">
            <Image className="logo-heart" src={require('../../../assets/icons/heart-white.png')} />
          </View>
          <Text className="logo-name">一家护</Text>
          <Text className="logo-slogan">家庭照护，从容有爱</Text>
        </View>

        {/* 微信登录面板 */}
        <View className="panel">
          <Button
            className="btn-wechat-primary"
            onClick={handleWechatLogin}
            disabled={loading}
          >
            <Text className="btn-wechat-text">微信一键登录</Text>
          </Button>

          {/* 手机号登录入口（暂隐藏）
          <Button
            className="btn-ghost"
            onClick={() => setMode('phone')}
          >
            使用手机号登录
          </Button>
          */}
        </View>

        {/* 手机号登录面板（暂隐藏）
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
        */}

        <View className="disclaimer-wrap">
          <View className="agreement-row" onClick={() => setAgreed(!agreed)}>
            <View className={`agreement-checkbox ${agreed ? 'agreement-checked' : ''}`}>
              {agreed && <Text className="agreement-checkmark">✓</Text>}
            </View>
            <Text className="disclaimer">我已阅读并同意</Text>
            <Text className="link">《用户协议》</Text>
            <Text className="disclaimer">和</Text>
            <Text className="link">《隐私政策》</Text>
          </View>
        </View>
      </View>
    </View>
  );
}
