//
//  POIDetailView.swift
//  EarthLord
//
//  Created by Claude Code
//

import SwiftUI

/// POI详情视图
struct POIDetailView: View {
    // MARK: - Properties
    let poi: PointOfInterest

    // MARK: - State
    @State private var showExplorationResult = false
    @Environment(\.dismiss) private var dismiss

    // 假数据：距离
    private let mockDistance: Double = 350  // 米

    // MARK: - Body
    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // 顶部大图区域
                    headerImageSection

                    // 内容区域
                    VStack(spacing: 16) {
                        // 信息卡片
                        infoCard

                        // 操作按钮区域
                        actionButtons
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showExplorationResult) {
            ExplorationResultView(
                result: MockExplorationData.sampleExplorationResult,
                poiName: poi.name
            )
        }
    }

    // MARK: - Header Image Section
    /// 顶部大图区域
    private var headerImageSection: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 渐变背景
                LinearGradient(
                    gradient: Gradient(colors: [poiColor, poiColor.opacity(0.7)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // 中间大图标
                Image(systemName: poiIcon)
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, 60)

                // 底部半透明遮罩和文字
                VStack(alignment: .leading, spacing: 6) {
                    Text(poi.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        Image(systemName: poiIcon)
                            .font(.system(size: 14))

                        Text(poi.type)
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.width * 0.9)
        }
        .frame(height: UIScreen.main.bounds.height * 0.35)
    }

    // MARK: - Info Card
    /// 信息卡片
    private var infoCard: some View {
        ELCard(padding: 20) {
            VStack(spacing: 16) {
                // 距离
                infoRow(
                    icon: "location.fill",
                    iconColor: ApocalypseTheme.info,
                    title: "距离",
                    value: "\(Int(mockDistance))米"
                )

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 物资状态
                infoRow(
                    icon: "cube.box.fill",
                    iconColor: resourceStatusColor,
                    title: "物资状态",
                    value: resourceStatusText
                )

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 危险等级
                infoRow(
                    icon: "exclamationmark.triangle.fill",
                    iconColor: dangerLevelColor,
                    title: "危险等级",
                    value: dangerLevelText
                )

                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 来源
                infoRow(
                    icon: "map.fill",
                    iconColor: ApocalypseTheme.textSecondary,
                    title: "来源",
                    value: "地图数据"
                )
            }
        }
    }

    // MARK: - Info Row
    /// 信息行组件
    private func infoRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            // 图标
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }

            // 标题和值
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Spacer()
        }
    }

    // MARK: - Action Buttons
    /// 操作按钮区域
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 主按钮：搜寻此POI
            Button(action: {
                if poi.status != .depleted {
                    showExplorationResult = true
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: poi.status == .depleted ? "exclamationmark.circle.fill" : "magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))

                    Text(poi.status == .depleted ? "此地点已被搜空" : "搜寻此POI")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    Group {
                        if poi.status == .depleted {
                            ApocalypseTheme.textMuted
                        } else {
                            LinearGradient(
                                gradient: Gradient(colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                    }
                )
                .cornerRadius(12)
                .shadow(color: poi.status == .depleted ? .clear : ApocalypseTheme.primary.opacity(0.4), radius: 10, x: 0, y: 4)
            }
            .disabled(poi.status == .depleted)

            // 小按钮区域
            HStack(spacing: 12) {
                // 标记已发现
                secondaryButton(
                    title: "标记已发现",
                    icon: "eye.fill",
                    color: ApocalypseTheme.info
                ) {
                    print("标记POI已发现: \(poi.name)")
                }

                // 标记无物资
                secondaryButton(
                    title: "标记无物资",
                    icon: "xmark.circle.fill",
                    color: ApocalypseTheme.warning
                ) {
                    print("标记POI无物资: \(poi.name)")
                }
            }
        }
    }

    // MARK: - Secondary Button
    /// 次要按钮组件
    private func secondaryButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(color)
            .cornerRadius(10)
        }
    }

    // MARK: - POI Type Styling
    /// 根据POI类型返回对应颜色
    private var poiColor: Color {
        switch poi.type {
        case "医院":
            return Color.red
        case "超市":
            return Color.green
        case "工厂":
            return Color.gray
        case "药店":
            return Color.purple
        case "加油站":
            return Color.orange
        default:
            return ApocalypseTheme.primary
        }
    }

    /// 根据POI类型返回对应图标
    private var poiIcon: String {
        switch poi.type {
        case "医院":
            return "cross.case.fill"
        case "超市":
            return "cart.fill"
        case "工厂":
            return "building.2.fill"
        case "药店":
            return "pills.fill"
        case "加油站":
            return "fuelpump.fill"
        default:
            return "mappin.circle.fill"
        }
    }

    // MARK: - Resource Status
    /// 物资状态文字
    private var resourceStatusText: String {
        switch poi.status {
        case .undiscovered:
            return "未知"
        case .discovered:
            if let resources = poi.estimatedResources, !resources.isEmpty {
                let total = resources.values.reduce(0, +)
                return "有物资（约\(total)件）"
            } else {
                return "可能有物资"
            }
        case .depleted:
            return "已清空"
        }
    }

    /// 物资状态颜色
    private var resourceStatusColor: Color {
        switch poi.status {
        case .undiscovered:
            return ApocalypseTheme.textMuted
        case .discovered:
            if let resources = poi.estimatedResources, !resources.isEmpty {
                return ApocalypseTheme.success
            } else {
                return ApocalypseTheme.warning
            }
        case .depleted:
            return ApocalypseTheme.danger
        }
    }

    // MARK: - Danger Level
    /// 危险等级文字
    private var dangerLevelText: String {
        switch poi.dangerLevel {
        case 1:
            return "安全"
        case 2:
            return "低危"
        case 3:
            return "中危"
        case 4:
            return "高危"
        case 5:
            return "极危"
        default:
            return "未知"
        }
    }

    /// 危险等级颜色
    private var dangerLevelColor: Color {
        switch poi.dangerLevel {
        case 1:
            return ApocalypseTheme.success
        case 2:
            return Color.green
        case 3:
            return ApocalypseTheme.warning
        case 4:
            return ApocalypseTheme.danger
        case 5:
            return Color.purple
        default:
            return ApocalypseTheme.textMuted
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        POIDetailView(poi: MockExplorationData.pointsOfInterest[0])
    }
}
