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

    /// 位置管理器（用于获取当前位置）
    @StateObject private var locationManager = LocationManager.shared

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
        // Day23: App生命周期监听
        .onAppear {
            // App启动时启动位置上报
            if authManager.isAuthenticated {
                PlayerDensityManager.shared.startReporting()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            // 进入后台：标记离线并停止上报
            Task { @MainActor in
                await PlayerDensityManager.shared.markOffline()
                PlayerDensityManager.shared.stopReporting()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // 回到前台：标记在线并恢复上报
            Task { @MainActor in
                // 尝试使用当前位置标记在线（如果位置可用）
                if let location = locationManager.currentLocation {
                    await PlayerDensityManager.shared.markOnline(location)
                } else {
                    LogManager.shared.warning("[RootView] 回到前台时位置不可用，等待GPS更新后再标记在线")
                }

                if authManager.isAuthenticated {
                    PlayerDensityManager.shared.startReporting()
                }
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            // 登录状态变化时处理位置上报
            if isAuthenticated {
                PlayerDensityManager.shared.startReporting()
            } else {
                PlayerDensityManager.shared.stopReporting()
            }
        }
    }
}

#Preview {
    RootView()
}
