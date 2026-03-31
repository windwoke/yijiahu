#!/bin/bash
# =============================================
# 一家护 - 代码更新脚本（GitHub webhook 触发）
# 或手动执行: bash /opt/yijiahu/update.sh
# =============================================

set -e

APP_DIR="/opt/yijiahu"
LOG_FILE="$APP_DIR/logs/deploy.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=========================================="
log "开始部署..."
log "=========================================="

cd "$APP_DIR"

# 保存当前版本
git log -1 --oneline > "$APP_DIR/.prev_version"

# 拉取最新代码
sudo -u yijiahu git pull origin main >> "$LOG_FILE" 2>&1

# 如果有变更
if ! sudo -u yijiahu git log --since="1 minute" -1 | grep -q "$(cat $APP_DIR/.prev_version)"; then
  log "检测到代码更新，开始构建..."

  cd "$APP_DIR/backend"

  # 安装依赖
  sudo -u yijiahu npm ci --production >> "$LOG_FILE" 2>&1

  # 编译
  sudo -u yijiahu npm run build >> "$LOG_FILE" 2>&1

  # 数据库迁移（如有必要）
  source "$APP_DIR/.env.prod"
  npx prisma migrate deploy >> "$LOG_FILE" 2>&1 || true

  # 重启服务
  systemctl restart yijiahu
  sleep 2

  if systemctl is-active --quiet yijiahu; then
    NEW_VERSION=$(cd "$APP_DIR" && git log -1 --oneline)
    log "[OK] 部署成功！版本: $NEW_VERSION"
  else
    log "[ERROR] 服务启动失败，查看日志："
    journalctl -u yijiahu --no-pager -n 10 | tail -5
    exit 1
  fi
else
  log "无代码更新，跳过构建"
fi
