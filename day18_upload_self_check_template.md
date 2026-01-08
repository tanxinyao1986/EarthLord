# Day 18-上传 自检报告

## 📋 测试环境

- **测试日期**：________
- **设备型号**：________
- **iOS 版本**：________
- **App 版本**：________
- **Supabase 项目**：dzfylsyvnskzvpwomcim

---

## ✅ 场景 1：验证失败（面积不足）

### 操作记录

- **开始时间**：________
- **圈地面积**：________ m²
- **点数**：________ 个点

### 测试结果

| 检查项 | 结果 | 备注 |
|--------|------|------|
| 显示验证失败横幅 | ☐ ✅ ☐ ❌ |  |
| 不显示"确认登记"按钮 | ☐ ✅ ☐ ❌ |  |
| 数据库没有新增记录 | ☐ ✅ ☐ ❌ |  |

### 日志截图

```
粘贴 Xcode Console 日志或截图
```

### 数据库验证

```sql
-- 执行前的记录数
SELECT COUNT(*) FROM territories;
结果：________ 条

-- 执行后的记录数
SELECT COUNT(*) FROM territories;
结果：________ 条

-- 差值应该为 0
```

### ✅ 场景 1 结果：☐ 通过 ☐ 失败

---

## ✅ 场景 2：验证通过并成功上传

### 操作记录

- **开始时间**：________
- **圈地面积**：________ m²
- **点数**：________ 个点
- **上传时间**：________

### 测试结果 - 验证阶段

| 检查项 | 结果 | 备注 |
|--------|------|------|
| 显示验证成功横幅 | ☐ ✅ ☐ ❌ |  |
| 显示"确认登记领地"按钮 | ☐ ✅ ☐ ❌ |  |
| 按钮为绿色 | ☐ ✅ ☐ ❌ |  |

### 测试结果 - 上传阶段

| 检查项 | 结果 | 备注 |
|--------|------|------|
| 点击后显示"上传中..." | ☐ ✅ ☐ ❌ |  |
| 显示 ProgressView | ☐ ✅ ☐ ❌ |  |
| 按钮变灰（禁用） | ☐ ✅ ☐ ❌ |  |
| 显示"领地登记成功" Alert | ☐ ✅ ☐ ❌ |  |
| 点击确定后按钮消失 | ☐ ✅ ☐ ❌ |  |
| 地图上路径清空 | ☐ ✅ ☐ ❌ |  |
| 圈地按钮恢复为"开始圈地" | ☐ ✅ ☐ ❌ |  |

### 日志记录

```
粘贴完整的上传日志：
[INFO] 开始上传领地：面积 XXX m², 点数 XX
[SUCCESS] 领地上传成功！面积: XXX m²
[SUCCESS] 领地登记成功！面积: XXX m²
[INFO] 停止追踪并重置状态
```

### 数据库验证

```sql
-- 查看最新上传的记录
SELECT
    id,
    area,
    point_count,
    is_active,
    created_at
FROM territories
ORDER BY created_at DESC
LIMIT 1;
```

**查询结果**：

| 字段 | 值 | 是否正确 |
|------|----|----|
| id | ________ | ☐ ✅ |
| area | ________ m² | ☐ ✅ (与日志一致) ☐ ❌ |
| point_count | ________ | ☐ ✅ (与日志一致) ☐ ❌ |
| is_active | ________ | ☐ ✅ (true) ☐ ❌ |
| created_at | ________ | ☐ ✅ (刚才时间) ☐ ❌ |

### ✅ 场景 2 结果：☐ 通过 ☐ 失败

---

## ✅ 场景 3：防止重复上传

### 操作记录

- **完成场景 2 的时间**：________
- **等待时间**：________ 秒
- **尝试的操作**：
  - ☐ 等待（不点击任何按钮）
  - ☐ 切换 Tab
  - ☐ 杀掉 App 重新打开

### 测试结果

| 检查项 | 结果 | 备注 |
|--------|------|------|
| "确认登记"按钮已消失 | ☐ ✅ ☐ ❌ |  |
| 地图上无路径轨迹 | ☐ ✅ ☐ ❌ |  |
| 圈地按钮显示"开始圈地" | ☐ ✅ ☐ ❌ |  |
| 切换 Tab 后回来仍无按钮 | ☐ ✅ ☐ ❌ |  |
| 重启 App 后仍无按钮 | ☐ ✅ ☐ ❌ |  |

### 数据库验证（重复检查）

```sql
-- 检查是否有重复记录
SELECT
    user_id,
    area,
    point_count,
    COUNT(*) as upload_count,
    MIN(created_at) as first_upload,
    MAX(created_at) as last_upload
FROM territories
WHERE created_at > NOW() - INTERVAL '10 minutes'
GROUP BY user_id, area, point_count
HAVING COUNT(*) > 1;
```

**查询结果**：________ rows (应该为 0)

### ✅ 场景 3 结果：☐ 通过 ☐ 失败

---

## 🔍 数据库完整性验证

### 完整验证脚本

```bash
# 在 Supabase SQL Editor 执行
cat /Users/xinyao/Desktop/EarthLord/migrations/verify_territories_upload.sql
```

或者手动执行以下 SQL：

```sql
-- 1. 查看最新 5 条记录
SELECT
    id,
    area,
    point_count,
    is_active,
    created_at
FROM territories
ORDER BY created_at DESC
LIMIT 5;

-- 2. 检查数据完整性
SELECT
    id,
    CASE WHEN user_id IS NOT NULL THEN '✅' ELSE '❌' END as user_id_check,
    CASE WHEN path IS NOT NULL THEN '✅' ELSE '❌' END as path_check,
    CASE WHEN area > 0 THEN '✅' ELSE '❌' END as area_check,
    CASE WHEN point_count > 0 THEN '✅' ELSE '❌' END as point_count_check,
    area,
    point_count
FROM territories
ORDER BY created_at DESC
LIMIT 3;

-- 3. 检查 path 格式
SELECT
    id,
    point_count,
    jsonb_array_length(path) as path_length,
    CASE
        WHEN jsonb_array_length(path) = point_count THEN '✅'
        ELSE '❌'
    END as length_match,
    path->0 as first_point
FROM territories
ORDER BY created_at DESC
LIMIT 3;
```

### 验证结果

| 验证项 | 结果 | 备注 |
|--------|------|------|
| 所有记录 user_id 不为空 | ☐ ✅ ☐ ❌ |  |
| 所有记录 path 不为空 | ☐ ✅ ☐ ❌ |  |
| 所有记录 area > 0 | ☐ ✅ ☐ ❌ |  |
| 所有记录 point_count > 0 | ☐ ✅ ☐ ❌ |  |
| path 长度与 point_count 一致 | ☐ ✅ ☐ ❌ |  |
| path 第一个点格式正确 ({"lat":x,"lon":y}) | ☐ ✅ ☐ ❌ |  |

---

## 📊 总体测试结果

### 场景汇总

| 场景 | 结果 |
|------|------|
| 场景 1：验证失败 | ☐ ✅ 通过 ☐ ❌ 失败 |
| 场景 2：验证通过并上传 | ☐ ✅ 通过 ☐ ❌ 失败 |
| 场景 3：防止重复上传 | ☐ ✅ 通过 ☐ ❌ 失败 |

### 问题记录

**遇到的问题**：
1. ________________________________________
2. ________________________________________
3. ________________________________________

**解决方案**：
1. ________________________________________
2. ________________________________________
3. ________________________________________

---

## 🎉 最终结论

**所有场景测试结果**：☐ ✅ 全部通过 ☐ ❌ 部分失败

### 如果全部通过

✅ **场景 1 测试通过**：验证失败时没有上传
✅ **场景 2 测试通过**：验证通过后成功上传
✅ **场景 3 测试通过**：上传后追踪停止，无法重复上传

🎉 **Day 18-上传 完成，可以继续 Day 18-地图显示！**

### 如果有失败

请记录详细信息并提供：
1. 失败场景的截图
2. Xcode Console 完整日志
3. 数据库查询结果截图
4. 操作步骤录屏（如果可能）

---

## 📎 附件

### Xcode Console 完整日志

```
粘贴完整日志
```

### 数据库查询截图

粘贴 Supabase SQL Editor 截图

### UI 截图

1. 验证失败时的界面：
2. 验证通过时的界面：
3. 上传中的界面：
4. 上传成功的 Alert：
5. 上传后的界面（按钮消失）：

---

**测试人员**：________
**测试完成时间**：________
