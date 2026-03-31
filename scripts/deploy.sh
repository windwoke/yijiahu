#!/bin/bash
# =============================================
# Yijiahu Production Server Setup Script
# Ubuntu 22.04 LTS on Aliyun ECS
# =============================================
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [ $# -lt 3 ]; then
  echo ""
  echo "Usage: bash deploy.sh <domain> <repo_ssh> <branch>"
  echo "Example: bash deploy.sh api.yijiahu.com git@github.com:windwoke/yijiahu.git main"
  exit 1
fi

DOMAIN="$1"
REPO_SSH="$2"
BRANCH="${3:-main}"
APP_DIR="/opt/yijiahu"

log_info "=== Yijiahu Production Deployment ==="
log_info "Domain: $DOMAIN"
log_info "Repo:   $REPO_SSH"
log_info "Branch: $BRANCH"

# ── 1. System Update ──
log_info "[1/8] System update..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq
log_ok "System updated"

# ── 2. Install Software ──
log_info "[2/8] Installing software..."

curl -fsSL https://deb.nodesource.com/setup_18.x | bash - > /dev/null 2>&1
apt-get install -y nodejs > /dev/null 2>&1

apt-get install -y postgresql postgresql-contrib > /dev/null 2>&1
apt-get install -y nginx > /dev/null 2>&1
apt-get install -y certbot python3-certbot-nginx > /dev/null 2>&1

log_ok "Software installed"

# ── 3. PostgreSQL Setup ──
log_info "[3/8] Configuring PostgreSQL..."

PG_VER=$(ls /etc/postgresql/ | grep -E '^[0-9]+' | sort -r | head -1)
if [ -z "$PG_VER" ]; then
  log_error "PostgreSQL not found"
  exit 1
fi
log_info "PostgreSQL version: $PG_VER"

PG_CONF="/etc/postgresql/$PG_VER/main/postgresql.conf"
PG_HBA="/etc/postgresql/$PG_VER/main/pg_hba.conf"

# Create user and database
sudo -u postgres psql -c "CREATE USER yijiahu WITH PASSWORD 'CHANGE_ME_PASSWORD';" 2>/dev/null || true
sudo -u postgres psql -c "CREATE DATABASE yijiahu OWNER yijiahu;" 2>/dev/null || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE yijiahu TO yijiahu;" 2>/dev/null || true

# Allow remote connections
if [ -f "$PG_CONF" ]; then
  sed -i "s/^#listen_addresses.*/listen_addresses = '*'/" "$PG_CONF"
  sed -i "s/^listen_addresses.*/listen_addresses = '*'/" "$PG_CONF"
fi

# Allow password auth
if [ -f "$PG_HBA" ] && ! grep -q "host.*all.*all.*md5" "$PG_HBA"; then
  echo "host    all             all             0.0.0.0/0               md5" >> "$PG_HBA"
  echo "host    all             all             ::/0                    md5" >> "$PG_HBA"
fi

systemctl restart postgresql
log_ok "PostgreSQL configured"

# ── 4. App Directory ──
log_info "[4/8] Creating app directory..."
mkdir -p "$APP_DIR"/{backend,logs}
if ! id -u yijiahu > /dev/null 2>&1; then
  useradd -m -s /bin/bash yijiahu
fi
chown -R yijiahu:yijiahu "$APP_DIR"
log_ok "Directory created"

# ── 5. Nginx ──
log_info "[5/8] Configuring Nginx..."

mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled
rm -f /etc/nginx/sites-enabled/default

cat > /etc/nginx/sites-available/yijiahu <<NGINXEOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    location / { return 301 https://\$host\$request_uri; }
}
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300s;
    }
    access_log /var/log/nginx/yijiahu_access.log;
    error_log /var/log/nginx/yijiahu_error.log;
}
NGINXEOF

ln -sf /etc/nginx/sites-available/yijiahu /etc/nginx/sites-enabled/yijiahu
nginx -t && systemctl reload nginx
log_ok "Nginx configured"

# ── 6. SSL Certificate ──
log_info "[6/8] Getting SSL certificate..."
systemctl restart nginx
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "admin@$DOMAIN" --redirect > /dev/null 2>&1 || true
systemctl enable certbot.timer
systemctl start certbot.timer
log_ok "SSL configured"

# ── 7. Pull Code ──
log_info "[7/8] Pulling code..."

# Configure SSH for GitHub
mkdir -p ~/.ssh
cat >> ~/.ssh/config <<EOF
Host github.com
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF

cd "$APP_DIR"
if [ -d ".git" ]; then
  sudo -u yijiahu git pull origin "$BRANCH"
else
  sudo -u yijiahu git clone -b "$BRANCH" "$REPO_SSH" "$APP_DIR"
fi
chown -R yijiahu:yijiahu "$APP_DIR"
log_ok "Code pulled"

# ── 8. Build & Start ──
log_info "[8/8] Building and starting..."

cd "$APP_DIR/backend"

ENV_FILE="$APP_DIR/.env.prod"
if [ ! -f "$ENV_FILE" ]; then
  cat > "$ENV_FILE" <<ENVEOF
DATABASE_URL=postgresql://yijiahu:CHANGE_ME_PASSWORD@localhost:5432/yijiahu
JWT_SECRET=CHANGE_ME_GENERATE_WITH_openssl_rand_base64_64
PORT=3000
API_BASE_URL=https://$DOMAIN/v1
ENVEOF
  log_warn "ENV file created at $ENV_FILE - please edit and set real passwords"
fi

npm ci --production > /dev/null 2>&1
npm run build > /dev/null 2>&1

# Prisma migrate
source "$ENV_FILE" 2>/dev/null || true
npx prisma migrate deploy > /dev/null 2>&1 || true

# Systemd service
cat > /etc/systemd/system/yijiahu.service <<SYSEOF
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
SYSEOF

chown yijiahu:yijiahu "$ENV_FILE"
chmod 600 "$ENV_FILE"
chown -R yijiahu:yijiahu "$APP_DIR"

systemctl daemon-reload
systemctl enable yijiahu
systemctl restart yijiahu

sleep 3
if systemctl is-active --quiet yijiahu; then
  log_ok "Service started successfully"
else
  log_error "Service failed to start, check logs:"
  journalctl -u yijiahu --no-pager -n 20
fi

# Firewall
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable > /dev/null 2>&1 || true

echo ""
echo "=========================================="
log_ok "Deployment complete!"
echo "=========================================="
echo ""
echo "  API:          https://$DOMAIN/v1"
echo "  Logs:         journalctl -u yijiahu -f"
echo "  Status:       systemctl status yijiahu"
echo "  Restart:      systemctl restart yijiahu"
echo "  Env file:     $ENV_FILE"
echo ""
echo "NEXT STEPS:"
echo "  1. nano $ENV_FILE  -> set real JWT_SECRET and DB password"
echo "  2. systemctl restart yijiahu"
echo "  3. curl https://$DOMAIN/v1/health"
echo ""
