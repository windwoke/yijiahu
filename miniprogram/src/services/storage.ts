/**
 * 本地存储封装
 * 封装 Taro.getStorageSync，避免大量重复的 try-catch
 */

import Taro from '@tarojs/taro';

const PREFIX = 'yijiahu_';

export const Storage = {
  /** 同步获取 */
  get<T = string>(key: string): T | null {
    try {
      const val = Taro.getStorageSync(`${PREFIX}${key}`);
      return (val === '' ? null : val) as T | null;
    } catch {
      return null;
    }
  },

  /** 同步设置 */
  set(key: string, value: any): void {
    try {
      Taro.setStorageSync(`${PREFIX}${key}`, value);
    } catch (e) {
      console.warn('[Storage] set failed:', e);
    }
  },

  /** 删除 */
  remove(key: string): void {
    try {
      Taro.removeStorageSync(`${PREFIX}${key}`);
    } catch (e) {
      console.warn('[Storage] remove failed:', e);
    }
  },

  /** 清空所有 */
  clear(): void {
    try {
      Taro.clearStorageSync();
    } catch (e) {
      console.warn('[Storage] clear failed:', e);
    }
  },

  // ─── 认证相关 ───────────────────────────────────────────────

  getToken(): string {
    return this.get<string>('access_token') ?? '';
  },

  setToken(token: string): void {
    this.set('access_token', token);
  },

  clearToken(): void {
    this.remove('access_token');
  },

  // ─── 用户信息 ───────────────────────────────────────────────

  getUserId(): string {
    return this.get<string>('user_id') ?? '';
  },

  setUserId(id: string): void {
    this.set('user_id', id);
  },

  // ─── 当前家庭 ───────────────────────────────────────────────

  getCurrentFamilyId(): string {
    return this.get<string>('current_family_id') ?? '';
  },

  setCurrentFamilyId(id: string): void {
    this.set('current_family_id', id);
  },
};
