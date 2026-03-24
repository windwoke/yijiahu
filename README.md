# 一家护 (Yi Jia Hu)

> 家庭照护协调平台 —— 让家人更好地照顾老人

## 项目结构

```
yijiahu/
├── flutter/          # Flutter App（iOS/Android）
├── backend/         # NestJS API 后端
├── .github/         # GitHub Actions CI/CD
└── docs/           # 设计文档（商业方案、技术架构等）
```

## 技术栈

| 端 | 技术 |
|----|------|
| 移动端 | Flutter 3.x + Riverpod + go_router |
| 后端 | NestJS + TypeScript + TypeORM |
| 数据库 | PostgreSQL 16 + Redis |
| 云服务 | 阿里云（境内存储，PIPL 合规）|
| 微信生态 | 微信小程序（主入口）+ App |

## 本地开发

### 前端（Flutter）

```bash
cd flutter
flutter pub get
flutter run
```

### 后端（NestJS）

```bash
cd backend
npm install

# 启动开发服务器（需要 PostgreSQL）
cp .env.example .env   # 编辑填入数据库配置
npm run start:dev

# API 文档：http://localhost:3000/api-docs
```

### 环境变量（后端）

```bash
# .env 示例
NODE_ENV=development
PORT=3000

DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=postgres
DB_PASSWORD=你的密码
DB_NAME=yijiahu

JWT_SECRET=你的JWT密钥
JWT_EXPIRES_IN=7d

REDIS_HOST=localhost
REDIS_PORT=6379
```

## CI/CD

- **Flutter CI** — 每次 push 自动构建 iOS + Android
- **Backend CI** — 每次 push 到 `backend/` 目录自动 lint + test + build

## 主要功能

- [x] 手机号 + 验证码登录
- [x] 今日用药打卡
- [x] 家庭成员管理 + 邀请码
- [ ] 用药提醒推送
- [ ] 复诊日历
- [ ] 紧急 SOS
- [ ] 照护日志
- [ ] 健康数据追踪

## 合规

- **个人信息保护法（PIPL）**：敏感数据境内存储
- **网络完全法**：阿里云境内服务器
- **医疗法规**：定位"记录与提醒"，不提供诊断/治疗
