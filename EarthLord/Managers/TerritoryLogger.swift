//
//  TerritoryLogger.swift
//  EarthLord
//
//  圈地验证日志管理器 - 专门用于记录圈地验证过程
//

import Foundation
import SwiftUI

// MARK: - 日志类型枚举

/// 日志类型（用于区分不同类型的日志）
enum TerritoryLogType: String {
    case info = "INFO"       // 普通信息（蓝色）
    case success = "SUCCESS" // 成功事件（绿色）
    case warning = "WARNING" // 警告信息（橙色）
    case error = "ERROR"     // 错误信息（红色）
}

// MARK: - 圈地日志管理器（全局单例）

/// 圈地验证日志管理器 - 整个App共享唯一实例
class TerritoryLogger {
    // MARK: - 单例模式

    /// ⭐ 全局唯一实例（整个App只用这一个）
    static let shared = TerritoryLogger()

    // MARK: - 初始化

    /// 私有初始化（防止外部创建实例，确保单例）
    private init() {}

    // MARK: - 核心方法

    /// 记录圈地验证日志
    /// - Parameters:
    ///   - message: 日志内容
    ///   - type: 日志类型
    func log(_ message: String, type: TerritoryLogType) {
        // 格式化日志
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let formattedLog = "[\(timestamp)] [\(type.rawValue)] \(message)"

        // 输出到控制台
        print(formattedLog)

        // 同时记录到全局日志管理器
        switch type {
        case .info:
            LogManager.shared.info(message)
        case .success:
            LogManager.shared.success(message)
        case .warning:
            LogManager.shared.warning(message)
        case .error:
            LogManager.shared.error(message)
        }
    }
}
