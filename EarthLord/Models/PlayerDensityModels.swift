//
//  PlayerDensityModels.swift
//  EarthLord
//
//  Created by Claude on 2026-01-14.
//  附近玩家密度检测相关数据模型
//

import Foundation
import CoreLocation

// MARK: - 密度等级枚举

/// 玩家密度等级
enum DensityLevel: Int, Codable {
    case solo = 0       // 独行者：0人
    case low = 1        // 低密度：1-5人
    case medium = 2     // 中密度：6-20人
    case high = 3       // 高密度：20+人

    /// 根据密度等级返回建议显示的POI数量
    var poiCount: Int {
        switch self {
        case .solo:
            return 1    // 独行者：显示1个最近POI（保底）
        case .low:
            return 3    // 低密度：显示2-3个，取上限3
        case .medium:
            return 6    // 中密度：显示4-6个，取上限6
        case .high:
            return 20   // 高密度：显示所有POI（最多20个，iOS地理围栏限制）
        }
    }

    /// 密度等级的中文描述
    var description: String {
        switch self {
        case .solo:
            return "独行者"
        case .low:
            return "低密度"
        case .medium:
            return "中密度"
        case .high:
            return "高密度"
        }
    }

    /// 密度等级的详细说明
    var detailedDescription: String {
        switch self {
        case .solo:
            return "附近1公里内没有其他玩家"
        case .low:
            return "附近1公里内有1-5名玩家"
        case .medium:
            return "附近1公里内有6-20名玩家"
        case .high:
            return "附近1公里内有20+名玩家"
        }
    }

    /// 从玩家数量映射到密度等级
    /// - Parameter playerCount: 附近玩家数量
    /// - Returns: 对应的密度等级
    static func from(playerCount: Int) -> DensityLevel {
        switch playerCount {
        case 0:
            return .solo
        case 1...5:
            return .low
        case 6...20:
            return .medium
        default:
            return .high
        }
    }
}

// MARK: - 用户位置数据库模型

/// 用户位置数据库记录（对应 user_locations 表）
struct UserLocationDB: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let latitude: Double
    let longitude: Double
    let accuracy: Double?
    let reportedAt: Date
    let isOnline: Bool
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case latitude
        case longitude
        case accuracy
        case reportedAt = "reported_at"
        case isOnline = "is_online"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// 转换为CLLocationCoordinate2D
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// 转换为CLLocation
    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    /// 判断是否在线（5分钟内有上报）
    var isActiveOnline: Bool {
        guard isOnline else { return false }
        let fiveMinutesAgo = Date().addingTimeInterval(-5 * 60)
        return reportedAt > fiveMinutesAgo
    }
}

// MARK: - 附近玩家查询结果

/// 附近玩家查询结果
struct NearbyPlayersResult {
    /// 附近玩家数量
    let count: Int

    /// 密度等级
    let densityLevel: DensityLevel

    /// 建议显示的POI数量
    let suggestedPOICount: Int

    /// 查询半径（米）
    let radiusMeters: Double

    /// 查询时间
    let timestamp: Date

    /// 从玩家数量初始化
    init(count: Int, radiusMeters: Double = 1000) {
        self.count = count
        self.densityLevel = DensityLevel.from(playerCount: count)
        self.suggestedPOICount = densityLevel.poiCount
        self.radiusMeters = radiusMeters
        self.timestamp = Date()
    }
}
