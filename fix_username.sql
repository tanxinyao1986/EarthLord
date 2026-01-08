-- 修复用户名问题：允许 username 为空
-- 用户可以在 App 中稍后设置用户名

-- 1. 修改 profiles 表，允许 username 为 NULL
ALTER TABLE profiles ALTER COLUMN username DROP NOT NULL;

-- 2. 更新触发器函数，使用完整 UUID 作为默认用户名
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, username, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(
            NEW.raw_user_meta_data->>'username',
            'user_' || replace(NEW.id::text, '-', '')
        ),
        NEW.raw_user_meta_data->>'avatar_url'
    );
    RETURN NEW;
EXCEPTION
    WHEN unique_violation THEN
        -- 如果用户名冲突，使用 NULL
        INSERT INTO profiles (id, username, avatar_url)
        VALUES (NEW.id, NULL, NEW.raw_user_meta_data->>'avatar_url');
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
