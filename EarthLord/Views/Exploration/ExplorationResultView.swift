//
//  ExplorationResultView.swift
//  EarthLord
//
//  Created by Claude Code
//

import SwiftUI

/// 探索结果状态
enum ExplorationStatus {
    case success(ExplorationResult)
    case failure(String)  // 错误信息
}

/// 探索结果弹窗视图
struct ExplorationResultView: View {
    // MARK: - Properties
    let status: ExplorationStatus
    let poiName: String?  // 可选，如果是从POI搜寻的
    let onRetry: (() -> Void)?  // 重试回调

    @Environment(\.dismiss) private var dismiss

    // 便捷初始化器 - 成功状态
    init(result: ExplorationResult, poiName: String? = nil) {
        self.status = .success(result)
        self.poiName = poiName
        self.onRetry = nil
    }

    // 完整初始化器 - 支持失败状态
    init(status: ExplorationStatus, poiName: String? = nil, onRetry: (() -> Void)? = nil) {
        self.status = status
        self.poiName = poiName
        self.onRetry = onRetry
    }

    // MARK: - Animation State
    @State private var animatedDistance: Double = 0
    @State private var animatedArea: Double = 0
    @State private var animatedTotalDistance: Double = 0
    @State private var animatedTotalArea: Double = 0
    @State private var animatedExperience: Int = 0
    @State private var showItems: [Bool] = []
    @State private var showCheckmarks: [Bool] = []

    // MARK: - Body
    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            switch status {
            case .success(let result):
                successView(result: result)
            case .failure(let errorMessage):
                errorView(errorMessage: errorMessage)
            }
        }
    }

    // MARK: - Success View
    /// 成功状态视图
    private func successView(result: ExplorationResult) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // 成就标题区域
                achievementHeader

                // 统计数据卡片
                statsCard(result: result)

                // 奖励物品卡片
                rewardsCard(result: result)

                // 确认按钮
                confirmButton
                    .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 30)
        }
        .onAppear {
            startAnimations(result: result)
        }
    }

    // MARK: - Error View
    /// 错误状态视图
    private func errorView(errorMessage: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // 错误图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.danger.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(ApocalypseTheme.danger)
            }

            // 错误信息
            VStack(spacing: 12) {
                Text("探索失败")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(errorMessage)
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            // 按钮区域
            VStack(spacing: 12) {
                // 重试按钮
                if let onRetry = onRetry {
                    Button(action: {
                        dismiss()
                        onRetry()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
                            Text("重试")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(12)
                    }
                }

                // 关闭按钮
                Button(action: { dismiss() }) {
                    Text("关闭")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()
        }
    }

    // MARK: - Achievement Header
    /// 成就标题区域
    private var achievementHeader: some View {
        VStack(spacing: 20) {
            // 大图标带光晕效果
            ZStack {
                // 外圈光晕
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                ApocalypseTheme.primary.opacity(0.3),
                                ApocalypseTheme.primary.opacity(0.1),
                                .clear
                            ]),
                            center: .center,
                            startRadius: 30,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                // 中圈背景
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                ApocalypseTheme.primary,
                                ApocalypseTheme.primaryDark
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: ApocalypseTheme.primary.opacity(0.5), radius: 20, x: 0, y: 10)

                // 图标
                Image(systemName: "map.fill")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.white)
            }

            // 大文字
            VStack(spacing: 8) {
                Text("探索完成！")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if let poiName = poiName {
                    Text("成功搜寻了 \(poiName)")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            // 装饰线
            HStack(spacing: 12) {
                decorativeLine
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.primary)
                decorativeLine
            }
            .padding(.horizontal, 40)
        }
    }

    /// 装饰线
    private var decorativeLine: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        ApocalypseTheme.primary.opacity(0.5),
                        .clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
    }

    // MARK: - Stats Card
    /// 统计数据卡片
    private func statsCard(result: ExplorationResult) -> some View {
        ELCard(padding: 20) {
            VStack(alignment: .leading, spacing: 18) {
                // 标题
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 18))
                        .foregroundColor(ApocalypseTheme.info)

                    Text("探索统计")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 行走距离
                statRow(
                    icon: "figure.walk",
                    iconColor: .blue,
                    title: "行走距离",
                    current: "\(Int(animatedDistance))米",
                    total: "\(Int(animatedTotalDistance))米",
                    ranking: result.distanceRanking
                )

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 探索面积
                statRow(
                    icon: "map",
                    iconColor: .green,
                    title: "探索面积",
                    current: formatArea(animatedArea),
                    total: formatArea(animatedTotalArea),
                    ranking: result.areaRanking
                )

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 探索时长
                HStack(spacing: 12) {
                    // 图标
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: "clock.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.orange)
                    }

                    // 信息
                    VStack(alignment: .leading, spacing: 4) {
                        Text("探索时长")
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Text(formatDuration(result.duration))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }

                    Spacer()
                }

                // 经验值（如果有）
                if result.experienceGained > 0 {
                    Divider()
                        .background(ApocalypseTheme.textMuted.opacity(0.3))

                    HStack(spacing: 12) {
                        // 图标
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.15))
                                .frame(width: 40, height: 40)

                            Image(systemName: "star.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.purple)
                        }

                        // 信息
                        VStack(alignment: .leading, spacing: 4) {
                            Text("获得经验")
                                .font(.system(size: 13))
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            Text("+\(animatedExperience) EXP")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.purple)
                        }

                        Spacer()
                    }
                }
            }
        }
    }

    /// 统计行（带排名）
    private func statRow(icon: String, iconColor: Color, title: String, current: String, total: String, ranking: Int) -> some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }

            // 信息
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("本次")
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.textMuted)
                        Text(current)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }

                    Divider()
                        .frame(height: 30)
                        .background(ApocalypseTheme.textMuted.opacity(0.3))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("累计")
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.textMuted)
                        Text(total)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                }
            }

            Spacer()

            // 排名
            rankingBadge(ranking)
        }
    }

    /// 排名徽章
    private func rankingBadge(_ rank: Int) -> some View {
        VStack(spacing: 2) {
            Text("#\(rank)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ApocalypseTheme.success)

            Text("排名")
                .font(.system(size: 10))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(ApocalypseTheme.success.opacity(0.15))
        .cornerRadius(8)
    }

    // MARK: - Rewards Card
    /// 奖励物品卡片
    private func rewardsCard(result: ExplorationResult) -> some View {
        ELCard(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                // 标题
                HStack(spacing: 8) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 18))
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("获得物品")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()
                }

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 物品列表
                if result.itemsFound.isEmpty {
                    HStack {
                        Spacer()
                        Text("未获得任何物品")
                            .font(.system(size: 14))
                            .foregroundColor(ApocalypseTheme.textMuted)
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else {
                    ForEach(Array(result.itemsFound.keys.sorted().enumerated()), id: \.element) { index, itemId in
                        if let quantity = result.itemsFound[itemId],
                           let itemDef = MockExplorationData.getItemDefinition(id: itemId) {
                            itemRow(itemDef: itemDef, quantity: quantity, index: index)

                            if itemId != result.itemsFound.keys.sorted().last {
                                Divider()
                                    .background(ApocalypseTheme.textMuted.opacity(0.2))
                            }
                        }
                    }

                    // 底部提示
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(ApocalypseTheme.success)

                        Text("已添加到背包")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ApocalypseTheme.success)

                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    /// 物品行
    private func itemRow(itemDef: ItemDefinition, quantity: Int, index: Int) -> some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(categoryColor(itemDef.category).opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: categoryIcon(itemDef.category))
                    .font(.system(size: 20))
                    .foregroundColor(categoryColor(itemDef.category))
            }

            // 名称和数量
            VStack(alignment: .leading, spacing: 4) {
                Text(itemDef.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 6) {
                    Text("x\(quantity)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("•")
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text(itemDef.category.rawValue)
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            Spacer()

            // 绿色对勾 - 带弹跳动画
            if index < showCheckmarks.count && showCheckmarks[index] {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(ApocalypseTheme.success)
                    .scaleEffect(showCheckmarks[index] ? 1.0 : 0.1)
                    .animation(.spring(response: 0.4, dampingFraction: 0.5), value: showCheckmarks[index])
            }
        }
        .padding(.vertical, 4)
        .opacity(index < showItems.count && showItems[index] ? 1 : 0)
        .offset(x: index < showItems.count && showItems[index] ? 0 : 20)
    }

    // MARK: - Confirm Button
    /// 确认按钮
    private var confirmButton: some View {
        Button(action: { dismiss() }) {
            Text("确认")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            ApocalypseTheme.primary,
                            ApocalypseTheme.primaryDark
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: ApocalypseTheme.primary.opacity(0.4), radius: 10, x: 0, y: 4)
        }
    }

    // MARK: - Helpers

    /// 格式化面积
    private func formatArea(_ area: Double) -> String {
        if area >= 10000 {
            return String(format: "%.1f万㎡", area / 10000)
        } else {
            return "\(Int(area))㎡"
        }
    }

    /// 格式化时长
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }

    /// 分类颜色
    private func categoryColor(_ category: ItemCategory) -> Color {
        switch category {
        case .food: return .green
        case .water: return .blue
        case .material: return .brown
        case .tool: return .orange
        case .medical: return .red
        }
    }

    /// 分类图标
    private func categoryIcon(_ category: ItemCategory) -> String {
        switch category {
        case .food: return "fork.knife"
        case .water: return "drop.fill"
        case .material: return "hammer.fill"
        case .tool: return "wrench.and.screwdriver.fill"
        case .medical: return "cross.case.fill"
        }
    }

    // MARK: - Animation Functions
    /// 启动所有动画
    private func startAnimations(result: ExplorationResult) {
        // 初始化物品显示数组
        let itemCount = result.itemsFound.count
        showItems = Array(repeating: false, count: itemCount)
        showCheckmarks = Array(repeating: false, count: itemCount)

        // 统计数字动画
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
            animatedDistance = result.distanceWalked
            animatedTotalDistance = result.totalDistanceWalked
            animatedArea = result.areaExplored
            animatedTotalArea = result.totalAreaExplored
        }

        // 经验值动画（延迟一点）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedExperience = result.experienceGained
            }
        }

        // 物品依次出现动画
        for i in 0..<itemCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8 + Double(i) * 0.2) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showItems[i] = true
                }

                // 对勾图标延迟出现
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showCheckmarks[i] = true
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ExplorationResultView(
        result: MockExplorationData.sampleExplorationResult,
        poiName: "废弃超市"
    )
}
