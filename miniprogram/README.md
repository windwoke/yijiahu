# 一家护微信小程序

基于 Taro 4.x + React 的微信小程序客户端。

## 技术栈

- **框架**: Taro 4.x（React）
- **状态管理**: Redux + @tarojs/store
- **样式**: SCSS + CSS 变量（品牌色来自 shared/）
- **API 层**: Taro.request 封装（复用 shared/ 层）
- **类型**: TypeScript，共享模型来自 `shared/` 目录

## 目录结构

```
miniprogram/
├── src/
│   ├── app.ts                  # App 根组件
│   ├── app.config.ts           # 全局配置（tabBar、window）
│   ├── pages/
│   │   ├── auth/login/         # 登录页
│   │   ├── home/               # 首页
│   │   ├── medication/         # 药品管理
│   │   ├── calendar/           # 日历
│   │   ├── care-log/           # 护理日志
│   │   ├── family/             # 家庭
│   │   ├── profile/             # 个人设置
│   │   ├── sos/               # SOS 紧急
│   │   └── notification/       # 通知列表
│   ├── components/             # 公共组件
│   ├── services/               # 服务层
│   │   ├── api.ts             # API 客户端
│   │   ├── auth.service.ts    # 认证服务
│   │   └── storage.ts         # 本地存储封装
│   ├── store/                 # Redux store
│   └── styles/               # 全局样式
│       ├── variables.scss     # CSS 变量（品牌色）
│       └── global.scss
└── project.config.json        # 微信开发者工具配置
```

## 开发

### 环境要求

- Node.js >= 18
- npm >= 9

### 安装依赖

```bash
cd miniprogram
npm install
```

### 开发调试

```bash
# 微信小程序（需在微信开发者工具中打开）
npm run dev:weapp

# H5（浏览器预览）
npm run build:h5
```

### 微信开发者工具配置

1. 下载并安装 [微信开发者工具](https://developers.weixin.qq.com/miniprogram/dev/devtools/download.html)
2. 导入项目：`项目目录/miniprogram`
3. AppID：需要替换 `project.config.json` 中的 `appid` 为你的小程序 AppID
4. 编译模式：选择"依赖npm"

## 品牌色

品牌色统一在 `shared/constants/colors.ts` 中定义，
自动注入到小程序的 CSS 变量中。

## TODO

- [ ] tabbar 图标替换（当前为占位）
- [ ] 其他页面实现（见迁移方案）
- [ ] 生产环境 API 地址配置
- [ ] 微信开发者工具 AppID 配置
