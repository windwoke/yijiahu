/**
 * 认证服务
 * 处理微信登录、手机号登录、token 管理
 */

import Taro from '@tarojs/taro';
import { post, get } from './api';
import { Storage } from './storage';
import { store } from '../store';
import type { User, WechatLoginResponse } from '../shared/models/user';

/**
 * 微信小程序一键登录
 * 流程：wx.login() → code → 后端换取 token → 存储并跳转
 */
export async function wechatLogin(): Promise<{
  user: User;
  isNewUser: boolean;
}> {
  // 1. 获取微信登录凭证
  const loginRes = await Taro.login();
  console.log('[auth] wx.login() result:', loginRes);
  const { code } = loginRes;

  if (!code) {
    throw new Error('微信登录失败，未获取到 code');
  }

  // 2. 调用后端微信登录接口
  const res = await post<WechatLoginResponse>('/auth/wechat-login', { code });
  console.log('[auth] wechat-login response:', JSON.stringify(res));

  // 3. 存储 token
  Storage.setToken(res.accessToken);
  Storage.setUserId(res.user.id);

  // 4. 更新 Redux store
  try {
    store.dispatch({ type: 'auth/setToken', payload: res.accessToken });
    store.dispatch({ type: 'auth/setUser', payload: res.user });
    console.log('[auth] Redux state updated');
  } catch (e) {
    console.error('[auth] Redux dispatch error:', e);
  }

  // 5. 检查是否有家庭，无家庭则引导创建/加入
  try {
    console.log('[auth] 开始检查家庭...');
    const res = await get<{ families: any[] }>('/users/me/families');
    const families = res?.families ?? [];
    console.log('[auth] /users/me/families 返回:', JSON.stringify(families));
    if (!families || families.length === 0) {
      // 无家庭，跳转到引导页
      console.log('[auth] 无家庭，跳转引导页');
      Taro.redirectTo({ url: '/pages/auth/onboarding/index' });
    } else {
      console.log('[auth] 有家庭，直接跳转首页');
      Storage.setCurrentFamilyId(families[0].family?.id || '');
      Taro.switchTab({ url: '/pages/home/index' });
    }
  } catch (err: any) {
    console.error('[auth] 检查家庭失败:', err);
    // 网络错误，默认跳首页
    Taro.switchTab({ url: '/pages/home/index' });
  }

  return { user: res.user, isNewUser: res.isNewUser };
}

/**
 * 手机号+验证码登录（小程序内也可使用）
 */
export async function phoneLogin(phone: string, code: string): Promise<User> {
  const res = await post<{ accessToken: string; user: User }>('/auth/login', {
    phone,
    code,
  });

  Storage.setToken(res.accessToken);
  Storage.setUserId(res.user.id);

  store.dispatch({ type: 'auth/setToken', payload: res.accessToken });
  store.dispatch({ type: 'auth/setUser', payload: res.user });

  console.log('[auth] 手机号登录成功, user:', res.user);

  // 检查是否有家庭，无家庭则引导创建/加入
  try {
    const res = await get<{ families: Array<{ family: { id: string } }> }>('/users/me/families');
    const families = res?.families ?? [];
    if (!families || families.length === 0) {
      Taro.redirectTo({ url: '/pages/auth/onboarding/index' });
    } else {
      // 后端返回 { families: [{ family: {...}, role }] }
      Storage.setCurrentFamilyId(families[0].family?.id || '');
      Taro.switchTab({ url: '/pages/home/index' });
    }
  } catch {
    Taro.switchTab({ url: '/pages/home/index' });
  }

  return res.user;
}

/**
 * 发送验证码
 */
export async function sendCode(phone: string): Promise<{ mockCode?: string }> {
  const res = await post<{ mockCode?: string }>('/auth/send-code', { phone });
  return res;
}

/**
 * 登出
 */
export async function logout(): Promise<void> {
  Storage.clearToken();
  Storage.remove('user_id');
  Storage.remove('current_family_id');

  store.dispatch({ type: 'auth/clear' });

  Taro.redirectTo({ url: '/pages/auth/login/index' });
}

/**
 * 获取当前用户信息（启动时调用）
 */
export async function fetchCurrentUser(): Promise<User | null> {
  const token = Storage.getToken();
  if (!token) return null;

  try {
    const user = await get<User>('/users/me');
    store.dispatch({ type: 'auth/setUser', payload: user });
    return user;
  } catch (err: any) {
    // 只有 401 才清除 token，网络错误等临时问题保留 token
    const isUnauthorized = err?.isUnauthorized || err?.code === 401 || err?.code === 20001;
    if (isUnauthorized) Storage.clearToken();
    return null;
  }
}
