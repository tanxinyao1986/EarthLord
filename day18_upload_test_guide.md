# Day 18-上传 测试指南

## 📱 实机测试步骤

### 前置准备

1. **确保已登录**
   - 打开 App，确认已登录账号
   - 查看 Profile 页面，确认用户信息

2. **确保定位权限**
   - 设置 → 隐私 → 定位服务 → EarthLord → "使用期间"

3. **查看数据库当前状态**
   - 在 Supabase SQL Editor 执行：
   ```sql
   SELECT COUNT(*) FROM territories;
   ```
   - 记录当前总数：`____` 条

---

## 🧪 场景 1：验证失败（面积不足）

### 操作步骤

1. 打开 App，进入地图页面
2. 点击"开始圈地"按钮
3. 在原地走一个很小的圈：
   - 向前走 3 米
   - 右转 90 度
   - 向前走 3 米
   - 右转 90 度
   - 向前走 3 米
   - 右转 90 度
   - 回到起点（自动闭环）

### 预期结果

#### UI 表现
- ❌ 显示验证失败横幅："面积不足"或类似错误
- ❌ **不显示**"确认登记领地"按钮
- ✅ 仅显示"停止圈地"按钮

#### 日志检查
查看 Xcode Console 或 LogView：
```
[INFO] 路径已闭合，开始验证...
[ERROR] 验证失败：面积不足（实际: XX m², 要求: 100 m²）
```

#### 数据库检查
在 Supabase SQL Editor 执行：
```sql
SELECT COUNT(*) FROM territories WHERE created_at > NOW() - INTERVAL '5 minutes';
```
**预期**：返回 `0`（没有新增数据）

### ✅ 场景 1 通过标准
- [ ] 显示验证失败横幅
- [ ] 不显示"确认登记"按钮
- [ ] 数据库没有新增记录

---

## 🧪 场景 2：验证通过并成功上传

### 操作步骤

1. 点击"停止圈地"（清除上一次的失败路径）
2. 点击"开始圈地"
3. 走一个较大的圈：
   - 向前走 15 米
   - 右转 90 度
   - 向前走 15 米
   - 右转 90 度
   - 向前走 15 米
   - 右转 90 度
   - 回到起点（自动闭环）

### 预期结果 - 第一步：验证通过

#### UI 表现
- ✅ 显示验证成功横幅："领地验证通过！面积: XXX m²"
- ✅ **显示**绿色的"确认登记领地"按钮
- ✅ 按钮位于"停止圈地"按钮上方

#### 日志检查
```
[SUCCESS] 领地验证通过！面积: XXX m²
```

### 预期结果 - 第二步：点击上传

4. 点击"确认登记领地"按钮

#### UI 表现（上传过程）
- ✅ 按钮文字变为"上传中..."
- ✅ 显示 ProgressView（转圈动画）
- ✅ 按钮变灰（禁用状态）

#### UI 表现（上传完成）
- ✅ 显示 Alert："领地登记成功"
- ✅ 点击"确定"后 Alert 消失
- ✅ "确认登记领地"按钮**消失**
- ✅ 地图上的路径轨迹**清空**
- ✅ 圈地按钮恢复为"开始圈地"

#### 日志检查
```
[INFO] 开始上传领地：面积 XXX m², 点数 XX
[SUCCESS] 领地上传成功！面积: XXX m²
[SUCCESS] 领地登记成功！面积: XXX m²
[INFO] 停止追踪并重置状态
```

#### 数据库检查
在 Supabase SQL Editor 执行：
```sql
SELECT
    id,
    area,
    point_count,
    created_at,
    is_active
FROM territories
ORDER BY created_at DESC
LIMIT 1;
```

**预期结果**：
- ✅ 有一条新记录
- ✅ `area` 接近实际圈地面积（误差 ±10%）
- ✅ `point_count` 与日志中的点数一致
- ✅ `is_active = true`
- ✅ `created_at` 是刚才的时间

### ✅ 场景 2 通过标准
- [ ] 验证通过后显示"确认登记"按钮
- [ ] 点击按钮后显示"上传中..."
- [ ] 上传成功显示 Alert
- [ ] 按钮消失，路径清空
- [ ] 数据库有新记录
- [ ] 记录的 area 和 point_count 正确

---

## 🧪 场景 3：防止重复上传（最关键！）

### 操作步骤

1. 完成场景 2 后，**不要**点击任何按钮
2. 观察 UI 状态

### 预期结果 - 即时检查

#### UI 表现
- ✅ "确认登记领地"按钮**已消失**
- ✅ 地图上没有路径轨迹
- ✅ 圈地按钮显示为"开始圈地"（不是"停止圈地"）

### 预期结果 - 尝试重新上传

3. 尝试以下操作（这些都不应该触发上传）：
   - 不点击"开始圈地"，直接查看是否有"确认登记"按钮
   - 切换到其他 Tab 再回来
   - 杀掉 App 重新打开

#### UI 表现
- ✅ 始终不显示"确认登记"按钮
- ✅ 必须重新点击"开始圈地"才能开始新的圈地

### 预期结果 - 数据库检查

在 Supabase SQL Editor 执行：
```sql
-- 检查最近 5 分钟内是否有重复记录
SELECT
    user_id,
    area,
    point_count,
    COUNT(*) as upload_count,
    MIN(created_at) as first_upload,
    MAX(created_at) as last_upload,
    EXTRACT(EPOCH FROM (MAX(created_at) - MIN(created_at))) as time_diff_seconds
FROM territories
WHERE created_at > NOW() - INTERVAL '5 minutes'
GROUP BY user_id, area, point_count
HAVING COUNT(*) > 1;
```

**预期结果**：返回 `0 rows`（没有重复记录）

### ✅ 场景 3 通过标准
- [ ] 上传后"确认登记"按钮消失
- [ ] 路径已清空
- [ ] 追踪已停止
- [ ] 数据库中只有 1 条记录（没有重复）
- [ ] 必须重新"开始圈地"才能开始新的圈地

---

## 🔍 数据库完整性验证

完成所有场景后，在 Supabase SQL Editor 执行完整验证：

### 验证脚本位置
```
/Users/xinyao/Desktop/EarthLord/migrations/verify_territories_upload.sql
```

### 快速验证（复制粘贴）

```sql
-- 查看最新 3 条领地
SELECT
    id,
    area,
    point_count,
    is_active,
    created_at
FROM territories
ORDER BY created_at DESC
LIMIT 3;

-- 检查是否有重复
SELECT
    user_id,
    area,
    point_count,
    COUNT(*) as upload_count
FROM territories
GROUP BY user_id, area, point_count
HAVING COUNT(*) > 1;
```

### 预期结果

**查询 1**：最新 3 条领地
- ✅ 应该看到刚才上传的 1 条记录
- ✅ `area` 和 `point_count` 与日志一致

**查询 2**：重复检查
- ✅ 返回 `0 rows`（没有重复）

---

## 📊 测试结果记录表

### 场景 1：验证失败

| 检查项 | 状态 | 备注 |
|--------|------|------|
| 显示验证失败横幅 | ☐ 通过 ☐ 失败 |  |
| 不显示"确认登记"按钮 | ☐ 通过 ☐ 失败 |  |
| 数据库没有新增 | ☐ 通过 ☐ 失败 |  |

### 场景 2：验证通过并上传

| 检查项 | 状态 | 备注 |
|--------|------|------|
| 验证通过后显示按钮 | ☐ 通过 ☐ 失败 |  |
| 点击后显示"上传中..." | ☐ 通过 ☐ 失败 |  |
| 显示成功 Alert | ☐ 通过 ☐ 失败 |  |
| 按钮消失 | ☐ 通过 ☐ 失败 |  |
| 路径清空 | ☐ 通过 ☐ 失败 |  |
| 数据库有新记录 | ☐ 通过 ☐ 失败 |  |
| area 和 point_count 正确 | ☐ 通过 ☐ 失败 |  |

### 场景 3：防止重复上传

| 检查项 | 状态 | 备注 |
|--------|------|------|
| 上传后按钮消失 | ☐ 通过 ☐ 失败 |  |
| 追踪已停止 | ☐ 通过 ☐ 失败 |  |
| 数据库无重复记录 | ☐ 通过 ☐ 失败 |  |

---

## ⚠️ 常见问题排查

### 问题 1：上传失败，显示"用户未登录"

**原因**：未登录或 session 过期

**解决**：
1. 进入 Profile 页面
2. 退出登录
3. 重新登录
4. 再次测试

### 问题 2：上传失败，显示网络错误

**原因**：网络连接问题或 Supabase 服务异常

**解决**：
1. 检查手机网络连接
2. 检查 Supabase 项目状态
3. 查看 Xcode Console 详细错误信息

### 问题 3：验证通过但按钮不显示

**原因**：可能是状态更新问题

**解决**：
1. 检查 `territoryValidationPassed` 是否为 true
2. 重新编译并运行
3. 查看 Console 日志

### 问题 4：数据库中 area 或 point_count 为 0

**原因**：数据上传有问题

**解决**：
1. 检查 TerritoryManager.uploadTerritory 逻辑
2. 查看上传的 JSON 数据
3. 检查数据库字段约束

---

## 🎉 测试完成标准

当所有检查项都通过时，说明：

✅ **场景 1 测试通过**：验证失败时没有上传
✅ **场景 2 测试通过**：验证通过后成功上传
✅ **场景 3 测试通过**：上传后追踪停止，无法重复上传

**可以继续 Day 18-地图显示！**
