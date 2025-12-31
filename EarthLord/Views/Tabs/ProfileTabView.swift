//
//  ProfileTabView.swift
//  EarthLord
//
//  Created by Claude on 2025/12/24.
//

import SwiftUI

struct ProfileTabView: View {
    /// 认证管理器
    @ObservedObject private var authManager = AuthManager.shared

    /// 语言管理器
    @ObservedObject private var languageManager = LanguageManager.shared

    /// 是否显示退出登录确认
    @State private var showLogoutConfirm = false

    /// 是否正在退出
    @State private var isLoggingOut = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // 顶部背景
                    headerBackground

                    // 用户信息卡片
                    userInfoCard
                        .padding(.horizontal, 20)
                        .offset(y: -50)

                    // 统计数据
                    statsSection
                        .padding(.horizontal, 20)
                        .padding(.top, -30)

                    // 功能区域
                    actionsSection
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    // 退出登录按钮
                    logoutButton
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarHidden(true)
            .alert(Text("退出登录".localized()), isPresented: $showLogoutConfirm) {
                Button(role: .cancel) {
                } label: {
                    Text("取消".localized())
                }
                Button(role: .destructive) {
                    handleLogout()
                } label: {
                    Text("退出".localized())
                }
            } message: {
                Text("确定要退出登录吗？".localized())
            }
            .refreshOnLanguageChange()
        }
    }

    // MARK: - 顶部背景

    private var headerBackground: some View {
        ZStack {
            // 渐变背景
            LinearGradient(
                gradient: Gradient(colors: [
                    ApocalypseTheme.primary,
                    ApocalypseTheme.primary.opacity(0.7)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 200)

            // 装饰图案
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 300, height: 300)
                .offset(x: 100, y: -50)
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - 用户信息卡片

    private var userInfoCard: some View {
        VStack(spacing: 15) {
            // 头像
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 100, height: 100)
                    .shadow(color: .black.opacity(0.1), radius: 10)

                if let avatarUrl = authManager.currentUser?.avatarUrl {
                    AsyncImage(url: URL(string: avatarUrl)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        defaultAvatar
                    }
                    .frame(width: 95, height: 95)
                    .clipShape(Circle())
                } else {
                    defaultAvatar
                }
            }

            // 用户名
            Text(authManager.currentUser?.username ?? "未设置用户名".localized())
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)

            // 邮箱
            Text(authManager.currentUser?.email ?? "")
                .font(.system(size: 15))
                .foregroundColor(.secondary)

            // 用户ID（小字）
            if let userId = authManager.currentUser?.id {
                Text("ID: \(userId.uuidString.prefix(8))...")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10)
    }

    // 默认头像
    private var defaultAvatar: some View {
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
                .frame(width: 95, height: 95)

            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .foregroundColor(.white)
        }
    }

    // MARK: - 统计数据

    private var statsSection: some View {
        HStack(spacing: 15) {
            statItem(title: "领地".localized(), value: "0", icon: "map.fill")
            statItem(title: "探索".localized(), value: "0", icon: "location.fill")
            statItem(title: "成就".localized(), value: "0", icon: "trophy.fill")
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 15)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }

    private func statItem(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(ApocalypseTheme.primary)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)

            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 功能区域

    private var actionsSection: some View {
        VStack(spacing: 12) {
            actionButton(icon: "bell.fill", title: "通知".localized(), color: .orange) {
                // TODO: 实现通知功能
            }

            // 设置 - 使用 NavigationLink
            NavigationLink(destination: SettingsView()) {
                HStack(spacing: 15) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.gray)
                        .frame(width: 30)

                    Text("设置".localized())
                        .font(.system(size: 16))
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }

            actionButton(icon: "info.circle.fill", title: "关于".localized(), color: .purple) {
                // TODO: 实现关于功能
            }

            actionButton(icon: "questionmark.circle.fill", title: "帮助与反馈".localized(), color: .green) {
                // TODO: 实现帮助功能
            }
        }
    }

    private func actionButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(color)
                    .frame(width: 30)

                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - 退出登录按钮

    private var logoutButton: some View {
        Button(action: { showLogoutConfirm = true }) {
            HStack(spacing: 15) {
                if isLoggingOut {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 22))
                }

                Text("退出登录".localized())
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.red)
            .cornerRadius(12)
        }
        .disabled(isLoggingOut)
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
    ProfileTabView()
}
