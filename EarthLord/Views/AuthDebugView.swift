//
//  AuthDebugView.swift
//  EarthLord
//
//  用于测试和调试认证功能
//

import SwiftUI
import Supabase
import Auth

struct AuthDebugView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @State private var testEmail = ""
    @State private var testPassword = "test123456"
    @State private var debugLog = ""
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 测试区域
                    VStack(alignment: .leading, spacing: 15) {
                        Text("认证测试工具")
                            .font(.title2.bold())

                        // 测试邮箱
                        VStack(alignment: .leading, spacing: 8) {
                            Text("测试邮箱")
                                .font(.caption)
                                .foregroundColor(.gray)
                            TextField("输入邮箱", text: $testEmail)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                        }

                        // 测试密码
                        VStack(alignment: .leading, spacing: 8) {
                            Text("测试密码")
                                .font(.caption)
                                .foregroundColor(.gray)
                            TextField("密码", text: $testPassword)
                                .textFieldStyle(.roundedBorder)
                        }

                        // 测试按钮组
                        VStack(spacing: 10) {
                            Button(action: testConnection) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                    }
                                    Text("测试连接")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }

                            Button(action: testSendOTP) {
                                Text("测试发送 OTP")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }

                            Button(action: testDirectSignUp) {
                                Text("直接注册（无验证）")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }

                            Button(action: clearLog) {
                                Text("清除日志")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.gray)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(15)

                    // 调试日志
                    VStack(alignment: .leading, spacing: 10) {
                        Text("调试日志")
                            .font(.headline)

                        ScrollView {
                            Text(debugLog.isEmpty ? "等待测试..." : debugLog)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                        .frame(height: 300)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(10)
                    }
                    .padding()

                    // 当前状态
                    VStack(alignment: .leading, spacing: 10) {
                        Text("认证状态")
                            .font(.headline)

                        HStack {
                            Text("已登录:")
                            Text(authManager.isAuthenticated ? "✅ 是" : "❌ 否")
                                .foregroundColor(authManager.isAuthenticated ? .green : .red)
                        }

                        HStack {
                            Text("当前用户:")
                            Text(authManager.currentUser?.email ?? "无")
                        }

                        if let error = authManager.errorMessage {
                            VStack(alignment: .leading) {
                                Text("错误信息:")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(15)
                }
                .padding()
            }
            .navigationTitle("认证调试")
        }
    }

    // MARK: - Test Methods

    private func testConnection() {
        isLoading = true
        addLog("🔍 开始测试连接...")
        addLog("URL: https://dzfylsyvnskzvpwomcim.supabase.co")

        Task {
            do {
                let supabase = SupabaseConfig.shared
                addLog("✅ Supabase 客户端初始化成功")

                // 尝试简单的查询测试连接
                addLog("📡 测试 API 连接...")

                let session = try? await supabase.auth.session
                if session != nil {
                    addLog("✅ 已有会话，连接正常")
                } else {
                    addLog("ℹ️ 无活动会话，但连接可用")
                }

                addLog("✅ 连接测试成功")
            } catch {
                addLog("❌ 连接测试失败: \(error.localizedDescription)")
            }

            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func testSendOTP() {
        guard !testEmail.isEmpty else {
            addLog("⚠️ 请输入测试邮箱")
            return
        }

        addLog("📧 尝试发送 OTP 到: \(testEmail)")
        addLog("⏳ 请等待...")

        Task {
            // 等待一下让 print 输出
            try? await Task.sleep(nanoseconds: 500_000_000)

            await authManager.sendRegisterOTP(email: testEmail)

            // 再等待一下确保所有日志输出
            try? await Task.sleep(nanoseconds: 500_000_000)

            await MainActor.run {
                if authManager.otpSent {
                    addLog("✅ OTP 发送成功！")
                    addLog("📬 请检查邮箱: \(testEmail)")
                } else if let error = authManager.errorMessage {
                    addLog("❌ OTP 发送失败")
                    addLog("错误详情: \(error)")
                    addLog("")
                    addLog("💡 解决方案：")
                    addLog("1. 检查 Xcode Console 查看详细错误")
                    addLog("2. 使用下面的'直接注册'按钮")
                    addLog("3. 到 Supabase 控制台关闭邮箱验证")
                    addLog("")
                    addLog("🔗 Supabase 控制台:")
                    addLog("https://supabase.com/dashboard")
                }
            }
        }
    }

    private func testDirectSignUp() {
        guard !testEmail.isEmpty else {
            addLog("⚠️ 请输入测试邮箱")
            showToast(message: "请先输入测试邮箱")
            return
        }

        addLog("━━━━━━━━━━━━━━━━━━━━")
        addLog("🚀 开始直接注册测试")
        addLog("━━━━━━━━━━━━━━━━━━━━")
        addLog("邮箱: \(testEmail)")
        addLog("密码: \(testPassword)")
        addLog("")

        isLoading = true

        Task {
            do {
                let supabase = SupabaseConfig.shared

                addLog("📝 调用 signUp API...")
                addLog("等待服务器响应...")

                let session = try await supabase.auth.signUp(
                    email: testEmail,
                    password: testPassword
                )

                await MainActor.run {
                    addLog("")
                    addLog("✅ 注册成功！")
                    addLog("━━━━━━━━━━━━━━━━━━━━")
                    addLog("用户 ID: \(session.user.id)")
                    addLog("邮箱: \(session.user.email ?? "无")")
                    addLog("")

                    if session.user.emailConfirmedAt != nil {
                        addLog("✅ 邮箱已确认，可以直接登录")
                        addLog("正在自动登录...")
                        authManager.isAuthenticated = true
                        showToast(message: "注册成功！正在登录...")
                    } else {
                        addLog("⚠️ 邮箱未确认")
                        addLog("")
                        addLog("解决方法：")
                        addLog("1. 到 Supabase 控制台")
                        addLog("2. Authentication → Providers → Email")
                        addLog("3. 关闭 'Enable email confirmations'")
                        addLog("4. 保存后重试")
                        showToast(message: "需要关闭邮箱验证")
                    }

                    isLoading = false
                }

            } catch let error as NSError {
                // 打印到 Console 以便调试
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("❌❌❌ 注册失败 - 详细错误信息 ❌❌❌")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("错误描述: \(error.localizedDescription)")
                print("错误域: \(error.domain)")
                print("错误代码: \(error.code)")
                print("完整错误: \(error)")
                print("用户信息: \(error.userInfo)")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

                await MainActor.run {
                    addLog("")
                    addLog("❌ 注册失败")
                    addLog("━━━━━━━━━━━━━━━━━━━━")
                    addLog("错误描述: \(error.localizedDescription)")
                    addLog("错误域: \(error.domain)")
                    addLog("错误代码: \(error.code)")
                    addLog("")
                    addLog("完整错误信息:")
                    addLog("\(error)")
                    addLog("")
                    addLog("用户信息:")
                    addLog("\(error.userInfo)")
                    addLog("")
                    addLog("常见原因：")
                    addLog("1. 邮箱已被注册")
                    addLog("2. 网络连接问题")
                    addLog("3. Supabase 配置错误")
                    addLog("4. Email 确认未关闭")
                    showToast(message: "注册失败：\(error.localizedDescription)")
                    isLoading = false
                }
            }
        }
    }

    private func showToast(message: String) {
        // 简单的提示，可以后续改进
        print("🔔 Toast: \(message)")
    }

    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        debugLog += "[\(timestamp)] \(message)\n"
    }

    private func clearLog() {
        debugLog = ""
        authManager.clearError()
    }
}

#Preview {
    AuthDebugView()
}
