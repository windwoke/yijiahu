#!/bin/bash
# =============================================
# 一家护 - 生产服务器一键部署脚本
# 适用：阿里云 ECS Ubuntu 22.04 LTS
# =============================================

set -e

# ─── 颜色输出 ───────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ─── 参数检查 ───────────────────────────────
if [ $# -lt 3 ]; then
  echo ""
  echo "用法: bash deploy.sh <域名> <GitHub仓库SSH> <后端分支>"
  echo ""
  echo "示例: bash deploy.sh api.yijiahu.com git@github.com:windwoke/yijiahu.git main"
  echo ""
  echo "前提条件:"
  echo "  1. 服务器已购买，SSH 能连上（ssh root@服务器IP）"
  echo "  2. 域名已解析到服务器 IP"
  echo "  3. 服务器防火墙开放 22, 80, 443 端口"
  echo ""
  exit 1
fi

DOMAIN="$1"
REPO_SSH="$2"
BRANCH="${3:-main}"
APP_DIR="/opt/yijiahu"
NGINX_CONF="/etc/nginx/sites-available/yijiahu"
NGINX_ENABLED="/etc/nginx/sites-enabled/yijiahu"
CERT_DIR="/etc/letsencrypt/live/$DOMAIN"

log_info "=== 一家护生产服务器部署 ==="
log_info "域名:   $DOMAIN"
log_info "仓库:   $REPO_SSH"
log_info "分支:   $BRANCH"
log_info "目录:   $APP_DIR"
echo ""

# ─── 1. 系统更新 ─────────────────────────────
log_info "[1/8] 系统更新..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq
log_ok "系统更新完成"

# ─── 2. 安装基础软件 ─────────────────────────
log_info "[2/8] 安装基础软件（Node.js, PostgreSQL, Nginx, Certbot）..."

# Node.js 18 LTS（使用 NodeSource）
curl -fsSL https://deb.nodesource.com/setup_18.x | bash - > /dev/null 2>&1
apt-get install -y nodejs > /dev/null 2>&1

# PostgreSQL 15
apt-get install -y postgresql postgresql-contrib > /dev/null 2>&1

# Nginx
apt-get install -y nginx > /dev/null 2>&1

# Certbot（SSL 证书）
apt-get install -y certbot python3-certbot-nginx > /dev/null 2>&1

log_ok "基础软件安装完成"

# ─── 3. 配置 PostgreSQL ──────────────────────
log_info "[3/8] 配置 PostgreSQL..."

# 创建数据库和用户
sudo -u postgres psql <<EOF
-- 创建数据库用户
DO \\$\\$ BEGIN
  CREATE USER yijiahu WITH PASSWORD 'CHANGE_ME_PASSWORD';
EXCEPTION WHEN duplicate_object THEN NULL;
END \\$\\$;

-- 创建数据库
DO \\$\\$ BEGIN
  CREATE DATABASE yijiahu OWNER yijiahu;
EXCEPTION WHEN duplicate_object THEN NULL;
END \\$\\$;

-- 授权
GRANT ALL PRIVILEGES ON DATABASE yijiahu TO yijiahu;
ALTER DATABASE yijiahu SET timezone TO 'Asia/Shanghai';
\\q
EOF

# 修改 postgresql.conf 允许远程连接（如需要）
PG_CONF="/etc/postgresql/15/main/postgresql.conf"
if grep -q "^#listen_addresses" "$PG_CONF"; then
  sed -i "s/#listen_addresses.*/listen_addresses = '*'/" "$PG_CONF"
  sed -i "s/listen_addresses.*/listen_addresses = '*'/" "$PG_CONF"
fi

# 修改 pg_hba.conf 允许密码认证
PG_HBA="/etc/postgresql/15/main/pg_hba.conf"
if ! grep -q "host.*all.*all.*md5" "$PG_HBA"; then
  echo "host    all             all             0.0.0.0/0               md5" >> "$PG_HBA"
  echo "host    all             all             ::/0                    md5" >> "$PG_HBA"
fi

systemctl restart postgresql
log_ok "PostgreSQL 配置完成"

# ─── 4. 创建应用目录 ─────────────────────────
log_info "[4/8] 创建应用目录..."
mkdir -p "$APP_DIR"
mkdir -p "$APP_DIR/logs"
mkdir -p "$APP_DIR/backend"
mkdir -p "$APP_DIR/.env.prod"

# 创建应用运行用户
if ! id -u yijiahu > /dev/null 2>&1; then
  useradd -m -s /bin/bash yijiahu
  chown -R yijiahu:yijiahu "$APP_DIR"
fi

log_ok "应用目录创建完成"

# ─── 5. 配置 Nginx ───────────────────────────
log_info "[5/8] 配置 Nginx..."

cat > "$NGINX_CONF" <<EOF
# HTTP -> HTTPS 重定向
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    location / {
        return 301 https://\$host\$request_uri;
    }
}

# HTTPS
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;

    # SSL 证书（Certbot 自动写入）
    ssl_certificate $CERT_DIR/fullchain.pem;
    ssl_certificate_key $CERT_DIR/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;

    # API 代理到后端（NestJS 3000端口）
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }

    # 日志
    access_log /var/log/nginx/yijiahu_access.log;
    error_log /var/log/nginx/yijiahu_error.log;

    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
EOF

# 启用站点
ln -sf "$NGINX_CONF" "$NGINX_ENABLED"
# 禁用默认站点
rm -f /etc/nginx/sites-enabled/default

# 测试配置
nginx -t && systemctl reload nginx
log_ok "Nginx 配置完成"

# ─── 6. 获取 SSL 证书 ────────────────────────
log_info "[6/8] 申请 SSL 证书（Certbot）..."

# 先重启 nginx 确保 80 端口可访问
systemctl restart nginx

# 申请证书（自动验证）
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos \
  --email "admin@$DOMAIN" --redirect > /dev/null 2>&1 || true

# 设置证书自动续期
systemctl enable certbot.timer
systemctl start certbot.timer

log_ok "SSL 证书配置完成"

# ─── 7. 拉取代码 ─────────────────────────────
log_info "[7/8] 拉取代码..."

# 生成 GitHub deploy key（一次性，可跳过如果已有 SSH key）
if [ ! -f ~/.ssh/id_rsa ]; then
  ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "yijiahu-deploy" > /dev/null 2>&1
  log_warn "已生成 SSH deploy key，请添加到 GitHub 仓库 Settings > Deploy Keys:"
  cat ~/.ssh/id_rsa.pub
  echo ""
  read -p "添加后按回车继续..."
fi

# 配置 Git 不会首次连接确认
mkdir -p ~/.ssh
cat >> ~/.ssh/config <<EOF
Host github.com
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF

# 拉取代码
cd "$APP_DIR"
if [ -d ".git" ]; then
  sudo -u yijiahu git pull origin "$BRANCH"
else
  sudo -u yijiahu git clone -b "$BRANCH" "$REPO_SSH" "$APP_DIR"
fi

chown -R yijiahu:yijiahu "$APP_DIR"
log_ok "代码拉取完成"

# ─── 8. 安装依赖 & 启动 ──────────────────────
log_info "[8/8] 安装依赖并启动后端..."

cd "$APP_DIR/backend"

# 创建生产环境变量文件（首次）
ENV_FILE="$APP_DIR/.env.prod"
if [ ! -f "$ENV_FILE" ]; then
  cat > "$ENV_FILE" <<EOF
# ====== 生产环境变量 ======
# 请务必修改以下值！！！

# 数据库
DATABASE_URL=postgresql://yijiahu:CHANGE_ME_PASSWORD@localhost:5432/yijiahu

# JWT（生成随机字符串：openssl rand -base64 64）
JWT_SECRET=CHANGE_ME_GENERATE_WITH_openssl_rand_base64_64

# 后端端口
PORT=3000

# 前端 API 地址（小程序用）
API_BASE_URL=https://$DOMAIN/v1

# Redis（如需要）
# REDIS_URL=redis://localhost:6379

# 极光推送（可选）
# JPUSH_APP_KEY=
# JPUSH_MASTER_SECRET=

# 微信小程序（可选）
# WECHAT_APPID=
# WECHAT_SECRET=
EOF
  log_warn "生产环境变量已创建，请编辑: $ENV_FILE"
fi

# 安装依赖
npm ci --production > /dev/null 2>&1

# 数据库迁移
npm run build > /dev/null 2>&1
npx prisma migrate deploy > /dev/null 2>&1 || true

# 创建 systemd 服务
cat > /etc/systemd/system/yijiahu.service <<EOF
[Unit]
Description=Yijiahu Backend API
After=network.target postgresql.service

[Service]
Type=simple
User=yijiahu
WorkingDirectory=$APP_DIR/backend
EnvironmentFile=$ENV_FILE
ExecStart=/usr/bin/node dist/main.js
Restart=always
RestartSec=10
StandardOutput=append:$APP_DIR/logs/app.log
StandardError=append:$APP_DIR/logs/app.log

[Install]
WantedBy=multi-user.target
EOF

chown yijiahu:yijiahu "$ENV_FILE"
chmod 600 "$ENV_FILE"
chown -R yijiahu:yijiahu "$APP_DIR"

systemctl daemon-reload
systemctl enable yijiahu
systemctl restart yijiahu

# 等待启动
sleep 3
if systemctl is-active --quiet yijiahu; then
  log_ok "后端服务启动成功"
else
  log_error "后端服务启动失败，查看日志："
  journalctl -u yijiahu --no-pager -n 20
fi

# 开放防火墙
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable > /dev/null 2>&1 || true

echo ""
echo ""
echo "=========================================="
log_ok "部署完成！"
echo "=========================================="
echo ""
echo "  API 地址:       https://$DOMAIN/v1"
echo "  管理日志:      journalctl -u yijiahu -f"
echo "  查看状态:      systemctl status yijiahu"
echo "  重启服务:      systemctl restart yijiahu"
echo ""
echo "  数据库:         $APP_DIR/.env.prod"
echo "  代码目录:       $APP_DIR"
echo ""
echo "  下一步："
echo "  1. 编辑 $ENV_FILE，填入真实密码和密钥"
echo "  2. systemctl restart yijiahu"
echo "  3. 测试: curl https://$DOMAIN/v1/health"
echo ""
