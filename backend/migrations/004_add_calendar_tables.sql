-- 迁移：创建复诊表、家庭任务表、任务完成记录表
-- 时间: 2026-03-26

-- ============================================================
-- 1. 复诊表
-- ============================================================
CREATE TABLE IF NOT EXISTS appointments (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  "recipientId"         UUID NOT NULL REFERENCES care_recipients(id) ON DELETE CASCADE,
  "familyId"            UUID REFERENCES families(id) ON DELETE SET NULL,
  hospital              VARCHAR(200) NOT NULL,
  department            VARCHAR(100),
  "doctorName"         VARCHAR(100),
  "doctorPhone"         VARCHAR(20),
  "appointmentTime"    TIMESTAMPTZ NOT NULL,
  "appointmentNo"      VARCHAR(50),
  address               VARCHAR(300),
  latitude              DECIMAL(10, 7),
  longitude             DECIMAL(10, 7),
  fee                   DECIMAL(10, 2),
  purpose               VARCHAR(300),
  status                VARCHAR(20) NOT NULL DEFAULT 'upcoming',  -- upcoming/completed/cancelled
  "assignedDriverId"    UUID REFERENCES users(id) ON DELETE SET NULL,
  "reminder48h"         BOOLEAN NOT NULL DEFAULT TRUE,
  "reminder24h"         BOOLEAN NOT NULL DEFAULT TRUE,
  note                  TEXT,
  "createdById"         UUID NOT NULL REFERENCES users(id),
  "createdAt"          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updatedAt"          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "deletedAt"          TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_appointments_recipient ON appointments("recipientId");
CREATE INDEX IF NOT EXISTS idx_appointments_family   ON appointments("familyId");
CREATE INDEX IF NOT EXISTS idx_appointments_time      ON appointments("appointmentTime");
CREATE INDEX IF NOT EXISTS idx_appointments_status    ON appointments(status);

COMMENT ON TABLE appointments IS '复诊/就诊日程表';
COMMENT ON COLUMN appointments."assignedDriverId"   IS '接送人（家庭成员用户ID）';
COMMENT ON COLUMN appointments."reminder48h"         IS '是否在48小时前发送提醒';
COMMENT ON COLUMN appointments."reminder24h"         IS '是否在24小时前发送提醒';

-- ============================================================
-- 2. 家庭任务表
-- ============================================================
CREATE TABLE IF NOT EXISTS family_tasks (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  "familyId"            UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  "recipientId"         UUID REFERENCES care_recipients(id) ON DELETE SET NULL,
  title                 VARCHAR(200) NOT NULL,
  description           TEXT,
  frequency             VARCHAR(20) NOT NULL DEFAULT 'once',  -- once/daily/weekly/monthly
  "scheduledTime"      VARCHAR(8),                             -- HH:mm
  "scheduledDay"       INTEGER[],                              -- 周几(1-7) 或 日期(1-31)
  "assigneeId"          UUID NOT NULL REFERENCES users(id),
  status                VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending/completed/cancelled
  "nextDueAt"          TIMESTAMPTZ,
  note                  TEXT,
  "createdById"         UUID NOT NULL REFERENCES users(id),
  "createdAt"          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updatedAt"          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "deletedAt"          TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_family_tasks_family    ON family_tasks("familyId");
CREATE INDEX IF NOT EXISTS idx_family_tasks_assignee  ON family_tasks("assigneeId");
CREATE INDEX IF NOT EXISTS idx_family_tasks_status    ON family_tasks(status);
CREATE INDEX IF NOT EXISTS idx_family_tasks_next_due  ON family_tasks("nextDueAt");

COMMENT ON TABLE family_tasks IS '家庭任务表';
COMMENT ON COLUMN family_tasks.frequency     IS '频率：once=单次, daily=每日, weekly=每周, monthly=每月';
COMMENT ON COLUMN family_tasks."scheduledDay" IS '周期日数组，周频率存1-7（周一=1），月频率存1-31';

-- ============================================================
-- 3. 任务完成记录表
-- ============================================================
CREATE TABLE IF NOT EXISTS task_completions (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  "taskId"              UUID NOT NULL REFERENCES family_tasks(id) ON DELETE CASCADE,
  "completedById"        UUID NOT NULL REFERENCES users(id),
  "completedAt"         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  note                  TEXT
);

CREATE INDEX IF NOT EXISTS idx_task_completions_task      ON task_completions("taskId");
CREATE INDEX IF NOT EXISTS idx_task_completions_completed ON task_completions("completedAt");

COMMENT ON TABLE task_completions IS '任务完成记录表（每次完成任务生成一条）';
