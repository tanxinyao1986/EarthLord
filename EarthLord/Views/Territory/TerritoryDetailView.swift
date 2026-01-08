//
//  TerritoryDetailView.swift
//  EarthLord
//
//  领地详情页 - 显示领地详细信息和操作
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {
    // MARK: - Properties

    let territory: Territory
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    private let territoryManager = TerritoryManager.shared

    @State private var showDeleteAlert = false
    @State private var isDeleting = false

    // MARK: - 视图主体

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 地图预览
                    mapPreview

                    // 基本信息
                    basicInfoSection

                    // 统计信息
                    statisticsSection

                    // 占位功能区
                    futureFeatures

                    // 删除按钮
                    deleteButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationTitle(territory.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    Task {
                        await deleteTerritory()
                    }
                }
            } message: {
                Text("确定要删除这个领地吗？此操作无法撤销。")
            }
        }
    }

    // MARK: - 子视图

    /// 地图预览
    private var mapPreview: some View {
        Group {
            let coordinates = territory.toCoordinates()
            if !coordinates.isEmpty {
                Map {
                    // 将 WGS-84 转换为 GCJ-02 并绘制多边形
                    let gcj02Coords = coordinates.map { coord in
                        CoordinateConverter.wgs84ToGcj02(coord)
                    }
                    MapPolygon(coordinates: gcj02Coords)
                        .foregroundStyle(Color.green.opacity(0.3))
                        .stroke(Color.green, lineWidth: 2)
                }
                .frame(height: 250)
                .cornerRadius(12)
                .mapStyle(.hybrid)
            }
        }
    }

    /// 基本信息
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "基本信息")

            VStack(spacing: 12) {
                InfoRow(
                    icon: "map.fill",
                    label: "面积",
                    value: territory.formattedArea,
                    color: ApocalypseTheme.success
                )

                if let pointCount = territory.pointCount {
                    InfoRow(
                        icon: "location.fill",
                        label: "坐标点数",
                        value: "\(pointCount) 个",
                        color: ApocalypseTheme.primary
                    )
                }

                if let createdAt = territory.createdAt {
                    InfoRow(
                        icon: "clock.fill",
                        label: "创建时间",
                        value: formatDate(createdAt),
                        color: ApocalypseTheme.warning
                    )
                }
            }
            .padding(16)
            .background(
                ApocalypseTheme.cardBackground
                    .cornerRadius(12)
            )
        }
    }

    /// 统计信息
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "统计信息")

            HStack(spacing: 12) {
                StatBox(
                    icon: "chart.bar.fill",
                    label: "状态",
                    value: territory.isActive == true ? "活跃" : "未知",
                    color: territory.isActive == true ? ApocalypseTheme.success : ApocalypseTheme.textMuted
                )

                StatBox(
                    icon: "doc.text.fill",
                    label: "领地 ID",
                    value: String(territory.id.prefix(8)),
                    color: ApocalypseTheme.primary
                )
            }
        }
    }

    /// 未来功能占位
    private var futureFeatures: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "更多功能")

            VStack(spacing: 12) {
                FutureFeatureRow(
                    icon: "pencil.circle.fill",
                    title: "重命名领地",
                    description: "自定义领地名称"
                )

                FutureFeatureRow(
                    icon: "building.2.fill",
                    title: "建筑系统",
                    description: "在领地上建造设施"
                )

                FutureFeatureRow(
                    icon: "arrow.left.arrow.right.circle.fill",
                    title: "领地交易",
                    description: "与其他玩家交易领地"
                )
            }
            .padding(16)
            .background(
                ApocalypseTheme.cardBackground
                    .cornerRadius(12)
            )
        }
    }

    /// 删除按钮
    private var deleteButton: some View {
        Button {
            showDeleteAlert = true
        } label: {
            HStack {
                if isDeleting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16))
                }

                Text(isDeleting ? "删除中..." : "删除领地")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.red)
            .cornerRadius(12)
        }
        .disabled(isDeleting)
    }

    // MARK: - 辅助方法

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

    /// 删除领地
    private func deleteTerritory() async {
        isDeleting = true

        let success = await territoryManager.deleteTerritory(territoryId: territory.id)

        isDeleting = false

        if success {
            dismiss()
            onDelete?()
        }
    }
}

// MARK: - 支持视图

/// 章节标题
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(ApocalypseTheme.textPrimary)
    }
}

/// 信息行
struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 24)

            Text(label)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }
}

/// 统计框
struct StatBox: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            ApocalypseTheme.cardBackground
                .cornerRadius(10)
        )
    }
}

/// 未来功能行
struct FutureFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            Spacer()

            Text("敬请期待")
                .font(.system(size: 11))
                .foregroundColor(ApocalypseTheme.warning)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    ApocalypseTheme.warning.opacity(0.1)
                        .cornerRadius(6)
                )
        }
    }
}

// MARK: - 预览

#Preview {
    TerritoryDetailView(
        territory: Territory(
            id: "123",
            userId: "456",
            name: "测试领地",
            path: [
                ["lat": 31.2304, "lon": 121.4737],
                ["lat": 31.2305, "lon": 121.4738],
                ["lat": 31.2306, "lon": 121.4739]
            ],
            area: 1500,
            pointCount: 3,
            isActive: true,
            completedAt: nil,
            startedAt: nil,
            createdAt: "2025-01-08T00:00:00Z"
        )
    )
}
