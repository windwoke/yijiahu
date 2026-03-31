-- 新增 dailyCheckinCompleted 通知偏好字段（独立控制"打卡完成通知其他成员"）
ALTER TABLE "notification_preferences" ADD COLUMN IF NOT EXISTS "dailyCheckinCompleted" BOOLEAN NOT NULL DEFAULT TRUE;
