-- 添加 scheduledDate 字段到 task_completions 表
-- 用于明确标记完成的是哪一天的任务实例（YYYY-MM-DD 格式）
-- 解决 daily/weekly/monthly 任务完成时间与任务实例日期不匹配的问题

ALTER TABLE task_completions
ADD COLUMN IF NOT EXISTS scheduledDate VARCHAR(10);

-- 为已有记录补充 scheduledDate（从 completedAt 推导北京时间日期）
UPDATE task_completions
SET scheduledDate = TO_CHAR(completedAt AT TIME ZONE 'Asia/Shanghai', 'YYYY-MM-DD')
WHERE scheduledDate IS NULL;

-- 添加注释
COMMENT ON COLUMN task_completions.scheduledDate IS '完成的日期实例，格式 YYYY-MM-DD，例如 2026-03-27 表示完成了当天到期的任务';
