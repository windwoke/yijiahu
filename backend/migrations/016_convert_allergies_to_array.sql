-- 确认 allergies 和 chronicConditions 列为 text 类型（TypeORM simple-array 使用 text 列存储）
-- 现有数据为空，无需数据迁移
-- TypeORM 会自动把 string[] 序列化为逗号分隔字符串存入 text 列
DO $$
BEGIN
  -- 确保列存在（幂等）
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'care_recipients' AND column_name = 'allergies'
  ) THEN
    ALTER TABLE care_recipients ADD COLUMN allergies text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'care_recipients' AND column_name = 'chronicConditions'
  ) THEN
    ALTER TABLE care_recipients ADD COLUMN "chronicConditions" text;
  END IF;
END
$$;
