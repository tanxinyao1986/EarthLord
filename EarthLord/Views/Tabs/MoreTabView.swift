//
//  MoreTabView.swift
//  EarthLord
//
//  Created by Claude on 2025/12/24.
//

import SwiftUI

struct MoreTabView: View {
    /// 认证管理器
    @ObservedObject private var authManager = AuthManager.shared

    /// 是否显示退出登录确认
    @State private var showLogoutConfirm = false

    /// 是否正在退出
    @State private var isLoggingOut = false

    var body: some View {
        NavigationStack {
            List {
                // 用户信息区域
                userProfileSection

                // 开发测试区域
                Section("开发测试") {
                    NavigationLink(destination: SupabaseTestView()) {
                        Label("Supabase 连接测试", systemImage: "network")
                    }

                    NavigationLink(destination: AuthDebugView()) {
                        Label("认证调试工具", systemImage: "person.badge.shield.checkmark")
                    }
                }

                // 退出登录
                logoutSection
            }
            .navigationTitle("更多")
            .alert("退出登录", isPresented: $showLogoutConfirm) {
                Button("取消", role: .cancel) { }
                Button("退出", role: .destructive) {
                    handleLogout()
                }
            } message: {
                Text("确定要退出登录吗？")
            }
            .disabled(isLoggingOut)
        }
    }

    // MARK: - 用户信息区域

    private var userProfileSection: some View {
        Section {
            HStack(spacing: 15) {
                // 用户头像
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    ApocalypseTheme.primary,
                                    ApocalypseTheme.primary.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)

                    if let avatarUrl = authManager.currentUser?.avatarUrl {
                        // TODO: 加载用户头像
                        AsyncImage(url: URL(string: avatarUrl)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            defaultAvatar
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                    } else {
                        defaultAvatar
                    }
                }

                // 用户信息
                VStack(alignment: .leading, spacing: 5) {
                    Text(authManager.currentUser?.username ?? "未设置用户名")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(authManager.currentUser?.email ?? "")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 8)
        } header: {
            Text("个人信息")
        }
    }

    // 默认头像
    private var defaultAvatar: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 40, height: 40)
            .foregroundColor(.white)
    }

    // MARK: - 退出登录区域

    private var logoutSection: some View {
        Section {
            Button(action: { showLogoutConfirm = true }) {
                HStack {
                    if isLoggingOut {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }

                    Text("退出登录")
                        .foregroundColor(.red)
                }
            }
            .disabled(isLoggingOut)
        }
    }

    // MARK: - 退出登录处理

    private func handleLogout() {
        isLoggingOut = true

        Task {
            await authManager.signOut()

            await MainActor.run {
                isLoggingOut = false
            }
        }
    }
}

#Preview {
    MoreTabView()
}
