-- 010_expand_family_role_enum.sql
-- 扩展 family_members role 枚举为 4 级角色体系（幂等版本）
-- 角色: owner(管理员) / coordinator(协调管理员) / caregiver(照护人) / guest(访客)

-- 添加新枚举值（如果已存在则跳过）
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'coordinator') THEN
    ALTER TYPE family_members_role_enum ADD VALUE 'coordinator';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'caregiver') THEN
    ALTER TYPE family_members_role_enum ADD VALUE 'caregiver';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'guest') THEN
    ALTER TYPE family_members_role_enum ADD VALUE 'guest';
  END IF;
END
$$;

-- 清理旧枚举值（需在事务外单独执行）
-- 旧角色迁移（admin → coordinator, member → coordinator, viewer → guest）
-- 注意: DROP VALUE 需要在事务外单独执行，如果旧值不存在会报错
-- 以下为注释记录，迁移逻辑由后端 FamilyService 的 join() 方法处理新成员默认角色
