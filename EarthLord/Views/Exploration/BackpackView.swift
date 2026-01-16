//
//  BackpackView.swift
//  EarthLord
//
//  Created by Claude Code
//

import SwiftUI

/// 背包管理视图
struct BackpackView: View {
    // MARK: - State
    @StateObject private var inventoryManager = InventoryManager.shared
    @State private var searchText = ""
    @State private var selectedCategory: ItemCategory? = nil  // nil表示"全部"
    @State private var animatedWeight: Double = 0  // 用于动画的重量值
    @State private var showItems = false  // 控制物品显示动画
    @State private var isLoading = false
    @State private var loadError: String?

    // 背包容量设置
    private let maxCapacity: Double = 100.0  // 最大容量（kg）

    // MARK: - Computed Properties

    /// 背包物品列表
    private var inventoryItems: [InventoryItem] {
        inventoryManager.items
    }

    /// 当前背包总重量
    private var currentWeight: Double {
        inventoryManager.totalWeight
    }

    /// 容量使用百分比
    private var capacityPercentage: Double {
        currentWeight / maxCapacity
    }

    /// 容量进度条颜色
    private var capacityColor: Color {
        if capacityPercentage > 0.9 {
            return ApocalypseTheme.danger
        } else if capacityPercentage > 0.7 {
            return ApocalypseTheme.warning
        } else {
            return ApocalypseTheme.success
        }
    }

    /// 是否显示容量警告
    private var showCapacityWarning: Bool {
        capacityPercentage > 0.9
    }

    /// 筛选后的物品列表
    private var filteredItems: [InventoryItem] {
        var items = inventoryItems

        // 按分类筛选
        if let category = selectedCategory {
            items = items.filter { $0.definition?.category == category }
        }

        // 按搜索文字筛选
        if !searchText.isEmpty {
            items = items.filter { item in
                item.definition?.name.contains(searchText) ?? false
            }
        }

        return items
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            if isLoading {
                // 加载状态
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("加载中...")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            } else {
                VStack(spacing: 0) {
                    // 容量状态卡
                    capacityCard
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // 搜索框
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // 分类筛选
                    categoryFilter
                        .padding(.top, 12)

                    // 物品列表或空状态
                    if filteredItems.isEmpty {
                        emptyState
                    } else {
                        itemListView
                            .padding(.top, 16)
                    }
                }
            }
        }
        .navigationTitle("背包")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadInventoryData()
        }
        .onAppear {
            Task {
                await loadInventoryData()
            }
        }
    }

    // MARK: - Data Loading

    /// 加载背包数据
    private func loadInventoryData() async {
        isLoading = true
        loadError = nil

        do {
            try await inventoryManager.loadInventory()
            // 加载完成后动画显示重量
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedWeight = currentWeight
            }
        } catch {
            loadError = error.localizedDescription
            LogManager.shared.error("加载背包失败: \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Capacity Card
    /// 容量状态卡
    private var capacityCard: some View {
        ELCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                // 容量文字
                HStack {
                    Image(systemName: "backpack.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                        .font(.system(size: 18))

                    Text("背包容量：\(Int(animatedWeight)) / \(Int(maxCapacity))")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()

                    Text("\(Int(animatedWeight / maxCapacity * 100))%")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(capacityColor)
                }

                // 进度条
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ApocalypseTheme.background)
                            .frame(height: 8)

                        // 进度
                        RoundedRectangle(cornerRadius: 8)
                            .fill(capacityColor)
                            .frame(width: geometry.size.width * (animatedWeight / maxCapacity), height: 8)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animatedWeight)
                    }
                }
                .frame(height: 8)

                // 警告文字
                if showCapacityWarning {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                        Text("背包快满了！")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(ApocalypseTheme.danger)
                }
            }
        }
    }

    // MARK: - Search Bar
    /// 搜索框
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .font(.system(size: 16))

                TextField("搜索物品", text: $searchText)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .font(.system(size: 15))

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.textMuted)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(10)
        }
    }

    // MARK: - Category Filter
    /// 分类筛选工具栏
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "全部"按钮
                CategoryButton(
                    title: "全部",
                    icon: "square.grid.2x2.fill",
                    color: ApocalypseTheme.primary,
                    isSelected: selectedCategory == nil,
                    action: { selectedCategory = nil }
                )

                // 各分类按钮
                CategoryButton(
                    title: "食物",
                    icon: "fork.knife",
                    color: .green,
                    isSelected: selectedCategory == .food,
                    action: { selectedCategory = .food }
                )

                CategoryButton(
                    title: "水",
                    icon: "drop.fill",
                    color: .blue,
                    isSelected: selectedCategory == .water,
                    action: { selectedCategory = .water }
                )

                CategoryButton(
                    title: "材料",
                    icon: "hammer.fill",
                    color: .brown,
                    isSelected: selectedCategory == .material,
                    action: { selectedCategory = .material }
                )

                CategoryButton(
                    title: "工具",
                    icon: "wrench.and.screwdriver.fill",
                    color: .orange,
                    isSelected: selectedCategory == .tool,
                    action: { selectedCategory = .tool }
                )

                CategoryButton(
                    title: "医疗",
                    icon: "cross.case.fill",
                    color: .red,
                    isSelected: selectedCategory == .medical,
                    action: { selectedCategory = .medical }
                )
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Item List View
    /// 物品列表
    private var itemListView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(filteredItems) { item in
                    ItemCardView(item: item, itemDefinitions: inventoryManager.itemDefinitions)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedCategory)
        }
        .onChange(of: currentWeight) { _, newWeight in
            // 重量变化时动画更新
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedWeight = newWeight
            }
        }
    }

    // MARK: - Empty State
    /// 空状态视图
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            // 根据不同情况显示不同图标
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text(emptyStateSubtitle)
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    /// 空状态图标
    private var emptyStateIcon: String {
        if inventoryItems.isEmpty {
            return "backpack.fill"
        } else if !searchText.isEmpty {
            return "magnifyingglass"
        } else {
            return "tray.fill"
        }
    }

    /// 空状态标题
    private var emptyStateTitle: String {
        if inventoryItems.isEmpty {
            return "背包空空如也"
        } else if !searchText.isEmpty {
            return "没有找到相关物品"
        } else {
            return "没有找到该分类的物品"
        }
    }

    /// 空状态副标题
    private var emptyStateSubtitle: String {
        if inventoryItems.isEmpty {
            return "去探索收集物资吧"
        } else if !searchText.isEmpty {
            return "尝试使用其他关键词搜索"
        } else {
            return "尝试选择其他分类或清除筛选"
        }
    }
}

// MARK: - Category Button
/// 分类按钮组件
struct CategoryButton: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))

                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : ApocalypseTheme.cardBackground)
            .cornerRadius(20)
        }
    }
}

// MARK: - Item Card View
/// 物品卡片组件
struct ItemCardView: View {
    let item: InventoryItem
    var itemDefinitions: [ItemDefinition] = []

    /// 获取物品定义（优先从传入的列表中查找，其次从 Mock 数据中查找）
    private var itemDefinition: ItemDefinition? {
        // 先从传入的列表中查找
        if let def = itemDefinitions.first(where: { $0.id == item.itemId }) {
            return def
        }
        // 兼容：从 Mock 数据中查找
        return item.definition
    }

    var body: some View {
        ELCard(padding: 14) {
            HStack(spacing: 14) {
                // 左侧圆形图标
                categoryIcon

                // 中间物品信息
                VStack(alignment: .leading, spacing: 6) {
                    // 物品名称
                    Text(itemDefinition?.name ?? "未知物品")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 数量和重量
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "number")
                                .font(.system(size: 11))
                            Text("x\(item.quantity)")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(ApocalypseTheme.textSecondary)

                        HStack(spacing: 4) {
                            Image(systemName: "scalemass.fill")
                                .font(.system(size: 11))
                            Text("\(calculatedTotalWeight, specifier: "%.1f")kg")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(ApocalypseTheme.textSecondary)

                        // 品质（如有）
                        if let quality = item.quality {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 11))
                                Text("\(Int(quality))%")
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(qualityColor(quality))
                        }
                    }

                    // 稀有度标签
                    if let rarity = itemDefinition?.rarity {
                        rarityBadge(rarity)
                    }
                }

                Spacer()

                // 右侧操作按钮
                VStack(spacing: 8) {
                    actionButton(title: "使用", icon: "hand.point.up.left.fill", color: ApocalypseTheme.info) {
                        print("使用物品: \(itemDefinition?.name ?? "未知")")
                    }

                    actionButton(title: "存储", icon: "archivebox.fill", color: ApocalypseTheme.warning) {
                        print("存储物品: \(itemDefinition?.name ?? "未知")")
                    }
                }
            }
        }
    }

    /// 计算总重量
    private var calculatedTotalWeight: Double {
        (itemDefinition?.weight ?? 0) * Double(item.quantity)
    }

    // MARK: - Category Icon
    /// 分类图标
    private var categoryIcon: some View {
        ZStack {
            Circle()
                .fill(categoryColor.opacity(0.2))
                .frame(width: 50, height: 50)

            Image(systemName: categoryIconName)
                .font(.system(size: 22))
                .foregroundColor(categoryColor)
        }
    }

    /// 分类颜色
    private var categoryColor: Color {
        guard let category = itemDefinition?.category else {
            return ApocalypseTheme.textMuted
        }

        switch category {
        case .food:
            return .green
        case .water:
            return .blue
        case .material:
            return .brown
        case .tool:
            return .orange
        case .medical:
            return .red
        }
    }

    /// 分类图标名称
    private var categoryIconName: String {
        guard let category = itemDefinition?.category else {
            return "questionmark"
        }

        switch category {
        case .food:
            return "fork.knife"
        case .water:
            return "drop.fill"
        case .material:
            return "hammer.fill"
        case .tool:
            return "wrench.and.screwdriver.fill"
        case .medical:
            return "cross.case.fill"
        }
    }

    // MARK: - Rarity Badge
    /// 稀有度徽章
    private func rarityBadge(_ rarity: ItemRarity) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "gem.fill")
                .font(.system(size: 10))

            Text(rarity.rawValue)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(rarityColor(rarity))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(rarityColor(rarity).opacity(0.2))
        .cornerRadius(6)
    }

    /// 稀有度颜色
    private func rarityColor(_ rarity: ItemRarity) -> Color {
        switch rarity {
        case .common:
            return .gray
        case .uncommon:
            return .green
        case .rare:
            return .blue
        case .epic:
            return .purple
        case .legendary:
            return .orange
        }
    }

    /// 品质颜色
    private func qualityColor(_ quality: Double) -> Color {
        if quality >= 90 {
            return .purple
        } else if quality >= 75 {
            return .blue
        } else if quality >= 60 {
            return .green
        } else {
            return .gray
        }
    }

    // MARK: - Action Button
    /// 操作按钮
    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color)
            .cornerRadius(6)
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        BackpackView()
    }
}
