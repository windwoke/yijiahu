-- 新增 taskAssigned 通知偏好字段
ALTER TABLE "notification_preferences" ADD COLUMN IF NOT EXISTS "taskAssigned" BOOLEAN NOT NULL DEFAULT TRUE;
