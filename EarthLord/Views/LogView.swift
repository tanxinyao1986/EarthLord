//
//  LogView.swift
//  EarthLord
//
//  日志查看界面 - 显示App运行日志
//

import SwiftUI

struct LogView: View {
    // MARK: - 依赖注入

    /// 日志管理器（全局单例）
    @ObservedObject var logger = LogManager.shared

    // MARK: - 状态

    /// 当前选择的日志级别筛选（nil 表示显示全部）
    @State private var selectedLevel: LogLevel? = nil

    /// 是否显示清空确认对话框
    @State private var showClearAlert = false

    // MARK: - 计算属性

    /// 筛选后的日志
    private var filteredLogs: [LogEntry] {
        if let level = selectedLevel {
            return logger.logs.filter { $0.level == level }
        }
        return logger.logs
    }

    // MARK: - 视图

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 级别筛选器
                levelFilterPicker

                // 日志列表
                if filteredLogs.isEmpty {
                    emptyStateView
                } else {
                    logListView
                }
            }
            .navigationTitle("运行日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    clearButton
                }
            }
            .alert("清空日志", isPresented: $showClearAlert) {
                Button("取消", role: .cancel) {}
                Button("清空", role: .destructive) {
                    logger.clear()
                }
            } message: {
                Text("确定要清空所有日志吗？此操作无法撤销。")
            }
        }
    }

    // MARK: - 子视图

    /// 级别筛选器
    private var levelFilterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "全部" 按钮
                FilterChip(
                    title: "全部 (\(logger.logs.count))",
                    isSelected: selectedLevel == nil,
                    color: .gray
                ) {
                    selectedLevel = nil
                }

                // 各级别按钮
                ForEach(LogLevel.allCases, id: \.self) { level in
                    let count = logger.getLogs(ofLevel: level).count
                    FilterChip(
                        title: "\(level.rawValue) (\(count))",
                        isSelected: selectedLevel == level,
                        color: level.color
                    ) {
                        selectedLevel = level
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }

    /// 日志列表
    private var logListView: some View {
        List {
            ForEach(filteredLogs.reversed()) { log in
                LogRowView(log: log)
            }
        }
        .listStyle(.plain)
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("暂无日志")
                .font(.headline)
                .foregroundColor(.gray)
            if selectedLevel != nil {
                Text("当前筛选级别没有日志记录")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    /// 清空按钮
    private var clearButton: some View {
        Button {
            showClearAlert = true
        } label: {
            Image(systemName: "trash")
                .foregroundColor(logger.logs.isEmpty ? .gray : .red)
        }
        .disabled(logger.logs.isEmpty)
    }
}

// MARK: - 日志行视图

struct LogRowView: View {
    let log: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 图标
            Image(systemName: log.level.icon)
                .font(.system(size: 16))
                .foregroundColor(log.level.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                // 日志内容
                Text(log.message)
                    .font(.body)
                    .foregroundColor(.primary)

                // 时间戳
                Text(log.timeString)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 筛选标签

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : Color.clear)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color, lineWidth: 1)
                )
        }
    }
}

// MARK: - 预览

#Preview {
    // 添加测试数据
    let logger = LogManager.shared
    logger.info("开始圈地追踪")
    logger.success("闭环成功！距起点 25m")
    logger.warning("速度较快 18 km/h")
    logger.error("定位失败")

    return LogView()
}
