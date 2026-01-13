-- ============================================
-- 行走探索奖励功能 - 数据库表结构
-- ============================================
-- 执行顺序：按照注释顺序依次执行
-- ============================================

-- ============================================
-- 第一步：创建 item_definitions 表（物品定义）
-- ============================================

CREATE TABLE IF NOT EXISTS public.item_definitions (
    id text NOT NULL,
    name text NOT NULL,
    category text NOT NULL,
    weight double precision NOT NULL DEFAULT 0,
    volume double precision NOT NULL DEFAULT 0,
    rarity text NOT NULL DEFAULT 'common',
    description text,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    CONSTRAINT item_definitions_pkey PRIMARY KEY (id),
    CONSTRAINT item_definitions_category_check CHECK (category IN ('water', 'food', 'medical', 'material', 'tool')),
    CONSTRAINT item_definitions_rarity_check CHECK (rarity IN ('common', 'uncommon', 'rare', 'epic'))
);

-- 创建索引
CREATE INDEX IF NOT EXISTS item_definitions_category_idx ON public.item_definitions(category);
CREATE INDEX IF NOT EXISTS item_definitions_rarity_idx ON public.item_definitions(rarity);

-- RLS 策略
ALTER TABLE public.item_definitions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "所有人可以查看物品定义" ON public.item_definitions;
CREATE POLICY "所有人可以查看物品定义"
ON public.item_definitions
FOR SELECT
TO authenticated
USING (true);

-- ============================================
-- 第二步：插入物品定义数据
-- ============================================

INSERT INTO public.item_definitions (id, name, category, weight, volume, rarity, description) VALUES
-- 普通物品 (common)
('water_mineral', '矿泉水', 'water', 0.5, 0.5, 'common', '瓶装纯净水，末日前的产品，仍可安全饮用'),
('food_canned', '罐头食品', 'food', 0.4, 0.3, 'common', '密封罐头，保质期长，是珍贵的食物来源'),
('food_biscuit', '饼干', 'food', 0.2, 0.2, 'common', '高热量饼干，便于携带'),
('medical_bandage', '绷带', 'medical', 0.05, 0.1, 'common', '医用绷带，可以包扎伤口'),
('material_wood', '木材', 'material', 2.0, 5.0, 'common', '可用于建造和修复的木材'),
('tool_rope', '绳子', 'tool', 1.0, 1.5, 'common', '尼龙绳，多种用途'),
('tool_matches', '火柴', 'tool', 0.02, 0.01, 'common', '一盒火柴，生火必备'),

-- 罕见物品 (uncommon)
('medical_medicine', '药品', 'medical', 0.1, 0.05, 'uncommon', '各类常用药品，在末日中价值极高'),
('material_metal', '废金属', 'material', 3.0, 2.0, 'uncommon', '废弃的金属零件，可以回收利用'),
('tool_flashlight', '手电筒', 'tool', 0.3, 0.2, 'uncommon', 'LED手电筒，夜间探索的必需品'),
('water_purified', '净化水', 'water', 0.6, 0.5, 'uncommon', '经过净化处理的饮用水'),
('food_ration', '军粮', 'food', 0.3, 0.2, 'uncommon', '高热量军用口粮'),

-- 稀有物品 (rare)
('food_energy_bar', '能量棒', 'food', 0.1, 0.05, 'rare', '高热量能量补充食品'),
('medical_medkit', '急救包', 'medical', 0.5, 0.3, 'rare', '完整的急救包，可处理严重伤口'),
('tool_compass', '指南针', 'tool', 0.05, 0.02, 'rare', '末日后导航的必备工具'),
('tool_radio', '收音机', 'tool', 0.4, 0.3, 'rare', '可接收紧急广播的收音机'),

-- 史诗物品 (epic)
('material_electronic', '电子元件', 'material', 0.2, 0.1, 'epic', '稀有的电子零件，可用于修复设备'),
('medical_antibiotic', '抗生素', 'medical', 0.15, 0.08, 'epic', '珍贵的抗生素，治疗感染的特效药'),
('tool_generator_part', '发电机零件', 'tool', 1.5, 1.0, 'epic', '发电机的关键零件'),
('food_preserved', '特供食品', 'food', 0.5, 0.4, 'epic', '保存完好的高级食品')
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category,
    weight = EXCLUDED.weight,
    volume = EXCLUDED.volume,
    rarity = EXCLUDED.rarity,
    description = EXCLUDED.description;

-- ============================================
-- 第三步：创建 inventory_items 表（背包物品）
-- ============================================

CREATE TABLE IF NOT EXISTS public.inventory_items (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    item_id text NOT NULL,
    quantity integer NOT NULL DEFAULT 1,
    quality double precision,
    acquired_at timestamptz DEFAULT now(),
    exploration_session_id uuid,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    CONSTRAINT inventory_items_pkey PRIMARY KEY (id),
    CONSTRAINT inventory_items_user_id_fkey FOREIGN KEY (user_id)
        REFERENCES auth.users(id) ON DELETE CASCADE,
    CONSTRAINT inventory_items_item_id_fkey FOREIGN KEY (item_id)
        REFERENCES public.item_definitions(id) ON DELETE CASCADE,
    CONSTRAINT inventory_items_quantity_check CHECK (quantity > 0)
);

-- 创建索引
CREATE INDEX IF NOT EXISTS inventory_items_user_id_idx ON public.inventory_items(user_id);
CREATE INDEX IF NOT EXISTS inventory_items_item_id_idx ON public.inventory_items(item_id);
CREATE INDEX IF NOT EXISTS inventory_items_acquired_at_idx ON public.inventory_items(acquired_at DESC);

-- RLS 策略
ALTER TABLE public.inventory_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "用户查看自己背包" ON public.inventory_items;
DROP POLICY IF EXISTS "用户添加物品" ON public.inventory_items;
DROP POLICY IF EXISTS "用户更新物品" ON public.inventory_items;
DROP POLICY IF EXISTS "用户删除物品" ON public.inventory_items;

CREATE POLICY "用户查看自己背包"
ON public.inventory_items
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "用户添加物品"
ON public.inventory_items
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "用户更新物品"
ON public.inventory_items
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "用户删除物品"
ON public.inventory_items
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- ============================================
-- 第四步：创建 exploration_sessions 表（探索记录）
-- ============================================

CREATE TABLE IF NOT EXISTS public.exploration_sessions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    started_at timestamptz NOT NULL,
    ended_at timestamptz,
    duration_seconds integer,
    distance_walked double precision NOT NULL DEFAULT 0,
    reward_tier text,
    items_found jsonb,
    experience_gained integer DEFAULT 0,
    status text NOT NULL DEFAULT 'in_progress',
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    CONSTRAINT exploration_sessions_pkey PRIMARY KEY (id),
    CONSTRAINT exploration_sessions_user_id_fkey FOREIGN KEY (user_id)
        REFERENCES auth.users(id) ON DELETE CASCADE,
    CONSTRAINT exploration_sessions_status_check CHECK (status IN ('in_progress', 'completed', 'cancelled', 'failed')),
    CONSTRAINT exploration_sessions_tier_check CHECK (reward_tier IS NULL OR reward_tier IN ('none', 'bronze', 'silver', 'gold', 'diamond'))
);

-- 创建索引
CREATE INDEX IF NOT EXISTS exploration_sessions_user_id_idx ON public.exploration_sessions(user_id);
CREATE INDEX IF NOT EXISTS exploration_sessions_status_idx ON public.exploration_sessions(status);
CREATE INDEX IF NOT EXISTS exploration_sessions_created_at_idx ON public.exploration_sessions(created_at DESC);

-- RLS 策略
ALTER TABLE public.exploration_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "用户查看自己探索记录" ON public.exploration_sessions;
DROP POLICY IF EXISTS "用户创建探索记录" ON public.exploration_sessions;
DROP POLICY IF EXISTS "用户更新探索记录" ON public.exploration_sessions;

CREATE POLICY "用户查看自己探索记录"
ON public.exploration_sessions
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "用户创建探索记录"
ON public.exploration_sessions
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "用户更新探索记录"
ON public.exploration_sessions
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- ============================================
-- 验证：查看已创建的表
-- ============================================

-- 查看 item_definitions 表结构
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'item_definitions'
ORDER BY ordinal_position;

-- 查看已插入的物品数量
SELECT rarity, COUNT(*) as count
FROM public.item_definitions
GROUP BY rarity
ORDER BY
    CASE rarity
        WHEN 'common' THEN 1
        WHEN 'uncommon' THEN 2
        WHEN 'rare' THEN 3
        WHEN 'epic' THEN 4
    END;
