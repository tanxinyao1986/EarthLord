//
//  POIListView.swift
//  EarthLord
//
//  Created by Claude Code
//

import SwiftUI

/// 附近兴趣点列表视图
struct POIListView: View {
    // MARK: - State
    @State private var isSearching = false
    @State private var selectedCategory: String? = nil  // nil表示"全部"
    @State private var poiList: [PointOfInterest] = MockExplorationData.pointsOfInterest
    @State private var isButtonPressed = false
    @State private var showItems = false

    // 假数据：GPS坐标
    private let mockLatitude = 22.54
    private let mockLongitude = 114.06

    // MARK: - Computed Properties

    /// 筛选后的POI列表
    private var filteredPOIs: [PointOfInterest] {
        if let category = selectedCategory {
            return poiList.filter { $0.type == category }
        }
        return poiList
    }

    /// 所有POI类型
    private var allCategories: [String] {
        let types = Set(poiList.map { $0.type })
        return Array(types).sorted()
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 状态栏
                statusBar

                // 搜索按钮
                searchButton
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // 筛选工具栏
                filterToolbar
                    .padding(.top, 16)

                // POI列表
                poiListView
                    .padding(.top, 16)
            }
        }
        .navigationTitle("附近POI")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Status Bar
    /// 状态栏区域
    private var statusBar: some View {
        ELCard(padding: 12) {
            VStack(spacing: 8) {
                // GPS坐标
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .foregroundColor(ApocalypseTheme.info)
                        .font(.system(size: 14))

                    Text("GPS: \(mockLatitude, specifier: "%.2f"), \(mockLongitude, specifier: "%.2f")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Spacer()
                }

                // 发现数量
                HStack(spacing: 8) {
                    Image(systemName: "map.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                        .font(.system(size: 14))

                    Text("附近发现 \(filteredPOIs.count) 个地点")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Search Button
    /// 搜索按钮
    private var searchButton: some View {
        Button(action: handleSearch) {
            HStack {
                if isSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                }

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))

                Text(isSearching ? "搜索中..." : "搜索附近POI")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isSearching ? ApocalypseTheme.textMuted : ApocalypseTheme.primary)
            .cornerRadius(12)
        }
        .disabled(isSearching)
        .scaleEffect(isButtonPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isButtonPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isSearching {
                        isButtonPressed = true
                    }
                }
                .onEnded { _ in
                    isButtonPressed = false
                }
        )
    }

    // MARK: - Filter Toolbar
    /// 筛选工具栏
    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "全部"按钮
                FilterButton(
                    title: "全部",
                    isSelected: selectedCategory == nil,
                    action: { selectedCategory = nil }
                )

                // 各类型按钮
                ForEach(allCategories, id: \.self) { category in
                    FilterButton(
                        title: category,
                        isSelected: selectedCategory == category,
                        action: { selectedCategory = category }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - POI List View
    /// POI列表
    private var poiListView: some View {
        Group {
            if filteredPOIs.isEmpty {
                // 空状态
                emptyStateView
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(filteredPOIs.enumerated()), id: \.element.id) { index, poi in
                            NavigationLink(destination: POIDetailView(poi: poi)) {
                                POICardView(poi: poi)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .opacity(showItems ? 1 : 0)
                            .offset(y: showItems ? 0 : 20)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.8)
                                    .delay(Double(index) * 0.1),
                                value: showItems
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
                .onAppear {
                    showItems = true
                }
                .onChange(of: selectedCategory) { _, _ in
                    // 切换分类时重新播放动画
                    withAnimation {
                        showItems = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showItems = true
                    }
                }
            }
        }
    }

    // MARK: - Empty State View
    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: poiList.isEmpty ? "map.fill" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            VStack(spacing: 8) {
                Text(poiList.isEmpty ? "附近暂无兴趣点" : "没有找到该类型的地点")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                if poiList.isEmpty {
                    Text("点击搜索按钮发现周围的废墟")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textMuted)
                        .multilineTextAlignment(.center)
                } else {
                    Text("尝试选择其他分类或搜索")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions
    /// 处理搜索按钮点击
    private func handleSearch() {
        isSearching = true

        // 模拟网络请求，1.5秒后恢复
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSearching = false
            // 这里可以添加刷新数据的逻辑
        }
    }
}

// MARK: - Filter Button
/// 筛选按钮组件
struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
                .cornerRadius(20)
        }
    }
}

// MARK: - POI Card View
/// POI卡片组件
struct POICardView: View {
    let poi: PointOfInterest

    var body: some View {
        ELCard(padding: 16) {
            HStack(spacing: 16) {
                // 类型图标
                ZStack {
                    Circle()
                        .fill(poiColor.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: poiIcon)
                        .font(.system(size: 22))
                        .foregroundColor(poiColor)
                }

                // POI信息
                VStack(alignment: .leading, spacing: 6) {
                    // 名称
                    Text(poi.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 类型
                    Text(poi.type)
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    // 状态标签
                    HStack(spacing: 8) {
                        // 发现状态
                        statusBadge

                        // 物资状态（仅已发现的显示）
                        if poi.status == .discovered, let resources = poi.estimatedResources, !resources.isEmpty {
                            resourceBadge(count: resources.values.reduce(0, +))
                        }
                    }
                }

                Spacer()

                // 右侧箭头
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
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

    // MARK: - Status Badges
    /// 发现状态徽章
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.system(size: 10))

            Text(poi.status.rawValue)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(statusColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.2))
        .cornerRadius(6)
    }

    /// 物资徽章
    private func resourceBadge(count: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "cube.box.fill")
                .font(.system(size: 10))

            Text("\(count)件物资")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(ApocalypseTheme.success)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(ApocalypseTheme.success.opacity(0.2))
        .cornerRadius(6)
    }

    /// 状态图标
    private var statusIcon: String {
        switch poi.status {
        case .undiscovered:
            return "questionmark.circle.fill"
        case .discovered:
            return "eye.fill"
        case .depleted:
            return "xmark.circle.fill"
        }
    }

    /// 状态颜色
    private var statusColor: Color {
        switch poi.status {
        case .undiscovered:
            return ApocalypseTheme.textMuted
        case .discovered:
            return ApocalypseTheme.info
        case .depleted:
            return ApocalypseTheme.danger
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        POIListView()
    }
}
