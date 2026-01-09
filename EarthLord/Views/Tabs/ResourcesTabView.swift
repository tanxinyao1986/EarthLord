//
//  ResourcesTabView.swift
//  EarthLord
//
//  Created by Claude Code
//

import SwiftUI

/// 资源模块主入口页面
struct ResourcesTabView: View {
    // MARK: - State
    @State private var selectedSegment = 0
    @State private var isTradingEnabled = false  // 交易开关假数据

    // 分段选项
    private let segments = ["POI", "背包", "已购", "领地", "交易"]

    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 顶部区域（标题 + 交易开关）
                    headerSection

                    // 分段选择器
                    segmentedPicker
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 12)

                    // 内容区域
                    contentArea
                }
            }
            .navigationTitle("资源")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Header Section
    /// 顶部区域
    private var headerSection: some View {
        HStack {
            Spacer()

            // 交易开关
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(isTradingEnabled ? ApocalypseTheme.success : ApocalypseTheme.textMuted)

                Text(isTradingEnabled ? "交易开启" : "交易关闭")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Toggle("", isOn: $isTradingEnabled)
                    .labelsHidden()
                    .tint(ApocalypseTheme.success)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(20)
            .padding(.trailing, 16)
        }
        .padding(.top, 8)
    }

    // MARK: - Segmented Picker
    /// 分段选择器
    private var segmentedPicker: some View {
        Picker("选择分段", selection: $selectedSegment) {
            ForEach(0..<segments.count, id: \.self) { index in
                Text(segments[index])
                    .tag(index)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Content Area
    /// 内容区域
    private var contentArea: some View {
        Group {
            switch selectedSegment {
            case 0:
                // POI分段
                POIListView()
            case 1:
                // 背包分段
                BackpackView()
            case 2:
                // 已购分段
                placeholderView(icon: "bag.fill", title: "已购功能", subtitle: "功能开发中")
            case 3:
                // 领地分段
                placeholderView(icon: "map.fill", title: "领地资源", subtitle: "功能开发中")
            case 4:
                // 交易分段
                placeholderView(icon: "arrow.left.arrow.right", title: "交易市场", subtitle: "功能开发中")
            default:
                EmptyView()
            }
        }
    }

    // MARK: - Placeholder View
    /// 占位视图
    private func placeholderView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()
        }
    }
}

// MARK: - Preview
#Preview {
    ResourcesTabView()
}
