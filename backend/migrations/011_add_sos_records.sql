-- SOS 紧急求助记录表
CREATE TABLE sos_records (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id           UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    recipient_id        UUID REFERENCES care_recipients(id) ON DELETE SET NULL,
    triggered_by_id    UUID NOT NULL REFERENCES users(id),
    latitude            DECIMAL(10, 7),
    longitude           DECIMAL(10, 7),
    address             VARCHAR(300),
    status              VARCHAR(20) DEFAULT 'active',
    acknowledged_by_id  UUID REFERENCES users(id),
    acknowledged_at     TIMESTAMPTZ,
    resolved_at         TIMESTAMPTZ,
    cancelled_at        TIMESTAMPTZ,
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX "idx_sos_records_family" ON sos_records("family_id");
CREATE INDEX "idx_sos_records_status" ON sos_records("status");
CREATE INDEX "idx_sos_records_time" ON sos_records("created_at" DESC);
