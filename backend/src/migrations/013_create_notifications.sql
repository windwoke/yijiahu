-- 013_create_notifications.sql
-- 通知系统核心表（使用双引号保留 camelCase 列名）

-- 1. 用户 push_token
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'users' AND column_name = 'push_token'
    ) THEN
        ALTER TABLE users ADD COLUMN "pushToken" VARCHAR(255);
    END IF;
END $$;

-- 2. 通知记录表（列名用双引号保留 camelCase）
CREATE TABLE "notifications" (
    "id"             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "userId"         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    "familyId"       UUID REFERENCES families(id) ON DELETE SET NULL,

    "type"           VARCHAR(30) NOT NULL,
    "title"          VARCHAR(100) NOT NULL,
    "body"           TEXT NOT NULL,
    "level"          VARCHAR(10) NOT NULL DEFAULT 'normal',
    "sourceType"     VARCHAR(30),
    "sourceId"       UUID,
    "sourceUserId"   UUID REFERENCES users(id),

    "channel"        VARCHAR(20) NOT NULL DEFAULT 'app',
    "status"         VARCHAR(20) NOT NULL DEFAULT 'pending',

    "isRead"         BOOLEAN DEFAULT FALSE,
    "readAt"         TIMESTAMPTZ,

    "sentAt"         TIMESTAMPTZ,
    "deliveredAt"    TIMESTAMPTZ,
    "openedAt"       TIMESTAMPTZ,

    "dataJson"       JSONB,

    "createdAt"      TIMESTAMPTZ DEFAULT NOW(),
    "updatedAt"      TIMESTAMPTZ DEFAULT NOW(),
    "deletedAt"      TIMESTAMPTZ,

    CONSTRAINT level_check CHECK ("level" IN ('normal', 'high', 'urgent')),
    CONSTRAINT status_check CHECK ("status" IN ('pending', 'sent', 'delivered', 'opened', 'failed')),
    CONSTRAINT channel_check CHECK ("channel" IN ('app', 'wechat', 'sms'))
);

CREATE INDEX IF NOT EXISTS "idx_notifications_user" ON "notifications"("userId");
CREATE INDEX IF NOT EXISTS "idx_notifications_family" ON "notifications"("familyId");
CREATE INDEX IF NOT EXISTS "idx_notifications_type" ON "notifications"("userId", "type");
CREATE INDEX IF NOT EXISTS "idx_notifications_created" ON "notifications"("createdAt" DESC);
