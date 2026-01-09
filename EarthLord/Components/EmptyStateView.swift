//
//  EmptyStateView.swift
//  EarthLord
//
//  Created by Claude Code
//

import SwiftUI

/// 通用空状态视图组件
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var iconSize: CGFloat = 60

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: iconSize))
                .foregroundColor(ApocalypseTheme.textMuted)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

/// 错误状态视图组件
struct ErrorStateView: View {
    let icon: String
    let title: String
    let message: String
    let retryAction: (() -> Void)?
    var iconSize: CGFloat = 60

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // 错误图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.danger.opacity(0.15))
                    .frame(width: iconSize + 40, height: iconSize + 40)

                Image(systemName: icon)
                    .font(.system(size: iconSize))
                    .foregroundColor(ApocalypseTheme.danger)
            }

            // 错误信息
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            // 重试按钮
            if let retryAction = retryAction {
                Button(action: retryAction) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                        Text("重试")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview
#Preview("Empty State") {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        EmptyStateView(
            icon: "tray.fill",
            title: "没有数据",
            subtitle: "尝试刷新或稍后再试"
        )
    }
}

#Preview("Error State") {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        ErrorStateView(
            icon: "exclamationmark.triangle.fill",
            title: "加载失败",
            message: "无法加载数据，请检查网络连接",
            retryAction: {
                print("重试")
            }
        )
    }
}
