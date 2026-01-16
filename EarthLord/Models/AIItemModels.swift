//
//  AIItemModels.swift
//  EarthLord
//
//  AI 生成物品相关数据模型
//

import Foundation
import SwiftUI

// MARK: - AI 生成物品

/// AI 生成的物品（带独特名称和背景故事）
struct AIGeneratedItem: Codable {
    let uniqueName: String      // 独特名称
    let baseCategory: String    // 基础分类（水源/食物/医疗/材料/工具）
    let rarity: String          // 稀有度
    let backstory: String       // 背景故事
    let quantity: Int           // 数量

    enum CodingKeys: String, CodingKey {
        case uniqueName = "unique_name"
        case baseCategory = "base_category"
        case rarity
        case backstory
        case quantity
    }

    /// 转换为 ItemCategory
    var itemCategory: ItemCategory {
        switch baseCategory {
        case "水源": return .water
        case "食物": return .food
        case "医疗": return .medical
        case "材料": return .material
        case "工具": return .tool
        default: return .material
        }
    }

    /// 转换为 ItemRarity
    var itemRarity: ItemRarity {
        switch rarity {
        case "普通", "common": return .common
        case "罕见", "uncommon": return .uncommon
        case "稀有", "rare": return .rare
        case "史诗", "epic": return .epic
        case "传说", "legendary": return .legendary
        default: return .common
        }
    }
}

// MARK: - AI 生成请求

/// AI 物品生成请求
struct AIGenerateRequest: Codable {
    let poiName: String
    let poiCategory: String
    let dangerLevel: Int
    let itemCount: Int

    enum CodingKeys: String, CodingKey {
        case poiName = "poi_name"
        case poiCategory = "poi_category"
        case dangerLevel = "danger_level"
        case itemCount = "item_count"
    }
}

// MARK: - AI 生成响应

/// AI 物品生成响应
struct AIGenerateResponse: Codable {
    let items: [AIGeneratedItem]
    let error: String?
}

// MARK: - AI 搜刮结果

/// AI 搜刮结果（包含独特名称和故事）
struct AIScavengeResult {
    let poi: POI
    let aiItems: [AIGeneratedItem]      // AI 生成的物品（带独特名称和故事）
    let items: [String: Int]            // 系统物品映射（用于背包）

    /// 转换为显示用的探索结果
    func toExplorationResult() -> ExplorationResult {
        return ExplorationResult(
            distanceWalked: 0,
            duration: 0,
            itemsFound: items,
            experienceGained: items.values.reduce(0, +) * 10,
            totalDistanceWalked: 0,
            distanceRanking: 0,
            timestamp: Date()
        )
    }

    /// 获取所有物品的总数量
    var totalQuantity: Int {
        aiItems.reduce(0) { $0 + $1.quantity }
    }
}

// MARK: - ItemRarity 扩展

extension ItemRarity {
    /// 稀有度对应的颜色
    var color: Color {
        switch self {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }

    /// 稀有度显示名称
    var displayName: String {
        return self.rawValue
    }
}
