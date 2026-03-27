-- 给 medications 表添加 familyId 列（用于多家庭数据隔离）
-- 1. 添加列（可空，为现有数据回填做准备）
ALTER TABLE "medications" ADD COLUMN "familyId" uuid;

-- 2. 回填：medications JOIN care_recipients 通过 recipientId 获取 familyId
UPDATE "medications" m
SET "familyId" = cr."familyId"
FROM "care_recipients" cr
WHERE m."recipientId" = cr.id AND m."familyId" IS NULL;

-- 3. 设为非空（所有现有记录已回填）
ALTER TABLE "medications" ALTER COLUMN "familyId" SET NOT NULL;

-- 4. 添加外键约束
ALTER TABLE "medications" ADD CONSTRAINT "FK_medications_family"
  FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE CASCADE;

-- 5. 添加索引（按家庭查询药品列表）
CREATE INDEX "idx_medications_familyId" ON "medications"("familyId");

-- 6. 同步更新 medication_logs 的 familyId（medication_logs 通过 medicationId JOIN medications 再 JOIN care_recipients）
-- medication_logs 本身没有 familyId 列，但查询时 JOIN medications → care_recipients 来过滤
-- 不需要加列，因为 service 层通过 recipientId → care_recipients.familyId 过滤
