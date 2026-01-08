# Day 18-地图显示 测试指南

## 📋 测试前准备

### 1. 确认数据库中有领地数据

在 Supabase SQL Editor 执行：

```sql
-- 查看当前用户的领地
SELECT
    id,
    user_id,
    area,
    point_count,
    created_at
FROM territories
WHERE is_active = true
ORDER BY created_at DESC
LIMIT 5;
```

**预期结果**：至少有 1 条记录（之前上传的领地）

### 2. 记录当前用户 ID

在 App 中查看 Profile 页面，或执行：

```sql
-- 查看所有用户
SELECT
    id,
    email
FROM auth.users
ORDER BY created_at DESC
LIMIT 5;
```

记录您的 user_id：`____________________________`

---

## 🧪 测试 1：App 启动时加载领地

### 操作步骤

1. **完全退出 App**（从后台也关闭）
2. **重新启动 App**
3. **进入地图页面**
4. **等待 3-5 秒**

### 预期结果 - 控制台日志

在 Xcode Console 中应该看到：

```
🎨 绘制了 X 个领地
[INFO] 加载了 X 个领地
✅ 地图加载完成
```

### 预期结果 - 地图显示

| 检查项 | 预期 | 实际 |
|--------|------|------|
| 地图上显示领地多边形 | ✅ | ☐ ✅ ☐ ❌ |
| 领地有边框和填充 | ✅ | ☐ ✅ ☐ ❌ |
| 领地颜色为**绿色** | ✅ | ☐ ✅ ☐ ❌ |
| 领地位置正确（在您圈地的位置） | ✅ | ☐ ✅ ☐ ❌ |

### ⚠️ 常见问题 1：领地显示为橙色

**症状**：地图上有领地，但是**橙色**，不是绿色

**原因**：UUID 大小写不匹配

**诊断步骤**：

1. 查看控制台日志，找到这一行：
```
🎨 绘制了 X 个领地
```

2. 在 Xcode 中打断点，检查：
```swift
// MapViewRepresentable.swift 第 218 行
let isMine = territory.userId.lowercased() == currentUserId?.lowercased()
```

3. 检查值：
   - `territory.userId`: `____________________________`
   - `currentUserId`: `____________________________`
   - `isMine`: `____` (应该是 true)

**解决方案**：

检查 MapViewRepresentable.swift 第 218 行：

```swift
// ✅ 正确写法（使用 lowercased()）
let isMine = territory.userId.lowercased() == currentUserId?.lowercased()

// ❌ 错误写法（会导致橙色）
let isMine = territory.userId == currentUserId
```

### ⚠️ 常见问题 2：没有显示领地

**症状**：地图是空的，没有任何领地多边形

**可能原因**：

#### 原因 A：加载失败

检查控制台是否有错误：

```
[ERROR] 加载领地失败: ...
```

**解决方案**：根据错误信息排查

#### 原因 B：解码失败

错误信息：
```
The data couldn't be read because it is missing.
```

**解决方案**：检查 Territory 模型的 CodingKeys 和 Optional 字段

#### 原因 C：coordinates 转换失败

检查控制台：
```
🎨 绘制了 0 个领地
```

但是日志显示：
```
[INFO] 加载了 X 个领地
```

**解决方案**：检查 `territory.toCoordinates()` 方法

### ✅ 测试 1 通过标准

- [ ] 控制台显示"加载了 X 个领地"
- [ ] 地图上显示领地多边形
- [ ] 领地颜色为**绿色**（不是橙色）
- [ ] 领地位置正确

---

## 🧪 测试 2：新增领地后自动刷新

### 操作步骤

1. **记录当前领地数量**：`____` 个
2. **点击"开始圈地"**
3. **走一个足够大的圈**（面积 ≥ 100m²）
4. **等待自动闭合**
5. **点击"确认登记领地"**
6. **等待上传成功**
7. **观察地图**

### 预期结果 - 控制台日志

```
✅ 领地上传成功
[SUCCESS] 领地登记成功！面积: XXX m²
[INFO] 停止追踪并重置状态
[INFO] 加载了 Y 个领地  ← 注意：Y = X + 1
🎨 绘制了 Y 个领地
```

### 预期结果 - 地图显示

| 检查项 | 预期 | 实际 |
|--------|------|------|
| 上传成功后立即显示新领地 | ✅ | ☐ ✅ ☐ ❌ |
| 新领地颜色为**绿色** | ✅ | ☐ ✅ ☐ ❌ |
| 旧领地仍然显示 | ✅ | ☐ ✅ ☐ ❌ |
| 追踪路径已清除 | ✅ | ☐ ✅ ☐ ❌ |
| 领地总数增加 1 | ✅ | ☐ ✅ ☐ ❌ |

### ⚠️ 常见问题：上传后没有刷新

**症状**：上传成功，但地图上看不到新领地

**原因**：`uploadCurrentTerritory()` 中没有调用 `loadTerritories()`

**检查**：MapTabView.swift 第 438 行附近：

```swift
// 上传成功后
LogManager.shared.success("领地登记成功！...")

// ✅ 应该有这一行
await loadTerritories()
```

### ✅ 测试 2 通过标准

- [ ] 上传成功后立即刷新
- [ ] 新领地立即显示（绿色）
- [ ] 控制台显示领地数量增加
- [ ] 旧领地仍然显示

---

## 🧪 测试 3：UUID 大小写验证

### 目的

确认 UUID 比较正确处理大小写，避免自己的领地被误识别为他人领地

### 操作步骤

1. **在 Supabase SQL Editor 执行**：

```sql
-- 查看您的领地的 user_id（小写）
SELECT
    id,
    user_id,
    area,
    created_at
FROM territories
WHERE is_active = true
ORDER BY created_at DESC
LIMIT 1;
```

记录 `user_id`：`____________________________`（应该是小写）

2. **在 Xcode Console 查找日志**：

```
[INFO] 当前用户 ID: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
```

记录 User ID：`____________________________`（应该是大写）

3. **对比**：

| 字段 | 值 | 大小写 |
|------|-------|--------|
| 数据库 user_id | `____________________________` | 小写 |
| iOS currentUserId | `____________________________` | 大写 |
| 是否相同（忽略大小写） | ☐ ✅ ☐ ❌ | - |

### 预期结果

- ✅ 数据库 user_id 是**小写**
- ✅ iOS currentUserId 是**大写**
- ✅ 代码使用 `lowercased()` 比较
- ✅ 领地显示为**绿色**

### ⚠️ 验证代码

在 MapViewRepresentable.swift 第 218 行设置断点：

```swift
let isMine = territory.userId.lowercased() == currentUserId?.lowercased()
```

运行时检查：
- `territory.userId`: `____________________________`
- `territory.userId.lowercased()`: `____________________________`
- `currentUserId`: `____________________________`
- `currentUserId?.lowercased()`: `____________________________`
- `isMine`: `____` (应该是 `true`)

### ✅ 测试 3 通过标准

- [ ] UUID 大小写不同（数据库小写，iOS 大写）
- [ ] 代码使用 `lowercased()` 比较
- [ ] `isMine` 结果为 `true`
- [ ] 领地颜色为绿色

---

## 🧪 测试 4：坐标转换验证

### 目的

确认 WGS-84 坐标正确转换为 GCJ-02，领地显示在正确位置

### 操作步骤

1. **查看数据库中的坐标**：

```sql
SELECT
    id,
    path->0 as first_point,
    area
FROM territories
WHERE is_active = true
ORDER BY created_at DESC
LIMIT 1;
```

记录第一个点：
- lat: `____________________________`
- lon: `____________________________`

2. **在地图上查看领地位置**

3. **对比实际圈地位置**

### 预期结果

- ✅ 领地显示在您实际圈地的位置
- ✅ 没有明显偏移（误差 < 50 米）
- ✅ 领地形状正确

### ⚠️ 常见问题：位置偏移

**症状**：领地位置偏移约 500 米

**原因**：没有进行坐标转换（WGS-84 → GCJ-02）

**检查**：MapViewRepresentable.swift 第 205-208 行：

```swift
// ✅ 应该有坐标转换
coords = coords.map { coord in
    CoordinateConverter.wgs84ToGcj02(coord)
}
```

### ✅ 测试 4 通过标准

- [ ] 领地显示在正确位置
- [ ] 没有明显偏移
- [ ] 形状正确

---

## 🔍 错误排查清单

### 错误 1：「加载领地失败」

**完整错误信息**：
```
[ERROR] 加载领地失败: The data couldn't be read because it is missing.
```

**可能原因**：
- Territory 模型字段与数据库不匹配
- CodingKeys 映射错误
- 必填字段在数据库中是 NULL

**排查步骤**：

1. 检查数据库字段：
```sql
SELECT * FROM territories LIMIT 1;
```

2. 检查 Territory.swift 的 CodingKeys

3. 确认 Optional 字段：
```swift
let name: String?        // ✅ 应该是 Optional
let pointCount: Int?     // ✅ 应该是 Optional
let isActive: Bool?      // ✅ 应该是 Optional
```

### 错误 2：「绘制了 0 个领地」

**症状**：
```
[INFO] 加载了 X 个领地
🎨 绘制了 0 个领地
```

**可能原因**：
- `territory.toCoordinates()` 返回空数组
- path 格式不正确

**排查步骤**：

1. 检查数据库 path 格式：
```sql
SELECT path FROM territories LIMIT 1;
```

应该是：
```json
[{"lat": 31.23, "lon": 121.45}, ...]
```

2. 检查 Territory.toCoordinates() 方法

### 错误 3：领地颜色全是橙色

**症状**：所有领地都是橙色，包括自己的

**可能原因**：
- `currentUserId` 是 nil
- UUID 比较没有使用 `lowercased()`

**排查步骤**：

1. 检查 MapTabView.swift：
```swift
currentUserId: authManager.currentUser?.id.uuidString
```

2. 在控制台打印：
```swift
print("当前用户 ID: \(authManager.currentUser?.id.uuidString ?? "nil")")
```

3. 检查 MapViewRepresentable.swift 第 218 行

---

## 📊 测试结果记录表

### 测试汇总

| 测试项 | 状态 | 备注 |
|--------|------|------|
| 测试 1：App 启动加载领地 | ☐ ✅ ☐ ❌ |  |
| 测试 2：新增领地后刷新 | ☐ ✅ ☐ ❌ |  |
| 测试 3：UUID 大小写验证 | ☐ ✅ ☐ ❌ |  |
| 测试 4：坐标转换验证 | ☐ ✅ ☐ ❌ |  |

### 关键检查项

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 领地颜色为绿色（不是橙色） | ☐ ✅ ☐ ❌ | 最关键！ |
| 领地位置正确 | ☐ ✅ ☐ ❌ |  |
| 上传后自动刷新 | ☐ ✅ ☐ ❌ |  |
| 控制台无错误 | ☐ ✅ ☐ ❌ |  |

---

## 🎉 最终结论

### 如果所有测试通过

✅ **App 启动加载领地**：成功
✅ **领地显示在地图上**：绿色多边形（不是橙色）
✅ **新增领地后刷新**：成功
✅ **UUID 大小写处理**：正确
✅ **坐标转换**：正确

🎉 **Day 18-地图显示 完成！**

---

### 如果有测试失败

请记录以下信息：

1. **失败的测试项**：________

2. **错误信息**：
```
粘贴完整的控制台错误
```

3. **截图**：
   - 地图显示截图
   - Xcode Console 截图

4. **数据库查询结果**：
```sql
-- 您的领地数据
SELECT * FROM territories WHERE user_id = 'YOUR_USER_ID';
```

---

**测试完成时间**：________
**测试人员**：________
