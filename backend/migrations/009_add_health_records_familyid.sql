ALTER TABLE "health_records" ADD COLUMN "familyId" uuid;
UPDATE "health_records" hr SET "familyId" = cr."familyId"
  FROM "care_recipients" cr WHERE hr."recipientId" = cr.id AND hr."familyId" IS NULL;
ALTER TABLE "health_records" ALTER COLUMN "familyId" SET NOT NULL;
ALTER TABLE "health_records" ADD CONSTRAINT "FK_health_records_family"
  FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE CASCADE;
CREATE INDEX "idx_health_records_familyId" ON "health_records"("familyId");
