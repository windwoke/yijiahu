/**
 * API 客户端
 * 基于 Taro.request，封装统一的请求逻辑
 * 复用 shared/ 层错误处理
 */

import Taro from '@tarojs/taro';
import { store } from '../store';

/** API 基础地址（ICP备案期间使用IP，备案完成后改回HTTPS） */
export const BASE_URL = 'http://8.163.69.199/v1';

/** 上传文件服务地址（OSS 地址，兼容开发和生产） */
export const UPLOADS_URL = 'https://yijiahu.oss-cn-guangzhou.aliyuncs.com';

/** storage key 前缀（与 storage.ts 保持一致） */
const PREFIX = 'yijiahu_';

/** 上传文件（不走统一响应封装） */
export async function uploadFile(
  url: string,
  filePath: string,
  name: string = 'file',
  formData?: Record<string, string>,
): Promise<any> {
  const token = Taro.getStorageSync(`${PREFIX}access_token`);
  return new Promise((resolve, reject) => {
    Taro.uploadFile({
      url: `${BASE_URL}${url}`,
      filePath,
      name,
      header: {
        Authorization: token ? `Bearer ${token}` : '',
      },
      formData,
      success: (res) => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          try {
            resolve(JSON.parse(res.data));
          } catch {
            resolve(res.data);
          }
        } else {
          reject(new Error(`上传失败: ${res.statusCode}`));
        }
      },
      fail: (err) => reject(new Error(err.errMsg || '上传失败')),
    });
  });
}

/** 请求超时 */
const TIMEOUT = 30000;

/** 防止重复重定向的标志（每次 App 启动时重置） */
let isRedirecting = false;

export function resetRedirectFlag(): void {
  isRedirecting = false;
}

/** 响应码 */
export const API_CODE = {
  SUCCESS: 0,
  PARAM_ERROR: 10001,
  SIGN_ERROR: 10002,
  UNAUTHORIZED: 20001,
  NO_PERMISSION: 20002,
  NOT_FOUND: 30001,
  SERVER_ERROR: 50001,
} as const;

export class ApiException extends Error {
  code: number;
  message: string;
  errors?: Array<{ field: string; message: string }>;

  constructor(code: number, message: string, errors?: Array<{ field: string; message: string }>) {
    super(message);
    this.code = code;
    this.message = message;
    this.errors = errors;
  }

  static fromResponse(res: any): ApiException {
    return new ApiException(
      res.statusCode ?? res.code ?? -1,
      res.message || res.errMsg || '请求失败',
      res.errors,
    );
  }

  get isUnauthorized(): boolean {
    return this.code === API_CODE.UNAUTHORIZED || this.code === 401;
  }
}

interface RequestOptions extends Omit<Taro.request.Option, 'url' | 'method' | 'header' | 'data'> {
  url: string;
  method?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
  data?: any;
  params?: Record<string, string | number>;
  noAuth?: boolean;
  noToast?: boolean;
}

interface ApiResponse<T = unknown> {
  code: number;
  message: string;
  data: T;
  request_id?: string;
  timestamp?: number;
}

/** 通用请求方法 */
async function request<T = unknown>(options: RequestOptions): Promise<T> {
  const { url, method = 'GET', data, params, noAuth = false, noToast = false, ...taroOptions } = options;

  // 拼接参数
  let fullUrl = `${BASE_URL}${url}`;
  if (params) {
    const searchParams = new URLSearchParams();
    Object.entries(params).forEach(([k, v]) => searchParams.set(k, String(v)));
    fullUrl += `?${searchParams.toString()}`;
  }

  // 获取 token
  const token = noAuth ? undefined : Taro.getStorageSync(`${PREFIX}access_token`);
  console.log(`[api] ${method} ${fullUrl} token=${token ? 'yes' : 'NO'}`);

  const header: Record<string, string> = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-Platform': 'wechat', // 微信小程序来源
    'X-Version': '1.0.0',
    ...(options.header || {}),
  };

  if (token) {
    header['Authorization'] = `Bearer ${token}`;
  }

  try {
    const res = await Taro.request({
      url: fullUrl,
      method,
      data,
      header,
      timeout: TIMEOUT,
      ...taroOptions,
    });

    // HTTP 错误
    if (res.statusCode < 200 || res.statusCode >= 300) {
      if (res.statusCode === 401) {
        // Token 过期，清除并跳转登录（加标志防止重复）
        if (!isRedirecting) {
          isRedirecting = true;
          console.error(`[api] 401 on ${method} ${url}, redirecting to login`);
          Taro.removeStorageSync(`${PREFIX}access_token`);
          Taro.redirectTo({ url: '/pages/auth/login/index' });
        }
      }
      const body = res.data as any;
      const errMsg = (body && body.message) || res.errMsg || '请求失败';
      throw ApiException.fromResponse({ code: res.statusCode, message: errMsg, errors: body?.errors });
    }

    const body = res.data as any;

    // 业务错误：后端返回 { code, message, ... } 时检查 code
    // 注意：NestJS 的 HttpException 返回格式中没有 code 字段，
    // 只有正常响应（数组或对象）才没有 code，错误响应是 { statusCode, message, ... }
    // 所以这里判断：有 code 且非 0 才算错误
    if (body && typeof body.code === 'number' && body.code !== API_CODE.SUCCESS) {
      if (!noToast && body.message) {
        Taro.showToast({ title: body.message, icon: 'none', duration: 2000 });
      }
      throw ApiException.fromResponse(body);
    }

    // 兼容两种响应格式：
    // 1. { data: T, code: 0 }  —— 标准格式
    // 2. 直接返回 T（如登录返回 { accessToken, user }）—— 部分接口格式
    return body.data !== undefined ? body.data : body;
  } catch (err: any) {
    if (err instanceof ApiException) {
      throw err;
    }
    // 网络错误
    if (!noToast) {
      Taro.showToast({ title: '网络请求失败', icon: 'none', duration: 2000 });
    }
    throw new ApiException(-1, '网络请求失败');
  }
}

/** GET 请求 */
export const get = <T = unknown>(url: string, params?: Record<string, string | number>, options?: Partial<RequestOptions>) =>
  request<T>({ url, method: 'GET', params, ...options });

/** POST 请求 */
export const post = <T = unknown>(url: string, data?: any, options?: Partial<RequestOptions>) =>
  request<T>({ url, method: 'POST', data, ...options });

/** PUT 请求 */
export const put = <T = unknown>(url: string, data?: any, options?: Partial<RequestOptions>) =>
  request<T>({ url, method: 'PUT', data, ...options });

/** PATCH 请求 */
export const patch = <T = unknown>(url: string, data?: any, options?: Partial<RequestOptions>) =>
  request<T>({ url, method: 'PATCH', data, ...options });

/** DELETE 请求 */
export const del = <T = unknown>(url: string, options?: Partial<RequestOptions>) =>
  request<T>({ url, method: 'DELETE', ...options });
