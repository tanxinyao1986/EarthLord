-- ============================================
-- Day 18-上传 验证脚本
-- ============================================
-- 用于验证领地上传功能是否正常工作

-- ============================================
-- 1. 查看最新上传的领地
-- ============================================
SELECT
    id,
    user_id,
    name,
    area,
    point_count,
    is_active,
    created_at,
    started_at
FROM territories
ORDER BY created_at DESC
LIMIT 5;

-- ============================================
-- 2. 检查是否有重复上传（相同用户、相似时间、相同面积）
-- ============================================
SELECT
    user_id,
    area,
    point_count,
    COUNT(*) as upload_count,
    MIN(created_at) as first_upload,
    MAX(created_at) as last_upload,
    MAX(created_at) - MIN(created_at) as time_diff
FROM territories
GROUP BY user_id, area, point_count
HAVING COUNT(*) > 1
ORDER BY MAX(created_at) DESC;

-- ============================================
-- 3. 验证数据完整性
-- ============================================

-- 3.1 检查 name 字段（应该都是 NULL，因为没有传）
SELECT
    id,
    area,
    name,
    CASE
        WHEN name IS NULL THEN '✅ NULL (正确)'
        ELSE '❌ 有值 (异常)'
    END as name_status
FROM territories
ORDER BY created_at DESC
LIMIT 5;

-- 3.2 检查必填字段是否都有值
SELECT
    id,
    CASE WHEN user_id IS NOT NULL THEN '✅' ELSE '❌' END as user_id_status,
    CASE WHEN path IS NOT NULL THEN '✅' ELSE '❌' END as path_status,
    CASE WHEN area > 0 THEN '✅' ELSE '❌' END as area_status,
    CASE WHEN point_count > 0 THEN '✅' ELSE '❌' END as point_count_status,
    area,
    point_count,
    created_at
FROM territories
ORDER BY created_at DESC
LIMIT 5;

-- 3.3 检查 polygon 和 bbox 字段
SELECT
    id,
    area,
    CASE WHEN polygon IS NOT NULL THEN '✅ 有 WKT' ELSE '❌ 无 WKT' END as polygon_status,
    CASE
        WHEN bbox_min_lat IS NOT NULL AND bbox_max_lat IS NOT NULL
        AND bbox_min_lon IS NOT NULL AND bbox_max_lon IS NOT NULL
        THEN '✅ 完整'
        ELSE '❌ 不完整'
    END as bbox_status,
    bbox_min_lat,
    bbox_max_lat,
    bbox_min_lon,
    bbox_max_lon
FROM territories
ORDER BY created_at DESC
LIMIT 5;

-- ============================================
-- 4. 统计信息
-- ============================================

-- 4.1 总领地数
SELECT
    '总领地数' as metric,
    COUNT(*) as value
FROM territories;

-- 4.2 今天上传的领地数
SELECT
    '今天上传数' as metric,
    COUNT(*) as value
FROM territories
WHERE created_at >= CURRENT_DATE;

-- 4.3 活跃领地数
SELECT
    '活跃领地数' as metric,
    COUNT(*) as value
FROM territories
WHERE is_active = true;

-- 4.4 面积统计
SELECT
    '面积统计' as category,
    MIN(area) as min_area,
    MAX(area) as max_area,
    AVG(area) as avg_area,
    COUNT(*) as total_count
FROM territories;

-- ============================================
-- 5. 检查 path 格式是否正确
-- ============================================
SELECT
    id,
    area,
    point_count,
    jsonb_array_length(path) as path_array_length,
    CASE
        WHEN jsonb_array_length(path) = point_count THEN '✅ 一致'
        ELSE '❌ 不一致'
    END as length_check,
    path->0 as first_point_sample,
    created_at
FROM territories
ORDER BY created_at DESC
LIMIT 3;
