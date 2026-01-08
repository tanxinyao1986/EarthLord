# Supabase 配置检查清单

## ✅ 必须完成的配置

### 1. Email Provider 设置
访问：https://supabase.com/dashboard/project/dzfylsyvnskzvpwomcim/auth/providers

- [ ] Enable Email provider: **ON**
- [ ] Enable email confirmations: **OFF** ⚠️ 必须关闭
- [ ] Enable email change confirmations: **OFF**
- [ ] Enable secure password change: **OFF**
- [ ] 点击 **Save** 保存

### 2. 验证 API Keys
访问：https://supabase.com/dashboard/project/dzfylsyvnskzvpwomcim/settings/api

确认以下信息：
- Project URL: `https://dzfylsyvnskzvpwomcim.supabase.co`
- anon public key: `sb_publishable_KJcs3naUpYADIqbnpMeAeQ_tycx9k8o`

### 3. 测试步骤

#### 方案 A：在 Supabase 控制台创建测试用户
1. 访问：https://supabase.com/dashboard/project/dzfylsyvnskzvpwomcim/auth/users
2. 点击 "Add User" → "Create new user"
3. 输入邮箱：test@example.com
4. 输入密码：test123456
5. **取消勾选** "Send user a confirmation email"
6. 点击 "Create User"
7. 创建成功后，在 App 中用这个账号登录

#### 方案 B：直接在 App 中注册
1. 完成上述配置后
2. 在 App 中输入邮箱和密码
3. 点击注册
4. 应该能直接注册成功（无需邮件验证）

## 🔍 如果还是失败

请提供以下信息：
1. Supabase 控制台的截图（Email Provider 设置页面）
2. App 中的完整错误信息
3. Xcode Console 的日志输出

## 📞 联系支持

如果以上步骤都无法解决，可能是：
- Supabase 项目配置有问题
- 需要重新创建项目
- API Key 不匹配
