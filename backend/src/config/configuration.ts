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

  // 微信小程序/服务号配置
  wechat: {
    // 小程序配置（用于微信登录）
    miniApp: {
      appId: process.env.WECHAT_MINI_APP_ID || '',
      appSecret: process.env.WECHAT_MINI_APP_SECRET || '',
    },
    // 服务号配置（用于模板消息推送）
    officialAccount: {
      appId: process.env.WECHAT_OA_APP_ID || '',
      appSecret: process.env.WECHAT_OA_APP_SECRET || '',
    },
    // 微信支付配置
    payment: {
      mchId: process.env.WECHAT_MCH_ID || '',
      apiKey: process.env.WECHAT_API_KEY || '', // V2 签名密钥
      certPath: process.env.WECHAT_CERT_PATH || '', // V2 退款证书路径
    },
    // 模板消息 ID
    templates: {
      medicationReminder:
        process.env.WECHAT_TMPL_MEDICATION || 'TMPL_MEDICATION',
      appointmentReminder:
        process.env.WECHAT_TMPL_APPOINTMENT || 'TMPL_APPOINTMENT',
      sos: process.env.WECHAT_TMPL_SOS || 'TMPL_SOS',
    },
    // 小程序订阅消息模板 ID（通过微信公众平台配置，仅支持一次性订阅的低频关键场景）
    // 模板字段必须与微信后台配置完全一致
    tmpl: {
      // SOS 紧急求助（thing1姓名 thing3地址 thing5紧急联系人 phone_number6电话 thing7备注）
      sos: process.env.WECHAT_TMPL_SOS || '',
      // 复诊提醒（time1复诊日期 time2复诊时间 thing3复诊医院 thing4温馨提示 thing6复诊人）
      appointmentReminder: process.env.WECHAT_TMPL_APPOINTMENT || '',
    },
  },
});
