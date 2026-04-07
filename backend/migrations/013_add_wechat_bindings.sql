-- Migration: 013_add_wechat_bindings.sql
-- Desc: 用户表新增微信绑定字段，支持微信小程序登录
-- Date: 2026-04-04

-- ============================================================
-- 1. users 表新增微信绑定字段
-- ============================================================
ALTER TABLE users ADD COLUMN IF NOT EXISTS "openId" VARCHAR(128);
ALTER TABLE users ADD COLUMN IF NOT EXISTS "wechatUnionId" VARCHAR(128);
ALTER TABLE users ADD COLUMN IF NOT EXISTS "wechatNickname" VARCHAR(100);
ALTER TABLE users ADD COLUMN IF NOT EXISTS "wechatAvatar" VARCHAR(500);

-- openId 唯一索引（允许多个 phone=null 的微信用户）
DO $$ BEGIN
  CREATE UNIQUE INDEX idx_users_openid ON users("openId") WHERE "openId" IS NOT NULL;
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- ============================================================
-- 2. notifications 表新增微信模板消息相关字段
-- ============================================================
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS "wechatTemplateId" VARCHAR(64);
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS "wechatMsgId" VARCHAR(128);

COMMENT ON COLUMN users."openId" IS '微信小程序 OpenId（唯一）';
COMMENT ON COLUMN users."wechatUnionId" IS '微信 UnionId（需绑定开放平台）';
COMMENT ON COLUMN users."wechatNickname" IS '微信昵称（微信用户默认展示名）';
COMMENT ON COLUMN users."wechatAvatar" IS '微信头像 URL';
