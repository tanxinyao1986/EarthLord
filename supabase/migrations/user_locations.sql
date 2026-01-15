-- ============================================
-- 附近玩家检测系统数据库迁移脚本
-- 版本: v1.0
-- 日期: 2026-01-14
-- 描述: 创建用户位置表、RPC函数和RLS策略
-- ============================================

-- 启用PostGIS扩展（如果尚未启用）
CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================
-- 1. 创建用户位置表
-- ============================================
CREATE TABLE IF NOT EXISTS public.user_locations (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    location geography(Point, 4326) NOT NULL,  -- PostGIS地理点 (经度, 纬度)
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    accuracy double precision,  -- GPS精度（米）
    reported_at timestamptz NOT NULL DEFAULT now(),
    is_online boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),

    CONSTRAINT user_locations_pkey PRIMARY KEY (id),
    CONSTRAINT user_locations_user_id_fkey FOREIGN KEY (user_id)
        REFERENCES auth.users(id) ON DELETE CASCADE
);

-- ============================================
-- 2. 创建索引
-- ============================================

-- 用户ID索引（快速查找用户位置）
CREATE INDEX IF NOT EXISTS user_locations_user_id_idx
ON public.user_locations(user_id);

-- 上报时间索引（判断在线状态）
CREATE INDEX IF NOT EXISTS user_locations_reported_at_idx
ON public.user_locations(reported_at DESC);

-- 在线状态索引（过滤在线玩家）
CREATE INDEX IF NOT EXISTS user_locations_is_online_idx
ON public.user_locations(is_online)
WHERE is_online = true;

-- PostGIS空间索引（核心性能优化，支持高效范围查询）
CREATE INDEX IF NOT EXISTS user_locations_location_idx
ON public.user_locations USING GIST(location);

-- 唯一约束：每个用户只保留一条最新记录（用于Upsert）
CREATE UNIQUE INDEX IF NOT EXISTS user_locations_user_id_unique
ON public.user_locations(user_id);

-- ============================================
-- 3. RPC函数：上报用户位置（Upsert）
-- ============================================
CREATE OR REPLACE FUNCTION upsert_user_location(
    p_user_id uuid,
    p_latitude double precision,
    p_longitude double precision,
    p_accuracy double precision DEFAULT NULL,
    p_is_online boolean DEFAULT true
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_location geography;
BEGIN
    -- 创建PostGIS Point (注意：经度在前，纬度在后)
    v_location := ST_SetSRID(
        ST_MakePoint(p_longitude, p_latitude),
        4326
    )::geography;

    -- Upsert：存在则更新，不存在则插入
    INSERT INTO public.user_locations (
        user_id,
        location,
        latitude,
        longitude,
        accuracy,
        is_online,
        reported_at,
        updated_at
    )
    VALUES (
        p_user_id,
        v_location,
        p_latitude,
        p_longitude,
        p_accuracy,
        p_is_online,
        now(),
        now()
    )
    ON CONFLICT (user_id)
    DO UPDATE SET
        location = EXCLUDED.location,
        latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude,
        accuracy = EXCLUDED.accuracy,
        is_online = EXCLUDED.is_online,
        reported_at = now(),
        updated_at = now();
END;
$$;

-- 添加函数注释
COMMENT ON FUNCTION upsert_user_location IS '上报用户位置（Upsert策略）：每个用户只保留最新一条记录';

-- ============================================
-- 4. RPC函数：查询附近在线玩家数量
-- ============================================
CREATE OR REPLACE FUNCTION get_nearby_online_players_count(
    p_user_id uuid,
    p_latitude double precision,
    p_longitude double precision,
    p_radius_meters double precision DEFAULT 1000
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_count integer;
    v_center geography;
BEGIN
    -- 创建查询中心点
    v_center := ST_SetSRID(
        ST_MakePoint(p_longitude, p_latitude),
        4326
    )::geography;

    -- 查询附近在线玩家数量
    -- 条件：
    -- 1. 排除自己 (user_id != p_user_id)
    -- 2. 标记为在线 (is_online = true)
    -- 3. 5分钟内有上报 (reported_at > now() - interval '5 minutes')
    -- 4. 在指定半径范围内 (ST_DWithin)
    SELECT COUNT(*)
    INTO v_count
    FROM public.user_locations
    WHERE user_id != p_user_id
      AND is_online = true
      AND reported_at > (now() - interval '5 minutes')
      AND ST_DWithin(location, v_center, p_radius_meters);

    RETURN COALESCE(v_count, 0);
END;
$$;

-- 添加函数注释
COMMENT ON FUNCTION get_nearby_online_players_count IS '查询附近在线玩家数量（5分钟内活跃，默认半径1公里）';

-- ============================================
-- 5. RLS策略（行级安全）
-- ============================================

-- 启用RLS
ALTER TABLE public.user_locations ENABLE ROW LEVEL SECURITY;

-- 策略1：用户只能查看自己的位置记录
DROP POLICY IF EXISTS "用户查看自己位置" ON public.user_locations;
CREATE POLICY "用户查看自己位置"
ON public.user_locations
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- 策略2：用户只能插入/更新自己的位置记录
DROP POLICY IF EXISTS "用户上报自己位置" ON public.user_locations;
CREATE POLICY "用户上报自己位置"
ON public.user_locations
FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 注意：附近玩家查询通过SECURITY DEFINER函数绕过RLS
-- 函数只返回数量，不返回任何位置数据，保护隐私

-- ============================================
-- 6. 授予权限
-- ============================================

-- 授予authenticated角色访问表的权限
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_locations TO authenticated;

-- 授予authenticated角色访问函数的权限
GRANT EXECUTE ON FUNCTION upsert_user_location TO authenticated;
GRANT EXECUTE ON FUNCTION get_nearby_online_players_count TO authenticated;

-- ============================================
-- 7. 测试数据（可选，用于开发测试）
-- ============================================

-- 注释掉，生产环境不需要
-- INSERT INTO public.user_locations (user_id, location, latitude, longitude, is_online)
-- VALUES
--     ('00000000-0000-0000-0000-000000000001'::uuid, ST_SetSRID(ST_MakePoint(116.404, 39.915), 4326)::geography, 39.915, 116.404, true),
--     ('00000000-0000-0000-0000-000000000002'::uuid, ST_SetSRID(ST_MakePoint(116.405, 39.916), 4326)::geography, 39.916, 116.405, true);

-- ============================================
-- 迁移完成
-- ============================================
