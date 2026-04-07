/**
 * 用户模型
 * 对应后端 User 实体
 */
export interface User {
  id: string;
  phone: string | null;
  name: string | null;
  avatar: string | null;
  hasPassword: boolean;
  // 微信绑定字段
  openId?: string | null;
  wechatNickname?: string | null;
  wechatAvatar?: string | null;
}

/**
 * 登录响应（微信登录）
 */
export interface WechatLoginResponse {
  accessToken: string;
  tokenType: string;
  isNewUser: boolean;
  user: {
    id: string;
    phone: string | null;
    name: string | null;
    avatar: string | null;
    hasPassword: boolean;
    isBound: boolean;
  };
}
