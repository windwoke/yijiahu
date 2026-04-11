-- 017: 将过期的 pending 用药记录标记为 missed
-- 规则：scheduledDate(UTC 0点) + scheduledTime(北京时间的小时) < 当前北京时间 的 pending 记录

DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN
        SELECT ml.id, ml."scheduledDate", ml."scheduledTime"
        FROM medication_logs ml
        WHERE ml.status = 'pending'
    LOOP
        -- 构造 scheduled 北京时间：scheduledDate(UTC 0点) + scheduledTime 小时 + 8小时(UTC偏移)
        -- scheduledDate 存的是 UTC 0点 (=北京时间 8:00)，加上 scheduledTime 的小时即北京时间
        DECLARE
            v_scheduled_ts TIMESTAMP;
            v_now TIMESTAMP;
            v_hour INT := CAST(SPLIT_PART(rec."scheduledTime", ':', 1) AS INT);
            v_minute INT := CAST(SPLIT_PART(rec."scheduledTime", ':', 2) AS INT);
        BEGIN
            v_scheduled_ts := rec."scheduledDate" + (v_hour || ' hours')::INTERVAL + (v_minute || ' minutes')::INTERVAL + '8 hours'::INTERVAL;
            v_now := NOW() AT TIME ZONE 'Asia/Shanghai';
            IF v_scheduled_ts < v_now THEN
                UPDATE medication_logs SET status = 'missed' WHERE id = rec.id;
            END IF;
        END;
    END LOOP;
END $$;

-- 验证结果
DO $$
BEGIN
    RAISE NOTICE 'Missed logs updated successfully. Pending remaining: %', (SELECT COUNT(*) FROM medication_logs WHERE status = 'pending');
END $$;
