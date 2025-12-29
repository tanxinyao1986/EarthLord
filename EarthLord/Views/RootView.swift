//
//  RootView.swift
//  EarthLord
//
//  Created by Claude on 2025/12/24.
//

import SwiftUI

/// 根视图：控制启动页、认证页与主界面的切换
struct RootView: View {
    /// 认证管理器
    @StateObject private var authManager = AuthManager.shared

    /// 启动页是否完成
    @State private var splashFinished = false

    var body: some View {
        ZStack {
            if !splashFinished {
                // 显示启动页
                SplashView(isFinished: $splashFinished)
                    .transition(.opacity)
            } else if authManager.isAuthenticated && !authManager.needsPasswordSetup {
                // 已登录且完成所有设置，显示主页面
                MainTabView()
                    .transition(.opacity)
            } else {
                // 未登录或需要完成注册流程，显示认证页面
                AuthView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: splashFinished)
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: authManager.needsPasswordSetup)
    }
}

#Preview {
    RootView()
}
