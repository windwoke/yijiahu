export default () => ({
  // 服务端口
  port: parseInt(process.env.PORT || '3000', 10),

  // JWT 配置
  jwt: {
    secret: process.env.JWT_SECRET || 'yijiahu-dev-secret-change-in-production',
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  },

  // 数据库配置
  database: {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '5432', 10),
    username: process.env.DB_USERNAME || 'postgres',
    password: process.env.DB_PASSWORD || 'postgres',
    name: process.env.DB_NAME || 'yijiahu',
    synchronize: false,
    logging: process.env.NODE_ENV !== 'production',
  },

  // Redis 配置
  redis: {
    host: process.env.REDIS_HOST || 'localhost',
    port: parseInt(process.env.REDIS_PORT || '6379', 10),
    password: process.env.REDIS_PASSWORD || undefined,
  },

  // 阿里云配置
  aliyun: {
    accessKeyId: process.env.ALIYUN_ACCESS_KEY_ID || '',
    accessKeySecret: process.env.ALIYUN_ACCESS_KEY_SECRET || '',
    ossEndpoint:
      process.env.ALIYUN_OSS_ENDPOINT || 'oss-cn-hangzhou.aliyuncs.com',
    ossBucket: process.env.ALIYUN_OSS_BUCKET || 'yijiahu',
  },

  // 短信配置（阿里云）
  sms: {
    mode: process.env.SMS_MODE || 'mock', // mock | aliyun
    codeOverride: process.env.SMS_CODE_OVERRIDE || '', // 开发固定验证码
    accessKeyId: process.env.ALIYUN_ACCESS_KEY_ID || '',
    accessKeySecret: process.env.ALIYUN_ACCESS_KEY_SECRET || '',
    signName: process.env.SMS_SIGN_NAME || '一家护',
    loginTemplateCode: process.env.SMS_LOGIN_TEMPLATE || 'SMS_xxx',
  },

  // 极光推送配置
  jpush: {
    appKey: process.env.JPUSH_APP_KEY || '',
    masterSecret: process.env.JPUSH_MASTER_SECRET || '',
  },
});
