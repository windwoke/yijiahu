-- 给 care_log_attachments 表添加 familyId 列（用于多家庭数据隔离）
-- 前置：care_logs.familyId 存的是 UUID 字符串但类型是 varchar，先统一为 uuid 以便建 FK

-- 0. 将 care_logs.familyId 从 varchar 转为 uuid（如果尚未转换）
DO $$
BEGIN
  IF (SELECT data_type FROM information_schema.columns WHERE table_name = 'care_logs' AND column_name = 'familyId') = 'character varying' THEN
    ALTER TABLE "care_logs" ALTER COLUMN "familyId" TYPE uuid USING "familyId"::uuid;
    RAISE NOTICE 'care_logs.familyId 已转为 uuid';
  ELSE
    RAISE NOTICE 'care_logs.familyId 已是 uuid 类型，跳过';
  END IF;
END $$;

-- 0b. 将 care_log_attachments.familyId 从 varchar 转为 uuid（如果尚未转换）
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'care_log_attachments' AND column_name = 'familyId' AND data_type = 'character varying') THEN
    ALTER TABLE "care_log_attachments" ALTER COLUMN "familyId" TYPE uuid USING "familyId"::uuid;
    RAISE NOTICE 'care_log_attachments.familyId 已转为 uuid';
  ELSE
    RAISE NOTICE 'care_log_attachments.familyId 已是 uuid 类型，跳过';
  END IF;
END $$;

-- 1. 添加列（可空，为现有数据回填做准备，IF NOT EXISTS 防止重复执行）
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'care_log_attachments' AND column_name = 'familyId') THEN
    ALTER TABLE "care_log_attachments" ADD COLUMN "familyId" uuid;
    RAISE NOTICE 'care_log_attachments.familyId 列已添加';
  ELSE
    RAISE NOTICE 'care_log_attachments.familyId 列已存在，跳过';
  END IF;
END $$;

-- 2. 回填：care_log_attachments JOIN care_logs 通过 careLogId 获取 familyId
UPDATE "care_log_attachments" a
SET "familyId" = l."familyId"
FROM "care_logs" l
WHERE a."careLogId" = l.id AND a."familyId" IS NULL;
-- 注意：此时 care_logs.familyId 已是 uuid，JOIN 时类型一致

-- 3. 设为非空（所有现有记录已回填）
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'care_log_attachments' AND column_name = 'familyId' AND is_nullable = 'YES') THEN
    ALTER TABLE "care_log_attachments" ALTER COLUMN "familyId" SET NOT NULL;
    RAISE NOTICE 'care_log_attachments.familyId 已设为 NOT NULL';
  ELSE
    RAISE NOTICE 'care_log_attachments.familyId 已是 NOT NULL，跳过';
  END IF;
END $$;

-- 4. 添加外键约束（附件属于某个家庭）
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_name = 'care_log_attachments' AND constraint_name = 'FK_care_log_attachments_family') THEN
    ALTER TABLE "care_log_attachments" ADD CONSTRAINT "FK_care_log_attachments_family"
      FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE CASCADE;
    RAISE NOTICE 'FK 已添加';
  ELSE
    RAISE NOTICE 'FK 已存在，跳过';
  END IF;
END $$;

-- 5. 添加索引（按家庭查询附件列表）
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE tablename = 'care_log_attachments' AND indexname = 'idx_care_log_attachments_familyId') THEN
    CREATE INDEX "idx_care_log_attachments_familyId" ON "care_log_attachments"("familyId");
    RAISE NOTICE '索引已添加';
  ELSE
    RAISE NOTICE '索引已存在，跳过';
  END IF;
END $$;
