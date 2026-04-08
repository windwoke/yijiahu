/**
 * 绑定手机号页
 * 微信小程序通过 getPhoneNumber 一键授权绑定手机号
 * 绑定后可与 App 端账号互通
 */
import { useState } from 'react';
import { View, Text, Image } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { post } from '../../../services/api';
import { Storage } from '../../../services/storage';
import { store } from '../../../store';
import './index.scss';

export default function BindPhonePage() {
  const [loading, setLoading] = useState(false);

  const handleGetPhoneNumber = async (e: any) => {
    // e.detail 包含 errMsg / encryptedData / iv
    const { errMsg, encryptedData, iv } = e.detail || {} as {
      errMsg?: string;
      encryptedData?: string;
      iv?: string;
    };

    if (errMsg !== 'getPhoneNumber:ok') {
      // 用户拒绝授权或点击了拒绝
      console.warn('[bind-phone] 用户拒绝授权:', errMsg);
      return;
    }

    if (!encryptedData || !iv) {
      Taro.showToast({ title: '授权数据获取失败', icon: 'none' });
      return;
    }

    setLoading(true);
    try {
      // 获取当前登录凭证
      const loginRes = await Taro.login();
      if (!loginRes.code) {
        throw new Error('微信登录凭证获取失败');
      }

      // 调用后端绑定接口
      const result = await post<{ success: boolean; phone: string }>('/auth/bind-phone', {
        code: loginRes.code,
        encryptedData,
        iv,
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

        // 延迟跳转首页，让用户看到成功提示
        setTimeout(() => {
          Taro.switchTab({ url: '/pages/home/index' });
        }, 1500);
      }
    } catch (err: any) {
      console.error('[bind-phone] 绑定失败:', err);
      Taro.showToast({ title: err?.message || '绑定失败，请重试', icon: 'none', duration: 2500 });
    } finally {
      setLoading(false);
    }
  };

  return (
    <View className="bp-page">
      {/* 顶部装饰 */}
      <View className="bp-header">
        <View className="bp-icon-wrap">
          <Image
            className="bp-icon"
            src={require('../../../assets/icons/phone.png')}
          />
        </View>
        <Text className="bp-title">绑定手机号</Text>
        <Text className="bp-subtitle">绑定后可在 App 端使用同一账号登录</Text>
      </View>

      {/* 绑定按钮 */}
      <View className="bp-content">
        <View className="bp-benefit-row">
          <View className="bp-benefit-item">
            <Text className="bp-benefit-icon">✓</Text>
            <Text className="bp-benefit-text">与 App 端账号数据互通</Text>
          </View>
          <View className="bp-benefit-item">
            <Text className="bp-benefit-icon">✓</Text>
            <Text className="bp-benefit-text">支持账号密码登录</Text>
          </View>
          <View className="bp-benefit-item">
            <Text className="bp-benefit-icon">✓</Text>
            <Text className="bp-benefit-text">微信一键授权，无需输入</Text>
          </View>
        </View>

        {/* 微信一键绑定按钮 */}
        <View className={`bp-btn-wrap ${loading ? 'bp-btn-wrap-disabled' : ''}`}>
          <button
            {...({
              className: `bp-btn ${loading ? 'bp-btn-disabled' : ''}`,
              'open-type': 'getPhoneNumber',
              onGetPhoneNumber: handleGetPhoneNumber,
              disabled: loading,
            } as any)}
          >
            <Text className="bp-btn-text">
              {loading ? '绑定中...' : '微信一键绑定手机号'}
            </Text>
          </button>
        </View>

        {/* 跳过提示 */}
        <View
          className="bp-skip"
          onClick={() => Taro.switchTab({ url: '/pages/home/index' })}
        >
          <Text className="bp-skip-text">暂不绑定，以后再说</Text>
        </View>
      </View>

      {/* 底部装饰 */}
      <View className="bp-footer">
        <Text className="bp-footer-text">
          绑定即表示同意《用户协议》和《隐私政策》
        </Text>
      </View>
    </View>
  );
}
