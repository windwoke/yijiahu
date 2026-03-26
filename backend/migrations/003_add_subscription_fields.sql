-- 迁移：家庭表新增订阅相关字段 + 创建订阅记录表
-- 时间: 2026-03-26

-- 1. 家庭表新增字段
ALTER TABLE families ADD COLUMN IF NOT EXISTS "ownerId" UUID REFERENCES users(id);
ALTER TABLE families ADD COLUMN IF NOT EXISTS "region" VARCHAR(10) NOT NULL DEFAULT 'CN';
ALTER TABLE families ADD COLUMN IF NOT EXISTS "maxRecipients" INTEGER NOT NULL DEFAULT 1;
ALTER TABLE families ADD COLUMN IF NOT EXISTS "maxMembers" INTEGER NOT NULL DEFAULT 3;
ALTER TABLE families ADD COLUMN IF NOT EXISTS "maxLogsPerMonth" INTEGER NOT NULL DEFAULT 50;
ALTER TABLE families ADD COLUMN IF NOT EXISTS "deletedAt" TIMESTAMPTZ;

-- 已有家庭：用 ownerId = owner_id（第一个管理员的 userId），暂用 owner_id 列或 NULL
-- 如果 owner_id 列存在则迁移
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'families' AND column_name = 'owner_id') THEN
    UPDATE families SET "ownerId" = owner_id WHERE "ownerId" IS NULL;
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'owner_id column migration skipped: %', SQLERRM;
END $$;

-- 设置 ownerId = creator（如果有 family_members 表的话，取 role=owner 的第一条）
UPDATE families f
SET "ownerId" = (
  SELECT fm."userId"
  FROM family_members fm
  WHERE fm."familyId" = f.id
  AND fm.role = 'owner'
  LIMIT 1
)
WHERE f."ownerId" IS NULL;

-- 2. 创建订阅记录表
CREATE TABLE IF NOT EXISTS subscriptions (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  "familyId"           UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  plan                  VARCHAR(20) NOT NULL,   -- free/premium/annual
  status                VARCHAR(20) NOT NULL,   -- active/cancelled/expired/pending
  "startsAt"           TIMESTAMPTZ NOT NULL,
  "expiresAt"          TIMESTAMPTZ NOT NULL,
  "paymentPlatform"    VARCHAR(20),            -- wechat/apple/google
  "paymentTradeNo"     VARCHAR(100),           -- 平台交易单号
  "appleReceipt"       TEXT,                   -- IAP receipt（验签后存储）
  "wechatPrepayId"    VARCHAR(64),            -- 微信预支付 id
  "cancelAt"          TIMESTAMPTZ,            -- 取消时间（取消但未到期）
  "refundedAt"         TIMESTAMPTZ,            -- 退款时间
  "createdAt"         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updatedAt"         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_family ON subscriptions("familyId");
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_expires ON subscriptions("expiresAt");

COMMENT ON TABLE subscriptions IS '家庭订阅记录流水';
COMMENT ON COLUMN subscriptions."paymentPlatform" IS '支付平台：wechat/apple/google';
COMMENT ON COLUMN subscriptions."paymentTradeNo" IS '平台交易单号（微信支付单号/IAP transactionId）';
