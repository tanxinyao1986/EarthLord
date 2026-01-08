-- ============================================
-- Day 18-地图显示 UUID 验证脚本
-- ============================================
-- 用于验证 UUID 大小写问题

-- ============================================
-- 1. 查看所有用户的 UUID（小写）
-- ============================================
SELECT
    '用户 UUID（auth.users）' as category,
    id::text as user_id_lower,
    UPPER(id::text) as user_id_upper,
    email
FROM auth.users
ORDER BY created_at DESC
LIMIT 5;

-- ============================================
-- 2. 查看领地的 user_id（小写）
-- ============================================
SELECT
    '领地 user_id（territories）' as category,
    user_id as user_id_lower,
    UPPER(user_id) as user_id_upper,
    area,
    created_at
FROM territories
WHERE is_active = true
ORDER BY created_at DESC
LIMIT 5;

-- ============================================
-- 3. 验证大小写比较
-- ============================================

-- 测试：直接比较（会失败）
SELECT
    '直接比较测试' as test_name,
    t.user_id as territory_user_id,
    u.id::text as auth_user_id,
    t.user_id = u.id::text as direct_match,  -- ❌ 应该是 false（如果大小写不同）
    LOWER(t.user_id) = LOWER(u.id::text) as lowercase_match  -- ✅ 应该是 true
FROM territories t
JOIN auth.users u ON LOWER(t.user_id) = LOWER(u.id::text)
LIMIT 5;

-- ============================================
-- 4. 统计不同大小写格式的数量
-- ============================================

-- 检查 user_id 是否全是小写
SELECT
    '大小写检查' as category,
    COUNT(*) as total,
    COUNT(CASE WHEN user_id = LOWER(user_id) THEN 1 END) as lowercase_count,
    COUNT(CASE WHEN user_id = UPPER(user_id) THEN 1 END) as uppercase_count,
    COUNT(CASE WHEN user_id != LOWER(user_id) AND user_id != UPPER(user_id) THEN 1 END) as mixed_count
FROM territories;

-- ============================================
-- 5. 查找可能的颜色错误案例
-- ============================================

-- 模拟 iOS 的 UUID 比较（大写）
-- 这会显示哪些领地会被错误识别为"他人领地"
SELECT
    t.id,
    t.user_id as db_user_id,  -- 数据库中的小写
    u.id::text as auth_user_id,  -- 认证表中的小写
    UPPER(u.id::text) as ios_user_id,  -- iOS 返回的大写
    t.user_id = UPPER(u.id::text) as wrong_comparison,  -- ❌ 错误比较（会返回 false）
    LOWER(t.user_id) = LOWER(UPPER(u.id::text)) as correct_comparison,  -- ✅ 正确比较（会返回 true）
    CASE
        WHEN t.user_id = UPPER(u.id::text) THEN '绿色（错误实现）'
        WHEN LOWER(t.user_id) = LOWER(UPPER(u.id::text)) THEN '橙色（错误实现）→ 应该是绿色'
        ELSE '他人领地（橙色）'
    END as expected_color_if_no_lowercase
FROM territories t
JOIN auth.users u ON LOWER(t.user_id) = LOWER(u.id::text)
WHERE t.is_active = true
ORDER BY t.created_at DESC
LIMIT 5;

-- ============================================
-- 6. 验证当前实现是否正确
-- ============================================

-- 这个查询模拟正确的实现（使用 lowercased()）
SELECT
    '正确实现验证' as test_name,
    t.id,
    t.area,
    LOWER(t.user_id) = LOWER(UPPER(u.id::text)) as is_mine,
    CASE
        WHEN LOWER(t.user_id) = LOWER(UPPER(u.id::text)) THEN '✅ 绿色（我的领地）'
        ELSE '🟠 橙色（他人领地）'
    END as expected_color
FROM territories t
JOIN auth.users u ON LOWER(t.user_id) = LOWER(u.id::text)
WHERE t.is_active = true
ORDER BY t.created_at DESC
LIMIT 10;

-- ============================================
-- 7. 快速诊断查询
-- ============================================

-- 如果您的领地显示为橙色，运行这个查询来诊断
WITH user_info AS (
    SELECT id::text as user_id FROM auth.users LIMIT 1
)
SELECT
    '诊断结果' as category,
    t.user_id as db_user_id,
    u.user_id as auth_user_id,
    UPPER(u.user_id) as ios_would_return,
    t.user_id = UPPER(u.user_id) as direct_comparison_result,
    LOWER(t.user_id) = LOWER(UPPER(u.user_id)) as correct_comparison_result,
    CASE
        WHEN t.user_id = UPPER(u.user_id) THEN '❌ 问题：没有使用 lowercased()'
        WHEN LOWER(t.user_id) = LOWER(UPPER(u.user_id)) THEN '✅ 正常：使用了 lowercased()'
        ELSE '⚠️ 其他问题'
    END as diagnosis
FROM territories t
CROSS JOIN user_info u
WHERE t.is_active = true
ORDER BY t.created_at DESC
LIMIT 5;
