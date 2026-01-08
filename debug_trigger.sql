-- 调试方案：先禁用触发器，排查问题

-- 1. 暂时禁用触发器
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 2. 清空可能存在的测试数据
TRUNCATE TABLE profiles CASCADE;

-- 3. 检查是否有孤立的用户（auth.users 中存在但 profiles 中不存在）
-- 这个查询会显示所有没有 profile 的用户
SELECT id, email, created_at
FROM auth.users
WHERE id NOT IN (SELECT id FROM profiles);
