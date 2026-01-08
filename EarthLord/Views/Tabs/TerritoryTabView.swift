//
//  TerritoryTabView.swift
//  EarthLord
//
//  领地管理页面 - 显示我的领地列表
//

import SwiftUI

struct TerritoryTabView: View {
    // MARK: - 状态管理

    @ObservedObject private var languageManager = LanguageManager.shared
    private let territoryManager = TerritoryManager.shared

    @State private var myTerritories: [Territory] = []
    @State private var selectedTerritory: Territory?
    @State private var isLoading = false
    @State private var errorMessage: String?

    // MARK: - 计算属性

    /// 总面积
    private var totalArea: Double {
        myTerritories.reduce(0) { $0 + $1.area }
    }

    /// 格式化总面积
    private var formattedTotalArea: String {
        if totalArea >= 1_000_000 {
            return String(format: "%.2f km²", totalArea / 1_000_000)
        } else {
            return String(format: "%.0f m²", totalArea)
        }
    }

    // MARK: - 视图主体

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                if isLoading {
                    // 加载中
                    ProgressView("加载中...")
                        .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                } else if myTerritories.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    // 领地列表
                    ScrollView {
                        VStack(spacing: 16) {
                            // 统计头部
                            statisticsHeader

                            // 领地列表
                            ForEach(myTerritories) { territory in
                                TerritoryCard(territory: territory)
                                    .onTapGesture {
                                        selectedTerritory = territory
                                    }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 100)
                    }
                    .refreshable {
                        await loadMyTerritories()
                    }
                }
            }
            .navigationTitle("我的领地")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                Task {
                    await loadMyTerritories()
                }
            }
            .sheet(item: $selectedTerritory) { territory in
                TerritoryDetailView(
                    territory: territory,
                    onDelete: {
                        Task {
                            await loadMyTerritories()
                        }
                    }
                )
            }
        }
        .refreshOnLanguageChange()
    }

    // MARK: - 子视图

    /// 统计头部
    private var statisticsHeader: some View {
        HStack(spacing: 16) {
            // 领地数量
            StatisticCard(
                icon: "flag.fill",
                title: "领地数量",
                value: "\(myTerritories.count)",
                color: ApocalypseTheme.primary
            )

            // 总面积
            StatisticCard(
                icon: "map.fill",
                title: "总面积",
                value: formattedTotalArea,
                color: ApocalypseTheme.success
            )
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "flag.slash")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text("还没有领地")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("前往地图页面开始圈地吧！")
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - 数据加载

    /// 加载我的领地
    private func loadMyTerritories() async {
        isLoading = true
        errorMessage = nil

        do {
            myTerritories = try await territoryManager.loadMyTerritories()
        } catch {
            errorMessage = error.localizedDescription
            LogManager.shared.error("加载我的领地失败: \(error.localizedDescription)")
        }

        isLoading = false
    }
}

// MARK: - 统计卡片

struct StatisticCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(title)
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            ApocalypseTheme.cardBackground
                .cornerRadius(12)
        )
    }
}

// MARK: - 领地卡片

struct TerritoryCard: View {
    let territory: Territory

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Text(territory.displayName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            // 信息行
            HStack(spacing: 16) {
                // 面积
                InfoLabel(
                    icon: "map.fill",
                    text: territory.formattedArea,
                    color: ApocalypseTheme.success
                )

                // 点数
                if let pointCount = territory.pointCount {
                    InfoLabel(
                        icon: "location.fill",
                        text: "\(pointCount) 个点",
                        color: ApocalypseTheme.primary
                    )
                }
            }

            // 时间
            if let createdAt = territory.createdAt {
                Text("创建于 \(formatDate(createdAt))")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .padding(16)
        .background(
            ApocalypseTheme.cardBackground
                .cornerRadius(12)
        )
    }

    /// 格式化日期
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        return displayFormatter.string(from: date)
    }
}

// MARK: - 信息标签

struct InfoLabel: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }
}

// MARK: - 预览

#Preview {
    TerritoryTabView()
}
