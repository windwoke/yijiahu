-- 允许 phone 为 NULL（支持微信登录用户无手机号情况）
-- 微信用户通过 openId 登录，phone 后续通过绑定手机号补充
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'users' AND column_name = 'phone'
    AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE users ALTER COLUMN phone DROP NOT NULL;
  END IF;
END
$$;
