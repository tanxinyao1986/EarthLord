-- ============================================
-- Day 18-领地管理 验证脚本
-- ============================================
-- 用于验证领地管理功能的数据库操作

-- ============================================
-- 1. 查看当前用户 ID
-- ============================================
SELECT
    '当前用户信息' as category,
    id::text as user_id,
    email,
    created_at
FROM auth.users
ORDER BY created_at DESC
LIMIT 1;

-- ============================================
-- 2. 查看我的领地列表（删除前）
-- ============================================
-- ⚠️ 请将下面的 'YOUR_USER_ID' 替换为你的实际用户 ID

SELECT
    '我的领地列表（删除前）' as category,
    COUNT(*) as total_count,
    SUM(area) as total_area,
    MIN(area) as min_area,
    MAX(area) as max_area,
    AVG(area) as avg_area
FROM territories
WHERE user_id = 'YOUR_USER_ID'  -- ⚠️ 替换为你的用户 ID
  AND is_active = true;

-- ============================================
-- 3. 查看领地详细列表
-- ============================================
SELECT
    '领地详细信息' as category,
    id,
    name,
    area,
    point_count,
    created_at,
    updated_at
FROM territories
WHERE user_id = 'YOUR_USER_ID'  -- ⚠️ 替换为你的用户 ID
  AND is_active = true
ORDER BY created_at DESC;

-- ============================================
-- 4. 删除后验证（在 App 中删除一个领地后执行）
-- ============================================

-- 4.1 查看删除后的领地数量
SELECT
    '我的领地列表（删除后）' as category,
    COUNT(*) as total_count,
    SUM(area) as total_area
FROM territories
WHERE user_id = 'YOUR_USER_ID'  -- ⚠️ 替换为你的用户 ID
  AND is_active = true;

-- 4.2 验证删除的领地是否还存在（应该找不到）
-- ⚠️ 请将 'DELETED_TERRITORY_ID' 替换为你删除的领地 ID
SELECT
    '验证删除结果' as category,
    id,
    name,
    area,
    is_active,
    created_at
FROM territories
WHERE id = 'DELETED_TERRITORY_ID'  -- ⚠️ 替换为删除的领地 ID
LIMIT 1;

-- 期望结果：
-- - 如果是物理删除：返回 0 行（领地完全删除）
-- - 如果是逻辑删除：返回 1 行，但 is_active = false

-- ============================================
-- 5. 验证删除功能的完整性
-- ============================================

-- 5.1 对比删除前后的数量
WITH before_delete AS (
    -- 这里填写删除前的数量
    SELECT 5 as count  -- ⚠️ 替换为删除前的实际数量
),
after_delete AS (
    SELECT COUNT(*) as count
    FROM territories
    WHERE user_id = 'YOUR_USER_ID'  -- ⚠️ 替换为你的用户 ID
      AND is_active = true
)
SELECT
    '删除功能验证' as category,
    b.count as before_count,
    a.count as after_count,
    b.count - a.count as deleted_count,
    CASE
        WHEN b.count - a.count = 1 THEN '✅ 删除成功（数量减少 1）'
        WHEN b.count - a.count = 0 THEN '❌ 删除失败（数量未变化）'
        ELSE '⚠️ 异常（数量变化不符合预期）'
    END as result
FROM before_delete b, after_delete a;

-- ============================================
-- 6. 验证领地加载查询（模拟 loadMyTerritories）
-- ============================================

-- 这是 TerritoryManager.loadMyTerritories() 执行的查询
SELECT
    '模拟 loadMyTerritories 查询' as category,
    id,
    user_id,
    name,
    path,
    area,
    point_count,
    is_active,
    completed_at,
    started_at,
    created_at
FROM territories
WHERE user_id = 'YOUR_USER_ID'  -- ⚠️ 替换为你的用户 ID
  AND is_active = true
ORDER BY created_at DESC;

-- 期望结果：
-- - 返回当前用户的所有活跃领地
-- - 按创建时间降序排列
-- - 包含所有必要字段

-- ============================================
-- 7. 快速诊断查询
-- ============================================

-- 如果领地管理页面出现问题，运行这个查询来诊断
SELECT
    '快速诊断' as category,
    COUNT(*) as total_territories,
    COUNT(CASE WHEN is_active = true THEN 1 END) as active_territories,
    COUNT(CASE WHEN is_active = false THEN 1 END) as inactive_territories,
    COUNT(CASE WHEN name IS NOT NULL THEN 1 END) as named_territories,
    COUNT(CASE WHEN name IS NULL THEN 1 END) as unnamed_territories,
    SUM(area) as total_area,
    AVG(area) as avg_area,
    MIN(created_at) as earliest_territory,
    MAX(created_at) as latest_territory
FROM territories
WHERE user_id = 'YOUR_USER_ID';  -- ⚠️ 替换为你的用户 ID

-- ============================================
-- 8. 验证字段完整性
-- ============================================

-- 检查是否所有必需字段都有值
SELECT
    '字段完整性检查' as category,
    id,
    name,
    CASE WHEN user_id IS NULL THEN '❌ 缺失' ELSE '✅ 存在' END as user_id_status,
    CASE WHEN path IS NULL THEN '❌ 缺失' ELSE '✅ 存在' END as path_status,
    CASE WHEN area IS NULL THEN '❌ 缺失' ELSE '✅ 存在' END as area_status,
    CASE WHEN point_count IS NULL THEN '⚠️ 可选' ELSE '✅ 存在' END as point_count_status,
    CASE WHEN is_active IS NULL THEN '❌ 缺失' ELSE '✅ 存在' END as is_active_status,
    CASE WHEN created_at IS NULL THEN '❌ 缺失' ELSE '✅ 存在' END as created_at_status
FROM territories
WHERE user_id = 'YOUR_USER_ID'  -- ⚠️ 替换为你的用户 ID
ORDER BY created_at DESC
LIMIT 5;

-- ============================================
-- 9. 性能测试查询
-- ============================================

-- 测试查询性能（如果领地数量很多）
EXPLAIN ANALYZE
SELECT *
FROM territories
WHERE user_id = 'YOUR_USER_ID'  -- ⚠️ 替换为你的用户 ID
  AND is_active = true
ORDER BY created_at DESC;

-- 期望结果：
-- - 应该使用索引（如果有为 user_id 和 is_active 创建索引）
-- - 查询时间应该很短（< 100ms）

-- ============================================
-- 10. 清理测试数据（谨慎使用！）
-- ============================================

-- ⚠️⚠️⚠️ 警告：这会删除你的所有领地！仅用于测试！⚠️⚠️⚠️
-- DELETE FROM territories
-- WHERE user_id = 'YOUR_USER_ID'
--   AND is_active = true;

-- 如果要删除特定领地，使用：
-- DELETE FROM territories
-- WHERE id = 'SPECIFIC_TERRITORY_ID';

-- ============================================
-- 验证完成
-- ============================================

-- 所有查询执行完成后，检查：
-- ✅ 领地列表查询正确
-- ✅ 删除功能正常
-- ✅ 字段完整性正常
-- ✅ 查询性能良好

-- 🎉 Day 18-领地管理 数据库验证完成！
