CREATE TABLE caregiver_records (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    care_recipient_id    UUID NOT NULL REFERENCES care_recipients(id) ON DELETE CASCADE,
    caregiver_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    period_start         DATE NOT NULL,
    period_end           DATE,
    note                 VARCHAR(500),
    created_by_id        UUID REFERENCES users(id),
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    updated_at           TIMESTAMPTZ DEFAULT NOW(),
    deleted_at           TIMESTAMPTZ
);
CREATE INDEX idx_caregiver_records_recipient ON caregiver_records(care_recipient_id);
