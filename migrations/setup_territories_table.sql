-- ============================================
-- Day 18: territories 表完整配置
-- ============================================
-- 项目: dzfylsyvnskzvpwomcim
-- 执行顺序: 第零步 → 第一步 → 第二步 → 第三步
-- ============================================

-- ============================================
-- 第一步：启用 PostGIS 扩展
-- ============================================
CREATE EXTENSION IF NOT EXISTS "postgis";


-- ============================================
-- 第二步：检查并补全 territories 表字段
-- ============================================

-- 2.1 创建或修改 territories 表
CREATE TABLE IF NOT EXISTS public.territories (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    name text NULL,  -- ⚠️ 必须是 nullable！
    path jsonb NOT NULL,
    polygon geography(Polygon, 4326) NULL,
    bbox_min_lat double precision NULL,
    bbox_max_lat double precision NULL,
    bbox_min_lon double precision NULL,
    bbox_max_lon double precision NULL,
    area double precision NOT NULL,
    point_count integer NULL,
    started_at timestamptz NULL,
    completed_at timestamptz NULL,
    is_active boolean NULL DEFAULT true,
    created_at timestamptz NULL DEFAULT now(),
    updated_at timestamptz NULL DEFAULT now(),
    CONSTRAINT territories_pkey PRIMARY KEY (id),
    CONSTRAINT territories_user_id_fkey FOREIGN KEY (user_id)
        REFERENCES auth.users(id) ON DELETE CASCADE
);

-- 2.2 如果表已存在，修改字段约束（确保 name 是 nullable）
DO $$
BEGIN
    -- 修改 name 字段为 nullable（如果是 NOT NULL）
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'territories'
        AND column_name = 'name'
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE public.territories ALTER COLUMN name DROP NOT NULL;
        RAISE NOTICE 'name 字段已修改为 nullable';
    END IF;

    -- 添加缺失的字段（如果不存在）
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'territories' AND column_name = 'polygon'
    ) THEN
        ALTER TABLE public.territories ADD COLUMN polygon geography(Polygon, 4326) NULL;
        RAISE NOTICE '已添加 polygon 字段';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'territories' AND column_name = 'bbox_min_lat'
    ) THEN
        ALTER TABLE public.territories
            ADD COLUMN bbox_min_lat double precision NULL,
            ADD COLUMN bbox_max_lat double precision NULL,
            ADD COLUMN bbox_min_lon double precision NULL,
            ADD COLUMN bbox_max_lon double precision NULL;
        RAISE NOTICE '已添加 bbox 字段';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'territories' AND column_name = 'point_count'
    ) THEN
        ALTER TABLE public.territories ADD COLUMN point_count integer NULL;
        RAISE NOTICE '已添加 point_count 字段';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'territories' AND column_name = 'started_at'
    ) THEN
        ALTER TABLE public.territories
            ADD COLUMN started_at timestamptz NULL,
            ADD COLUMN completed_at timestamptz NULL;
        RAISE NOTICE '已添加时间戳字段';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'territories' AND column_name = 'is_active'
    ) THEN
        ALTER TABLE public.territories ADD COLUMN is_active boolean NULL DEFAULT true;
        RAISE NOTICE '已添加 is_active 字段';
    END IF;
END $$;

-- 2.3 创建索引以提高查询性能
CREATE INDEX IF NOT EXISTS territories_user_id_idx ON public.territories(user_id);
CREATE INDEX IF NOT EXISTS territories_is_active_idx ON public.territories(is_active);
CREATE INDEX IF NOT EXISTS territories_created_at_idx ON public.territories(created_at DESC);

-- 2.4 创建空间索引（如果使用 PostGIS）
CREATE INDEX IF NOT EXISTS territories_polygon_idx ON public.territories USING GIST(polygon);


-- ============================================
-- 第三步：配置 RLS 策略
-- ============================================

-- 3.1 启用 RLS
ALTER TABLE public.territories ENABLE ROW LEVEL SECURITY;

-- 3.2 删除现有策略（如果存在）
DROP POLICY IF EXISTS "所有人可以查看领地" ON public.territories;
DROP POLICY IF EXISTS "用户可以创建自己的领地" ON public.territories;
DROP POLICY IF EXISTS "用户可以删除自己的领地" ON public.territories;
DROP POLICY IF EXISTS "用户可以更新自己的领地" ON public.territories;

-- 3.3 创建新策略

-- 策略 1：所有人可以查看所有领地
CREATE POLICY "所有人可以查看领地"
ON public.territories
FOR SELECT
TO authenticated
USING (true);

-- 策略 2：用户只能创建自己的领地
CREATE POLICY "用户可以创建自己的领地"
ON public.territories
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- 策略 3：用户只能删除自己的领地
CREATE POLICY "用户可以删除自己的领地"
ON public.territories
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- 策略 4：用户只能更新自己的领地
CREATE POLICY "用户可以更新自己的领地"
ON public.territories
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);


-- ============================================
-- 验证配置
-- ============================================

-- 显示表结构
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'territories'
ORDER BY ordinal_position;

-- 显示 RLS 策略
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'territories';
