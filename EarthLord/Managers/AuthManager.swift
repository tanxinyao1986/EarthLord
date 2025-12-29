//
//  AuthManager.swift
//  EarthLord
//
//  Created by Claude Code
//

import Foundation
import SwiftUI
import Combine
import Supabase

/// 认证管理器
/// 负责处理用户注册、登录、密码重置等认证相关操作
@MainActor
class AuthManager: ObservableObject {

    // MARK: - Published Properties

    /// 用户是否已完成认证（已登录且完成所有流程）
    @Published var isAuthenticated: Bool = false

    /// 是否需要设置密码（OTP 验证后但未设置密码）
    @Published var needsPasswordSetup: Bool = false

    /// 当前登录用户
    @Published var currentUser: User?

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    /// OTP 验证码是否已发送
    @Published var otpSent: Bool = false

    /// OTP 验证码是否已验证（等待设置密码）
    @Published var otpVerified: Bool = false

    // MARK: - Private Properties

    /// Supabase 客户端
    private let supabase = SupabaseConfig.shared

    /// 认证状态监听任务
    private var authStateTask: Task<Void, Never>?

    // MARK: - Singleton

    /// 全局共享实例
    static let shared = AuthManager()

    // MARK: - Initializer

    private init() {
        // 初始化时检查会话
        Task {
            await checkSession()
        }

        // 启动认证状态监听
        startAuthStateListener()
    }

    deinit {
        // 取消监听
        authStateTask?.cancel()
    }

    // MARK: - 注册流程

    /// 发送注册验证码
    /// - Parameter email: 邮箱地址
    func sendRegisterOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            print("📧 开始发送注册验证码...")
            print("📧 邮箱: \(email)")

            // 发送 OTP 验证码（允许创建新用户）
            try await supabase.auth.signInWithOTP(
                email: email,
                shouldCreateUser: true
            )

            otpSent = true
            print("✅ 注册验证码已发送到: \(email)")

        } catch let error as NSError {
            // 详细错误信息
            print("❌ 发送注册验证码失败")
            print("❌ 错误描述: \(error.localizedDescription)")
            print("❌ 错误代码: \(error.code)")
            print("❌ 错误域: \(error.domain)")
            print("❌ 详细信息: \(error)")

            // 检查是否是网络错误
            if error.domain == NSURLErrorDomain {
                errorMessage = "网络错误: \(error.localizedDescription)"
            } else {
                errorMessage = "发送验证码失败: \(error.localizedDescription)\n错误代码: \(error.code)"
            }
        } catch {
            errorMessage = "发送验证码失败: \(error.localizedDescription)"
            print("❌ 发送注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 验证注册验证码
    /// - Parameters:
    ///   - email: 邮箱地址
    ///   - code: 验证码
    /// - Note: 验证成功后用户已登录，但需要设置密码才能完成注册
    func verifyRegisterOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 验证 OTP 验证码
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .email
            )

            // 验证成功，用户已登录
            otpVerified = true
            needsPasswordSetup = true

            // 获取用户信息
            let authUser = session.user
            currentUser = User(
                id: authUser.id,
                email: authUser.email ?? email,
                username: authUser.userMetadata["username"]?.stringValue,
                avatarUrl: authUser.userMetadata["avatar_url"]?.stringValue,
                createdAt: authUser.createdAt
            )

            print("✅ 验证码验证成功，用户已登录但需要设置密码")

        } catch {
            errorMessage = "验证码验证失败: \(error.localizedDescription)"
            print("❌ 验证注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 完成注册（设置密码）
    /// - Parameter password: 用户密码
    /// - Note: 注册流程的最后一步，设置密码后才能进入主页
    func completeRegistration(password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            try await supabase.auth.update(
                user: UserAttributes(password: password)
            )

            // 设置密码成功，完成注册
            needsPasswordSetup = false
            otpVerified = false  // 重置标志
            isAuthenticated = true

            print("✅ 注册完成，密码设置成功")

        } catch {
            errorMessage = "设置密码失败: \(error.localizedDescription)"
            print("❌ 完成注册失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 登录

    /// 使用邮箱和密码登录
    /// - Parameters:
    ///   - email: 邮箱地址
    ///   - password: 密码
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 使用邮箱和密码登录
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            // 登录成功
            isAuthenticated = true

            // 获取用户信息
            let authUser = session.user
            currentUser = User(
                id: authUser.id,
                email: authUser.email ?? email,
                username: authUser.userMetadata["username"]?.stringValue,
                avatarUrl: authUser.userMetadata["avatar_url"]?.stringValue,
                createdAt: authUser.createdAt
            )

            print("✅ 登录成功: \(email)")

        } catch {
            errorMessage = "登录失败: \(error.localizedDescription)"
            print("❌ 登录失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 找回密码流程

    /// 发送密码重置验证码
    /// - Parameter email: 邮箱地址
    /// - Note: 会触发 Supabase 的 "Reset Password" 邮件模板
    func sendResetOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 发送密码重置邮件
            try await supabase.auth.resetPasswordForEmail(email)

            otpSent = true
            print("✅ 密码重置验证码已发送到: \(email)")

        } catch {
            errorMessage = "发送重置验证码失败: \(error.localizedDescription)"
            print("❌ 发送重置验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 验证密码重置验证码
    /// - Parameters:
    ///   - email: 邮箱地址
    ///   - code: 验证码
    /// - Note: 注意 type 使用 .recovery 而非 .email
    func verifyResetOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 验证密码重置验证码（type 为 .recovery）
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery  // ⚠️ 注意：密码重置使用 .recovery 类型
            )

            // 验证成功
            otpVerified = true
            needsPasswordSetup = true

            // 获取用户信息
            let authUser = session.user
            currentUser = User(
                id: authUser.id,
                email: authUser.email ?? email,
                username: authUser.userMetadata["username"]?.stringValue,
                avatarUrl: authUser.userMetadata["avatar_url"]?.stringValue,
                createdAt: authUser.createdAt
            )

            print("✅ 密码重置验证码验证成功")

        } catch {
            errorMessage = "验证码验证失败: \(error.localizedDescription)"
            print("❌ 验证密码重置验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 重置密码（设置新密码）
    /// - Parameter newPassword: 新密码
    func resetPassword(newPassword: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新为新密码
            try await supabase.auth.update(
                user: UserAttributes(password: newPassword)
            )

            // 密码重置成功
            needsPasswordSetup = false
            isAuthenticated = true

            print("✅ 密码重置成功")

        } catch {
            errorMessage = "重置密码失败: \(error.localizedDescription)"
            print("❌ 重置密码失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 第三方登录（预留）

    /// 使用 Apple 登录
    /// TODO: 实现 Apple 登录功能
    func signInWithApple() async {
        isLoading = true
        errorMessage = nil

        // TODO: 实现 Sign in with Apple
        // 1. 获取 Apple ID Credential
        // 2. 调用 supabase.auth.signInWithIdToken()
        // 3. 处理登录结果

        errorMessage = "Apple 登录功能开发中..."
        print("⚠️ Apple 登录功能尚未实现")

        isLoading = false
    }

    /// 使用 Google 登录
    /// TODO: 实现 Google 登录功能
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil

        // TODO: 实现 Sign in with Google
        // 1. 获取 Google ID Token
        // 2. 调用 supabase.auth.signInWithIdToken()
        // 3. 处理登录结果

        errorMessage = "Google 登录功能开发中..."
        print("⚠️ Google 登录功能尚未实现")

        isLoading = false
    }

    // MARK: - 其他方法

    /// 退出登录
    func signOut() async {
        isLoading = true
        errorMessage = nil

        do {
            // 退出登录
            try await supabase.auth.signOut()

            // 清空状态
            isAuthenticated = false
            needsPasswordSetup = false
            currentUser = nil
            otpSent = false
            otpVerified = false

            print("✅ 已退出登录")

        } catch {
            errorMessage = "退出登录失败: \(error.localizedDescription)"
            print("❌ 退出登录失败: \(error)")
        }

        isLoading = false
    }

    /// 检查会话状态
    /// - Note: 在应用启动时调用，恢复用户登录状态
    func checkSession() async {
        do {
            // 获取当前会话
            let session = try await supabase.auth.session

            // 有有效会话
            let authUser = session.user
            // 检查用户是否已设置密码
            // 注意：这里假设设置密码后用户都能正常登录
            // 如果需要更精确的判断，可以检查 user_metadata 中的标志
            isAuthenticated = true
            needsPasswordSetup = false

            currentUser = User(
                id: authUser.id,
                email: authUser.email ?? "",
                username: authUser.userMetadata["username"]?.stringValue,
                avatarUrl: authUser.userMetadata["avatar_url"]?.stringValue,
                createdAt: authUser.createdAt
            )

            print("✅ 会话有效，用户已登录: \(authUser.email ?? "")")

        } catch {
            // 没有有效会话或会话过期
            isAuthenticated = false
            currentUser = nil
            print("⚠️ 没有有效会话")
        }
    }

    // MARK: - Helper Methods

    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }

    /// 重置状态（用于在流程切换时清理状态）
    func resetState() {
        otpSent = false
        otpVerified = false
        errorMessage = nil
    }

    // MARK: - Auth State Listener

    /// 启动认证状态监听
    /// 监听 Supabase 的认证状态变化，自动更新 isAuthenticated
    private func startAuthStateListener() {
        authStateTask = Task {
            for await (event, session) in await supabase.auth.authStateChanges {
                await handleAuthStateChange(event: event, session: session)
            }
        }
    }

    /// 处理认证状态变化
    /// - Parameters:
    ///   - event: 认证状态变化事件
    ///   - session: 当前会话（可能为空）
    private func handleAuthStateChange(event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .signedIn:
            // 用户登录
            print("🔐 Auth状态变化: 用户已登录")
            // 检查会话以更新用户信息
            // 但如果正在注册流程中（OTP已验证但需要设置密码），不要覆盖 needsPasswordSetup
            if !otpVerified {
                await checkSession()
            } else {
                print("⚠️ 注册流程中，保持 needsPasswordSetup 状态")
            }

        case .signedOut:
            // 用户登出
            print("🔓 Auth状态变化: 用户已登出")
            isAuthenticated = false
            needsPasswordSetup = false
            currentUser = nil
            otpSent = false
            otpVerified = false

        case .tokenRefreshed:
            // Token刷新
            print("🔄 Auth状态变化: Token已刷新")

        case .userUpdated:
            // 用户信息更新
            print("📝 Auth状态变化: 用户信息已更新")
            await checkSession()

        case .passwordRecovery:
            // 密码恢复
            print("🔑 Auth状态变化: 密码恢复中")

        case .userDeleted:
            // 用户删除
            print("🗑️ Auth状态变化: 用户已删除")
            isAuthenticated = false
            currentUser = nil

        case .mfaChallengeVerified:
            // MFA验证
            print("🔐 Auth状态变化: MFA验证完成")

        @unknown default:
            print("⚠️ Auth状态变化: 未知状态")
        }
    }
}
