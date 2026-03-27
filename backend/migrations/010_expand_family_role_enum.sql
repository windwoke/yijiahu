-- 009_expand_family_role_enum.sql
-- 扩展 family_members role 枚举为 4 级角色体系

-- 添加新枚举值
ALTER TYPE family_members_role_enum ADD VALUE IF NOT EXISTS 'coordinator';
ALTER TYPE family_members_role_enum ADD VALUE IF NOT EXISTS 'caregiver';
ALTER TYPE family_members_role_enum ADD VALUE IF NOT EXISTS 'guest';

-- 清理旧枚举值（如果存在）
-- admin → coordinator（权限相近）
UPDATE family_members SET role = 'coordinator' WHERE role = 'admin';
ALTER TYPE family_members_role_enum DROP VALUE IF EXISTS 'admin';

-- member → coordinator（新成员默认成为协调管理员）
UPDATE family_members SET role = 'coordinator' WHERE role = 'member';
ALTER TYPE family_members_role_enum DROP VALUE IF EXISTS 'member';

-- viewer → guest
UPDATE family_members SET role = 'guest' WHERE role = 'viewer';
ALTER TYPE family_members_role_enum DROP VALUE IF EXISTS 'viewer';
