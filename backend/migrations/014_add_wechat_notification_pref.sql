-- 014: 新增微信小程序订阅通知偏好开关
-- 作者: Claude Code
-- 日期: 2026-04-08

-- 在 notification_preferences 表新增 wechat_enabled 字段
ALTER TABLE notification_preferences
ADD COLUMN IF NOT EXISTS "wechatEnabled" BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN notification_preferences."wechatEnabled" IS '微信小程序订阅通知开关，用户在小程序内主动订阅后开启';
