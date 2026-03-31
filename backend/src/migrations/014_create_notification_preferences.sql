-- 014_create_notification_preferences.sql
-- 通知偏好设置表

CREATE TABLE IF NOT EXISTS "notification_preferences" (
    "id"                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "userId"            UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,

    -- 通知开关（按类型）
    "medicationReminder"  BOOLEAN DEFAULT TRUE,
    "missedDose"         BOOLEAN DEFAULT TRUE,
    "appointmentReminder" BOOLEAN DEFAULT TRUE,
    "taskReminder"       BOOLEAN DEFAULT TRUE,
    "dailyCheckin"       BOOLEAN DEFAULT TRUE,
    "healthAlert"         BOOLEAN DEFAULT TRUE,
    "sosEnabled"          BOOLEAN DEFAULT TRUE,
    "memberJoined"        BOOLEAN DEFAULT TRUE,
    "careLog"            BOOLEAN DEFAULT TRUE,

    -- 提醒提前时间
    "medicationLeadMinutes" INT DEFAULT 5,   -- 用药提前多少分钟（默认5分钟）
    "appointmentLeadHours"  INT DEFAULT 24,  -- 复诊提前多少小时（默认24小时）

    -- 免打扰时段
    "dndEnabled"       BOOLEAN DEFAULT FALSE,
    "dndStart"         TIME DEFAULT '22:00',
    "dndEnd"           TIME DEFAULT '07:00',

    -- 推送偏好
    "soundEnabled"      BOOLEAN DEFAULT TRUE,
    "vibrationEnabled"  BOOLEAN DEFAULT TRUE,

    "createdAt"         TIMESTAMPTZ DEFAULT NOW(),
    "updatedAt"         TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS "idx_notification_prefs_user" ON "notification_preferences"("userId");
