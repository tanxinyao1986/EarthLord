//
//  LogManager.swift
//  EarthLord
//
//  全局日志记录工具 - 记录App运行过程中的所有事件
//

import Foundation
import SwiftUI
import Combine

// MARK: - 日志级别枚举

/// 日志级别（用于区分不同类型的日志）
enum LogLevel: String, CaseIterable {
    case info = "INFO"       // 普通信息（蓝色）
    case success = "SUCCESS" // 成功事件（绿色）
    case warning = "WARNING" // 警告信息（橙色）
    case error = "ERROR"     // 错误信息（红色）

    /// 对应的颜色（用于UI显示）
    var color: Color {
        switch self {
        case .info:
            return .blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    /// 对应的图标（用于UI显示）
    var icon: String {
        switch self {
        case .info:
            return "info.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        }
    }
}

// MARK: - 日志条目

/// 单条日志记录
struct LogEntry: Identifiable {
    let id = UUID()          // 唯一标识符（用于 SwiftUI List）
    let timestamp: Date      // 时间戳
    let level: LogLevel      // 日志级别
    let message: String      // 日志内容

    /// 格式化的时间字符串（HH:mm:ss）
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }

    /// 格式化的完整日志（用于控制台输出）
    /// 格式：[12:30:01] [INFO] 开始圈地追踪
    var formattedLog: String {
        "[\(timeString)] [\(level.rawValue)] \(message)"
    }
}

// MARK: - 日志管理器（全局单例）

/// 全局日志管理器 - 整个App共享唯一实例
class LogManager: ObservableObject {
    // MARK: - 单例模式

    /// ⭐ 全局唯一实例（整个App只用这一个）
    static let shared = LogManager()

    // MARK: - Published 属性

    /// 日志数组（自动通知 SwiftUI 界面更新）
    @Published var logs: [LogEntry] = []

    // MARK: - 配置

    /// 最大日志数量（防止内存溢出）
    private let maxLogs = 1000

    /// 是否同时输出到控制台
    var printToConsole = true

    // MARK: - 初始化

    /// 私有初始化（防止外部创建实例，确保单例）
    private init() {
        log("📱 LogManager 初始化完成", level: .info)
    }

    // MARK: - 核心方法

    /// 记录日志（核心方法）
    /// - Parameters:
    ///   - message: 日志内容
    ///   - level: 日志级别（默认为 .info）
    func log(_ message: String, level: LogLevel = .info) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            message: message
        )

        // ⚠️ 在主线程更新（确保 SwiftUI 能正常刷新）
        DispatchQueue.main.async {
            self.logs.append(entry)

            // 限制日志数量（超过上限时删除最旧的日志）
            if self.logs.count > self.maxLogs {
                self.logs.removeFirst()
            }
        }

        // 同时输出到 Xcode 控制台
        if printToConsole {
            print(entry.formattedLog)
        }
    }

    // MARK: - 便捷方法（语义化调用）

    /// 记录普通信息（蓝色）
    func info(_ message: String) {
        log(message, level: .info)
    }

    /// 记录成功事件（绿色）
    func success(_ message: String) {
        log(message, level: .success)
    }

    /// 记录警告信息（橙色）
    func warning(_ message: String) {
        log(message, level: .warning)
    }

    /// 记录错误信息（红色）
    func error(_ message: String) {
        log(message, level: .error)
    }

    // MARK: - 管理方法

    /// 清空所有日志
    func clear() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }

        if printToConsole {
            print("🗑️ 日志已清空")
        }
    }

    /// 获取指定级别的日志
    func getLogs(ofLevel level: LogLevel) -> [LogEntry] {
        logs.filter { $0.level == level }
    }

    /// 导出日志为文本（用于分享或保存）
    func exportLogs() -> String {
        logs.map { $0.formattedLog }.joined(separator: "\n")
    }
}

// MARK: - 使用示例（可删除）

/*
 【使用方式】

 // 1️⃣ 基本用法
 LogManager.shared.log("开始圈地追踪")
 LogManager.shared.log("速度过快", level: .warning)

 // 2️⃣ 便捷方法（推荐）
 LogManager.shared.info("开始圈地追踪")
 LogManager.shared.success("闭环成功！距起点 25m")
 LogManager.shared.warning("速度较快 18 km/h")
 LogManager.shared.error("定位失败")

 // 3️⃣ 在 SwiftUI 中使用
 struct LogView: View {
     @ObservedObject var logger = LogManager.shared

     var body: some View {
         List(logger.logs) { log in
             HStack {
                 Image(systemName: log.level.icon)
                     .foregroundColor(log.level.color)
                 Text(log.timeString)
                     .font(.caption)
                     .foregroundColor(.gray)
                 Text(log.message)
             }
         }
     }
 }

 // 4️⃣ 清空日志
 LogManager.shared.clear()

 // 5️⃣ 导出日志
 let logText = LogManager.shared.exportLogs()
 */
