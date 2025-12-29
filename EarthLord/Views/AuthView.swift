//
//  AuthView.swift
//  EarthLord
//
//  Created by Claude Code
//

import SwiftUI

/// 认证视图
/// 包含登录、注册、忘记密码功能
struct AuthView: View {

    // MARK: - Properties

    /// 认证管理器
    @StateObject private var authManager = AuthManager.shared

    /// 当前选中的Tab（登录/注册）
    @State private var selectedTab: AuthTab = .login

    /// 登录表单
    @State private var loginEmail = ""
    @State private var loginPassword = ""

    /// 注册表单
    @State private var registerEmail = ""
    @State private var registerCode = ""
    @State private var registerPassword = ""
    @State private var registerConfirmPassword = ""

    /// 忘记密码表单
    @State private var resetEmail = ""
    @State private var resetCode = ""
    @State private var resetPassword = ""
    @State private var resetConfirmPassword = ""

    /// 是否显示忘记密码弹窗
    @State private var showForgotPassword = false

    /// 忘记密码当前步骤
    @State private var resetStep: ResetPasswordStep = .enterEmail

    /// 显示Toast提示
    @State private var showToast = false
    @State private var toastMessage = ""

    /// 验证码重发倒计时（秒）
    @State private var resendCountdown = 0
    @State private var resendTimer: Timer?

    /// 密码重置倒计时
    @State private var resetResendCountdown = 0
    @State private var resetResendTimer: Timer?

    /// 是否显示调试工具
    @State private var showDebugView = false

    // MARK: - Enums

    /// 认证Tab类型
    enum AuthTab: String, CaseIterable {
        case login = "登录"
        case register = "注册"
    }

    /// 密码重置步骤
    enum ResetPasswordStep {
        case enterEmail     // 输入邮箱
        case enterCode      // 输入验证码
        case enterPassword  // 输入新密码
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景渐变
            backgroundGradient

            ScrollView {
                VStack(spacing: 30) {
                    Spacer(minLength: 60)

                    // Logo和标题
                    logoSection

                    // 调试按钮（长按 Logo 进入）
                    debugButton

                    // Tab切换
                    tabSelector

                    // 内容区域
                    contentSection
                        .padding(.horizontal, 30)

                    // 第三方登录
                    thirdPartyLoginSection
                        .padding(.horizontal, 30)

                    Spacer(minLength: 40)
                }
            }

            // Toast提示
            if showToast {
                toastView
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            forgotPasswordSheet
        }
        .onChange(of: authManager.errorMessage) { _, newValue in
            if let error = newValue {
                showToastMessage(error)
            }
        }
        .onDisappear {
            stopTimers()
        }
    }

    // MARK: - Background

    /// 背景渐变
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.1, green: 0.1, blue: 0.2),
                Color(red: 0.05, green: 0.05, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Logo Section

    /// Logo和标题区域
    private var logoSection: some View {
        VStack(spacing: 16) {
            // Logo图标
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 标题
            Text("地球新主")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
        }
    }

    /// 调试按钮（开发专用）
    private var debugButton: some View {
        HStack(spacing: 12) {
            // 调试工具按钮
            Button(action: {
                showDebugView = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "ladybug.fill")
                        .font(.system(size: 14))
                    Text("调试工具")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(20)
            }
            .sheet(isPresented: $showDebugView) {
                AuthDebugView()
            }

            // 跳过登录按钮（临时测试用）
            Button(action: {
                // 直接设置为已登录状态
                authManager.isAuthenticated = true
                showToastMessage("已跳过登录，进入开发模式")
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14))
                    Text("跳过登录")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.3))
                .cornerRadius(20)
            }
        }
    }

    // MARK: - Tab Selector

    /// Tab选择器
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(AuthTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = tab
                        authManager.resetState()
                    }
                }) {
                    Text(tab.rawValue)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(selectedTab == tab ? .white : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selectedTab == tab ?
                            Color.white.opacity(0.2) :
                            Color.clear
                        )
                }
            }
        }
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 30)
    }

    // MARK: - Content Section

    /// 内容区域
    @ViewBuilder
    private var contentSection: some View {
        if selectedTab == .login {
            loginSection
        } else {
            registerSection
        }
    }

    // MARK: - Login Section

    /// 登录区域
    private var loginSection: some View {
        VStack(spacing: 20) {
            // 邮箱输入
            CustomTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $loginEmail,
                keyboardType: .emailAddress
            )

            // 密码输入
            CustomSecureField(
                icon: "lock.fill",
                placeholder: "密码",
                text: $loginPassword
            )

            // 忘记密码链接
            HStack {
                Spacer()
                Button(action: {
                    showForgotPassword = true
                    resetStep = .enterEmail
                }) {
                    Text("忘记密码？")
                        .font(.system(size: 14))
                        .foregroundColor(.cyan)
                }
            }

            // 登录按钮
            ActionButton(
                title: "登录",
                isLoading: authManager.isLoading,
                action: handleLogin
            )
            .padding(.top, 10)

            // 错误提示
            if let error = authManager.errorMessage {
                ErrorMessage(text: error)
            }
        }
    }

    // MARK: - Register Section

    /// 注册区域
    private var registerSection: some View {
        VStack(spacing: 20) {
            if !authManager.otpVerified {
                // 第一步：输入邮箱
                if !authManager.otpSent {
                    registerStepOne
                } else {
                    // 第二步：输入验证码
                    registerStepTwo
                }
            } else {
                // 第三步：设置密码
                registerStepThree
            }

            // 错误提示
            if let error = authManager.errorMessage {
                ErrorMessage(text: error)
            }
        }
    }

    /// 注册第一步：输入邮箱
    private var registerStepOne: some View {
        VStack(spacing: 20) {
            StepIndicator(currentStep: 1, totalSteps: 3)

            Text("输入邮箱地址")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            CustomTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $registerEmail,
                keyboardType: .emailAddress
            )

            ActionButton(
                title: "发送验证码",
                isLoading: authManager.isLoading,
                action: handleSendRegisterOTP
            )
        }
    }

    /// 注册第二步：输入验证码
    private var registerStepTwo: some View {
        VStack(spacing: 20) {
            StepIndicator(currentStep: 2, totalSteps: 3)

            VStack(spacing: 8) {
                Text("验证码已发送到")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                Text(registerEmail)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }

            // 6位验证码输入
            OTPTextField(text: $registerCode)

            // 重发倒计时
            if resendCountdown > 0 {
                Text("\(resendCountdown)秒后可重发")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            } else {
                Button(action: handleSendRegisterOTP) {
                    Text("重新发送验证码")
                        .font(.system(size: 14))
                        .foregroundColor(.cyan)
                }
            }

            ActionButton(
                title: "验证",
                isLoading: authManager.isLoading,
                action: handleVerifyRegisterOTP
            )
        }
    }

    /// 注册第三步：设置密码
    private var registerStepThree: some View {
        VStack(spacing: 20) {
            StepIndicator(currentStep: 3, totalSteps: 3)

            Text("设置登录密码")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "密码（至少6位）",
                text: $registerPassword
            )

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "确认密码",
                text: $registerConfirmPassword
            )

            ActionButton(
                title: "完成注册",
                isLoading: authManager.isLoading,
                action: handleCompleteRegistration
            )
        }
    }

    // MARK: - Third Party Login

    /// 第三方登录区域
    private var thirdPartyLoginSection: some View {
        VStack(spacing: 20) {
            // 分隔线
            HStack {
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 1)

                Text("或者使用以下方式登录")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 12)

                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 1)
            }

            // 第三方登录按钮
            VStack(spacing: 12) {
                // Apple登录
                ThirdPartyButton(
                    icon: "apple.logo",
                    title: "使用 Apple 登录",
                    backgroundColor: .black,
                    action: {
                        showToastMessage("Apple 登录即将开放")
                    }
                )

                // Google登录
                ThirdPartyButton(
                    icon: "g.circle.fill",
                    title: "使用 Google 登录",
                    backgroundColor: .white,
                    foregroundColor: .black,
                    action: {
                        showToastMessage("Google 登录即将开放")
                    }
                )
            }
        }
    }

    // MARK: - Forgot Password Sheet

    /// 忘记密码弹窗
    private var forgotPasswordSheet: some View {
        NavigationView {
            ZStack {
                Color(red: 0.1, green: 0.1, blue: 0.2)
                    .ignoresSafeArea()

                VStack(spacing: 30) {
                    Spacer()

                    // 根据步骤显示不同内容
                    switch resetStep {
                    case .enterEmail:
                        resetStepOne
                    case .enterCode:
                        resetStepTwo
                    case .enterPassword:
                        resetStepThree
                    }

                    // 错误提示
                    if let error = authManager.errorMessage {
                        ErrorMessage(text: error)
                    }

                    Spacer()
                }
                .padding(30)
            }
            .navigationTitle("找回密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        showForgotPassword = false
                        authManager.resetState()
                        resetStep = .enterEmail
                    }
                    .foregroundColor(.cyan)
                }
            }
        }
    }

    /// 重置密码第一步
    private var resetStepOne: some View {
        VStack(spacing: 20) {
            Text("输入注册邮箱")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            CustomTextField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $resetEmail,
                keyboardType: .emailAddress
            )

            ActionButton(
                title: "发送验证码",
                isLoading: authManager.isLoading,
                action: handleSendResetOTP
            )
        }
    }

    /// 重置密码第二步
    private var resetStepTwo: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("验证码已发送到")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                Text(resetEmail)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }

            OTPTextField(text: $resetCode)

            if resetResendCountdown > 0 {
                Text("\(resetResendCountdown)秒后可重发")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            } else {
                Button(action: handleSendResetOTP) {
                    Text("重新发送验证码")
                        .font(.system(size: 14))
                        .foregroundColor(.cyan)
                }
            }

            ActionButton(
                title: "验证",
                isLoading: authManager.isLoading,
                action: handleVerifyResetOTP
            )
        }
    }

    /// 重置密码第三步
    private var resetStepThree: some View {
        VStack(spacing: 20) {
            Text("设置新密码")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "新密码（至少6位）",
                text: $resetPassword
            )

            CustomSecureField(
                icon: "lock.fill",
                placeholder: "确认新密码",
                text: $resetConfirmPassword
            )

            ActionButton(
                title: "重置密码",
                isLoading: authManager.isLoading,
                action: handleResetPassword
            )
        }
    }

    // MARK: - Toast View

    /// Toast提示视图
    private var toastView: some View {
        VStack {
            Spacer()

            Text(toastMessage)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.8))
                .cornerRadius(20)
                .padding(.bottom, 50)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.3), value: showToast)
    }

    // MARK: - Actions

    /// 处理登录
    private func handleLogin() {
        guard !loginEmail.isEmpty, !loginPassword.isEmpty else {
            showToastMessage("请输入邮箱和密码")
            return
        }

        Task {
            await authManager.signIn(email: loginEmail, password: loginPassword)
        }
    }

    /// 处理发送注册验证码
    private func handleSendRegisterOTP() {
        guard !registerEmail.isEmpty else {
            showToastMessage("请输入邮箱地址")
            return
        }

        guard isValidEmail(registerEmail) else {
            showToastMessage("请输入有效的邮箱地址")
            return
        }

        Task {
            await authManager.sendRegisterOTP(email: registerEmail)
            if authManager.otpSent {
                startResendCountdown()
            }
        }
    }

    /// 处理验证注册验证码
    private func handleVerifyRegisterOTP() {
        guard registerCode.count == 6 else {
            showToastMessage("请输入6位验证码")
            return
        }

        Task {
            await authManager.verifyRegisterOTP(email: registerEmail, code: registerCode)
        }
    }

    /// 处理完成注册
    private func handleCompleteRegistration() {
        guard !registerPassword.isEmpty, !registerConfirmPassword.isEmpty else {
            showToastMessage("请输入密码")
            return
        }

        guard registerPassword.count >= 6 else {
            showToastMessage("密码至少需要6位")
            return
        }

        guard registerPassword == registerConfirmPassword else {
            showToastMessage("两次输入的密码不一致")
            return
        }

        Task {
            await authManager.completeRegistration(password: registerPassword)
        }
    }

    /// 处理发送重置密码验证码
    private func handleSendResetOTP() {
        guard !resetEmail.isEmpty else {
            showToastMessage("请输入邮箱地址")
            return
        }

        guard isValidEmail(resetEmail) else {
            showToastMessage("请输入有效的邮箱地址")
            return
        }

        Task {
            await authManager.sendResetOTP(email: resetEmail)
            if authManager.otpSent {
                resetStep = .enterCode
                startResetResendCountdown()
            }
        }
    }

    /// 处理验证重置密码验证码
    private func handleVerifyResetOTP() {
        guard resetCode.count == 6 else {
            showToastMessage("请输入6位验证码")
            return
        }

        Task {
            await authManager.verifyResetOTP(email: resetEmail, code: resetCode)
            if authManager.otpVerified {
                resetStep = .enterPassword
            }
        }
    }

    /// 处理重置密码
    private func handleResetPassword() {
        guard !resetPassword.isEmpty, !resetConfirmPassword.isEmpty else {
            showToastMessage("请输入新密码")
            return
        }

        guard resetPassword.count >= 6 else {
            showToastMessage("密码至少需要6位")
            return
        }

        guard resetPassword == resetConfirmPassword else {
            showToastMessage("两次输入的密码不一致")
            return
        }

        Task {
            await authManager.resetPassword(newPassword: resetPassword)
            if authManager.isAuthenticated {
                showForgotPassword = false
                showToastMessage("密码重置成功")
            }
        }
    }

    // MARK: - Helper Methods

    /// 验证邮箱格式
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    /// 显示Toast提示
    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showToast = false
            }
        }
    }

    /// 开始重发倒计时（注册）
    private func startResendCountdown() {
        resendCountdown = 60
        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if resendCountdown > 0 {
                resendCountdown -= 1
            } else {
                resendTimer?.invalidate()
            }
        }
    }

    /// 开始重发倒计时（重置密码）
    private func startResetResendCountdown() {
        resetResendCountdown = 60
        resetResendTimer?.invalidate()
        resetResendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if resetResendCountdown > 0 {
                resetResendCountdown -= 1
            } else {
                resetResendTimer?.invalidate()
            }
        }
    }

    /// 停止所有计时器
    private func stopTimers() {
        resendTimer?.invalidate()
        resetResendTimer?.invalidate()
    }
}

// MARK: - Custom Components

/// 自定义文本输入框
struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

/// 自定义密码输入框
struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)

            SecureField(placeholder, text: $text)
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

/// 验证码输入框
struct OTPTextField: View {
    @Binding var text: String

    var body: some View {
        TextField("", text: $text)
            .font(.system(size: 32, weight: .medium, design: .monospaced))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .keyboardType(.numberPad)
            .frame(height: 60)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .onChange(of: text) { _, newValue in
                // 限制只能输入6位数字
                let filtered = newValue.filter { $0.isNumber }
                if filtered.count > 6 {
                    text = String(filtered.prefix(6))
                } else {
                    text = filtered
                }
            }
    }
}

/// 操作按钮
struct ActionButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(
                    colors: [.blue, .cyan],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .disabled(isLoading)
    }
}

/// 第三方登录按钮
struct ThirdPartyButton: View {
    let icon: String
    let title: String
    var backgroundColor: Color = .white
    var foregroundColor: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(backgroundColor)
            .cornerRadius(12)
        }
    }
}

/// 步骤指示器
struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? Color.cyan : Color.gray.opacity(0.3))
                    .frame(width: 10, height: 10)
            }
        }
    }
}

/// 错误提示
struct ErrorMessage: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(.red)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    AuthView()
}
