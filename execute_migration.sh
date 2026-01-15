#!/bin/bash

# 附近玩家检测系统 - 数据库迁移执行脚本
# 使用方法：在 Supabase Dashboard SQL Editor 中直接粘贴运行

cat << 'EOF'

请按以下步骤操作：

1. 打开浏览器访问：
   https://supabase.com/dashboard/project/dzfylsyvnskzvpwomcim/sql

2. 点击 "New query" 按钮

3. 粘贴以下完整 SQL 脚本并点击 "Run"：

EOF

cat /Users/xinyao/Desktop/EarthLord/supabase/migrations/user_locations.sql

cat << 'EOF'

---
执行完成后，您应该看到：
✅ "Success. No rows returned" 消息
✅ 左侧 Table Editor 中出现 user_locations 表
✅ Database → Functions 中出现 2 个新函数

如有错误，请将错误信息发送给 Claude。
EOF
