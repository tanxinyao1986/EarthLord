-- ============================================
-- 地球新主 (EarthLord) 数据库迁移脚本 V2
-- 可安全重复执行
-- ============================================

-- 1. 创建 profiles 表（用户资料）
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 为 profiles 表创建索引
CREATE INDEX IF NOT EXISTS idx_profiles_username ON profiles(username);

-- 启用 profiles 表的 RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- 删除旧策略（如果存在）
DROP POLICY IF EXISTS "用户可以查看所有资料" ON profiles;
DROP POLICY IF EXISTS "允许系统创建用户资料" ON profiles;
DROP POLICY IF EXISTS "用户只能更新自己的资料" ON profiles;

-- 创建新策略
CREATE POLICY "用户可以查看所有资料"
    ON profiles FOR SELECT
    USING (true);

CREATE POLICY "允许系统创建用户资料"
    ON profiles FOR INSERT
    WITH CHECK (true);

CREATE POLICY "用户只能更新自己的资料"
    ON profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- ============================================

-- 2. 创建 territories 表（领地）
CREATE TABLE IF NOT EXISTS territories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    path JSONB NOT NULL,
    area NUMERIC NOT NULL CHECK (area > 0),
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 为 territories 表创建索引
CREATE INDEX IF NOT EXISTS idx_territories_user_id ON territories(user_id);
CREATE INDEX IF NOT EXISTS idx_territories_created_at ON territories(created_at DESC);

-- 启用 territories 表的 RLS
ALTER TABLE territories ENABLE ROW LEVEL SECURITY;

-- 删除旧策略
DROP POLICY IF EXISTS "用户可以查看所有领地" ON territories;
DROP POLICY IF EXISTS "用户只能插入自己的领地" ON territories;
DROP POLICY IF EXISTS "用户只能更新自己的领地" ON territories;
DROP POLICY IF EXISTS "用户只能删除自己的领地" ON territories;

-- 创建新策略
CREATE POLICY "用户可以查看所有领地"
    ON territories FOR SELECT
    USING (true);

CREATE POLICY "用户只能插入自己的领地"
    ON territories FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "用户只能更新自己的领地"
    ON territories FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "用户只能删除自己的领地"
    ON territories FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================

-- 3. 创建 pois 表（兴趣点）
CREATE TABLE IF NOT EXISTS pois (
    id TEXT PRIMARY KEY,
    poi_type TEXT NOT NULL CHECK (poi_type IN ('hospital', 'supermarket', 'factory', 'park', 'bank', 'school', 'restaurant')),
    name TEXT NOT NULL,
    latitude NUMERIC NOT NULL CHECK (latitude >= -90 AND latitude <= 90),
    longitude NUMERIC NOT NULL CHECK (longitude >= -180 AND longitude <= 180),
    discovered_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    discovered_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 为 pois 表创建索引
CREATE INDEX IF NOT EXISTS idx_pois_poi_type ON pois(poi_type);
CREATE INDEX IF NOT EXISTS idx_pois_discovered_by ON pois(discovered_by);
CREATE INDEX IF NOT EXISTS idx_pois_location ON pois(latitude, longitude);

-- 启用 pois 表的 RLS
ALTER TABLE pois ENABLE ROW LEVEL SECURITY;

-- 删除旧策略
DROP POLICY IF EXISTS "所有人可以查看兴趣点" ON pois;
DROP POLICY IF EXISTS "认证用户可以发现新兴趣点" ON pois;
DROP POLICY IF EXISTS "发现者可以更新兴趣点" ON pois;

-- 创建新策略
CREATE POLICY "所有人可以查看兴趣点"
    ON pois FOR SELECT
    USING (true);

CREATE POLICY "认证用户可以发现新兴趣点"
    ON pois FOR INSERT
    WITH CHECK (auth.uid() = discovered_by);

CREATE POLICY "发现者可以更新兴趣点"
    ON pois FOR UPDATE
    USING (auth.uid() = discovered_by)
    WITH CHECK (auth.uid() = discovered_by);

-- ============================================

-- 4. 创建触发器：自动创建用户资料
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, username, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'username', 'user_' || substr(NEW.id::text, 1, 8)),
        NEW.raw_user_meta_data->>'avatar_url'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建触发器
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();

-- ============================================

-- 5. 创建辅助函数：计算两点之间的距离（米）
CREATE OR REPLACE FUNCTION calculate_distance(
    lat1 NUMERIC,
    lon1 NUMERIC,
    lat2 NUMERIC,
    lon2 NUMERIC
)
RETURNS NUMERIC AS $$
DECLARE
    earth_radius CONSTANT NUMERIC := 6371000;
    dlat NUMERIC;
    dlon NUMERIC;
    a NUMERIC;
    c NUMERIC;
BEGIN
    dlat := radians(lat2 - lat1);
    dlon := radians(lon2 - lon1);
    a := sin(dlat/2) * sin(dlat/2) +
         cos(radians(lat1)) * cos(radians(lat2)) *
         sin(dlon/2) * sin(dlon/2);
    c := 2 * atan2(sqrt(a), sqrt(1-a));
    RETURN earth_radius * c;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
