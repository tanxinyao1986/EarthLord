//
//  AIScavengeResultView.swift
//  EarthLord
//
//  AI 生成物品搜刮结果视图 - 展示独特名称和背景故事
//

import SwiftUI
import CoreLocation

/// AI 搜刮结果弹窗
struct AIScavengeResultView: View {
    // MARK: - Properties

    let result: AIScavengeResult
    @Environment(\.dismiss) private var dismiss

    // MARK: - Animation State

    @State private var showItems: [Bool] = []
    @State private var expandedStory: Int? = nil
    @State private var showHeader: Bool = false

    // MARK: - Body

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // 标题区域
                    headerSection
                        .opacity(showHeader ? 1 : 0)
                        .offset(y: showHeader ? 0 : -20)

                    // 物品列表
                    itemsSection

                    // 确认按钮
                    confirmButton
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 30)
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // 成功图标
            ZStack {
                // 外圈光晕
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                ApocalypseTheme.success.opacity(0.3),
                                ApocalypseTheme.success.opacity(0.1),
                                .clear
                            ]),
                            center: .center,
                            startRadius: 30,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(ApocalypseTheme.success.opacity(0.2))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(ApocalypseTheme.success)
            }

            // 标题
            VStack(spacing: 8) {
                Text("搜刮成功！")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                HStack(spacing: 4) {
                    Text(result.poi.category.emoji)
                    Text(result.poi.name)
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            // 危险等级标签
            dangerLevelBadge
        }
    }

    /// 危险等级徽章
    private var dangerLevelBadge: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { level in
                Image(systemName: level <= result.poi.dangerLevel ? "star.fill" : "star")
                    .font(.system(size: 12))
                    .foregroundColor(dangerColor(for: result.poi.dangerLevel))
            }

            Text(dangerText(for: result.poi.dangerLevel))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(dangerColor(for: result.poi.dangerLevel))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(dangerColor(for: result.poi.dangerLevel).opacity(0.15))
        .cornerRadius(20)
    }

    // MARK: - Items Section

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundColor(ApocalypseTheme.primary)
                Text("获得物品")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("\(result.totalQuantity) 件")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 物品卡片列表
            ForEach(Array(result.aiItems.enumerated()), id: \.offset) { index, item in
                if index < showItems.count && showItems[index] {
                    aiItemCard(item: item, index: index)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
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
        .padding(20)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    /// 单个 AI 物品卡片
    private func aiItemCard(item: AIGeneratedItem, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 物品头部
            HStack(spacing: 12) {
                // 稀有度图标
                ZStack {
                    Circle()
                        .fill(rarityColor(item.itemRarity).opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: categoryIcon(item.itemCategory))
                        .font(.system(size: 24))
                        .foregroundColor(rarityColor(item.itemRarity))
                }

                // 名称和分类
                VStack(alignment: .leading, spacing: 4) {
                    // 独特名称
                    Text(item.uniqueName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(rarityColor(item.itemRarity))

                    // 分类和数量
                    HStack(spacing: 8) {
                        Text(item.baseCategory)
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textMuted)

                        Text("x\(item.quantity)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                }

                Spacer()

                // 稀有度标签
                Text(item.rarity)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(rarityColor(item.itemRarity))
                    .cornerRadius(4)
            }

            // 背景故事（可展开）
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    expandedStory = expandedStory == index ? nil : index
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.info)

                    Text(expandedStory == index ? item.backstory : "点击查看背景故事...")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .lineLimit(expandedStory == index ? nil : 1)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: expandedStory == index ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(12)
            .background(ApocalypseTheme.background.opacity(0.5))
            .cornerRadius(8)
        }
        .padding(16)
        .background(ApocalypseTheme.background)
        .cornerRadius(12)
    }

    // MARK: - Confirm Button

    private var confirmButton: some View {
        Button(action: { dismiss() }) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                Text("收下物品")
                    .font(.system(size: 17, weight: .bold))
            }
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

    /// 启动动画
    private func startAnimations() {
        showItems = Array(repeating: false, count: result.aiItems.count)

        // 头部动画
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showHeader = true
        }

        // 物品依次出现动画
        for i in 0..<result.aiItems.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Double(i) * 0.2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    if i < showItems.count {
                        showItems[i] = true
                    }
                }
            }
        }
    }

    /// 稀有度颜色
    private func rarityColor(_ rarity: ItemRarity) -> Color {
        switch rarity {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }

    /// 分类图标
    private func categoryIcon(_ category: ItemCategory) -> String {
        switch category {
        case .water: return "drop.fill"
        case .food: return "fork.knife"
        case .medical: return "cross.case.fill"
        case .material: return "hammer.fill"
        case .tool: return "wrench.and.screwdriver.fill"
        }
    }

    /// 危险等级颜色
    private func dangerColor(for level: Int) -> Color {
        switch level {
        case 1, 2: return .green
        case 3: return .orange
        case 4, 5: return .red
        default: return .gray
        }
    }

    /// 危险等级文字
    private func dangerText(for level: Int) -> String {
        switch level {
        case 1: return "安全区"
        case 2: return "低危区"
        case 3: return "中危区"
        case 4: return "高危区"
        case 5: return "极危区"
        default: return "未知"
        }
    }
}

// MARK: - Preview

#Preview {
    AIScavengeResultView(
        result: AIScavengeResult(
            poi: POI(
                id: "test",
                name: "废弃超市",
                coordinate: CLLocationCoordinate2D(latitude: 31.23, longitude: 121.47),
                category: .supermarket,
                dangerLevel: 3
            ),
            aiItems: [
                AIGeneratedItem(
                    uniqueName: "老王的最后存货",
                    baseCategory: "食物",
                    rarity: "稀有",
                    backstory: "超市仓库角落发现的罐头，上面还贴着'老王私藏'的标签。这可能是末日前最后一批进货。",
                    quantity: 2
                ),
                AIGeneratedItem(
                    uniqueName: "锈迹斑斑的急救箱",
                    baseCategory: "医疗",
                    rarity: "罕见",
                    backstory: "货架下找到的急救箱，虽然外壳已锈，里面的绷带还算干净。",
                    quantity: 1
                ),
                AIGeneratedItem(
                    uniqueName: "末日幸存的矿泉水",
                    baseCategory: "水源",
                    rarity: "普通",
                    backstory: "收银台下的矿泉水，瓶身积满了灰尘，但水还是清澈的。",
                    quantity: 3
                )
            ],
            items: ["food_canned": 2, "medical_bandage": 1, "water_mineral": 3]
        )
    )
}
