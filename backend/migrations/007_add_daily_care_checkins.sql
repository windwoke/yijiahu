CREATE TABLE daily_care_checkins (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    care_recipient_id     UUID NOT NULL REFERENCES care_recipients(id) ON DELETE CASCADE,
    checkin_date          DATE NOT NULL,
    status                VARCHAR(20) NOT NULL DEFAULT 'normal',
    medication_completed  INT NOT NULL DEFAULT 0,
    medication_total      INT NOT NULL DEFAULT 0,
    special_note          VARCHAR(500),
    checked_in_by_id      UUID REFERENCES users(id),
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(care_recipient_id, checkin_date)
);
CREATE INDEX idx_daily_care_checkins_recipient_date ON daily_care_checkins(care_recipient_id, checkin_date);
