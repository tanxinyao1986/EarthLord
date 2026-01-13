//
//  ExplorationModels.swift
//  EarthLord
//
//  探索功能相关的数据模型
//

import Foundation

// MARK: - 奖励等级枚举

/// 探索奖励等级
enum RewardTier: String, Codable, CaseIterable {
    case none = "none"           // 无奖励 (0-200m)
    case bronze = "bronze"       // 铜级 (200-500m)
    case silver = "silver"       // 银级 (500-1000m)
    case gold = "gold"           // 金级 (1000-2000m)
    case diamond = "diamond"     // 钻石级 (2000m+)

    /// 该等级获得的物品数量
    var itemCount: Int {
        switch self {
        case .none: return 0
        case .bronze: return 1
        case .silver: return 2
        case .gold: return 3
        case .diamond: return 5
        }
    }

    /// 中文显示名称
    var displayName: String {
        switch self {
        case .none: return "无奖励"
        case .bronze: return "铜级"
        case .silver: return "银级"
        case .gold: return "金级"
        case .diamond: return "钻石级"
        }
    }

    /// 图标 emoji
    var icon: String {
        switch self {
        case .none: return "❌"
        case .bronze: return "🥉"
        case .silver: return "🥈"
        case .gold: return "🥇"
        case .diamond: return "💎"
        }
    }

    /// 经验值倍率
    var experienceMultiplier: Double {
        switch self {
        case .none: return 0
        case .bronze: return 1.0
        case .silver: return 1.5
        case .gold: return 2.0
        case .diamond: return 3.0
        }
    }

    /// 各稀有度的概率分布
    var rarityProbabilities: [ItemRarity: Double] {
        switch self {
        case .none:
            return [:]
        case .bronze:
            return [.common: 0.90, .uncommon: 0.10, .rare: 0.0, .epic: 0.0]
        case .silver:
            return [.common: 0.70, .uncommon: 0.25, .rare: 0.05, .epic: 0.0]
        case .gold:
            return [.common: 0.50, .uncommon: 0.35, .rare: 0.15, .epic: 0.0]
        case .diamond:
            return [.common: 0.30, .uncommon: 0.40, .rare: 0.20, .epic: 0.10]
        }
    }

    /// 根据距离计算奖励等级
    static func fromDistance(_ distance: Double) -> RewardTier {
        switch distance {
        case ..<200:
            return .none
        case 200..<500:
            return .bronze
        case 500..<1000:
            return .silver
        case 1000..<2000:
            return .gold
        default:
            return .diamond
        }
    }
}

// MARK: - 探索会话状态枚举

/// 探索会话状态
enum ExplorationSessionStatus: String, Codable {
    case inProgress = "in_progress"   // 进行中
    case completed = "completed"       // 已完成
    case cancelled = "cancelled"       // 已取消
    case failed = "failed"             // 失败（如超速）
}

// MARK: - 探索会话模型（数据库）

/// 探索会话数据库模型
struct ExplorationSessionDB: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let startedAt: Date
    var endedAt: Date?
    var durationSeconds: Int?
    var distanceWalked: Double
    var rewardTier: String?
    var itemsFound: [String: Int]?
    var experienceGained: Int
    var status: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationSeconds = "duration_seconds"
        case distanceWalked = "distance_walked"
        case rewardTier = "reward_tier"
        case itemsFound = "items_found"
        case experienceGained = "experience_gained"
        case status
        case createdAt = "created_at"
    }
}

/// 探索会话插入模型
struct ExplorationSessionInsert: Codable {
    let userId: UUID
    let startedAt: Date
    let status: String
    let distanceWalked: Double

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case startedAt = "started_at"
        case status
        case distanceWalked = "distance_walked"
    }

    init(userId: UUID, startedAt: Date = Date(), status: ExplorationSessionStatus = .inProgress) {
        self.userId = userId
        self.startedAt = startedAt
        self.status = status.rawValue
        self.distanceWalked = 0
    }
}

/// 探索会话更新模型
struct ExplorationSessionUpdate: Codable {
    var endedAt: Date?
    var durationSeconds: Int?
    var distanceWalked: Double?
    var rewardTier: String?
    var itemsFound: [String: Int]?
    var experienceGained: Int?
    var status: String?

    enum CodingKeys: String, CodingKey {
        case endedAt = "ended_at"
        case durationSeconds = "duration_seconds"
        case distanceWalked = "distance_walked"
        case rewardTier = "reward_tier"
        case itemsFound = "items_found"
        case experienceGained = "experience_gained"
        case status
    }
}

// MARK: - 物品定义模型（数据库）

/// 物品定义数据库模型
struct ItemDefinitionDB: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let weight: Double
    let volume: Double
    let rarity: String
    let description: String?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, category, weight, volume, rarity, description
        case isActive = "is_active"
    }

    /// 转换为 UI 使用的 ItemDefinition
    func toItemDefinition() -> ItemDefinition {
        ItemDefinition(
            id: id,
            name: name,
            category: ItemCategory(rawValue: category) ?? .material,
            weight: weight,
            volume: volume,
            rarity: ItemRarity(rawValue: rarity) ?? .common,
            description: description ?? ""
        )
    }
}

// MARK: - 背包物品模型（数据库）

/// 背包物品数据库模型
struct InventoryItemDB: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let itemId: String
    var quantity: Int
    var quality: Double?
    let acquiredAt: Date
    let explorationSessionId: UUID?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case itemId = "item_id"
        case quantity
        case quality
        case acquiredAt = "acquired_at"
        case explorationSessionId = "exploration_session_id"
        case createdAt = "created_at"
    }

    /// 转换为 UI 使用的 InventoryItem
    func toInventoryItem() -> InventoryItem {
        InventoryItem(
            id: id.uuidString,
            itemId: itemId,
            quantity: quantity,
            quality: quality,
            acquiredAt: acquiredAt
        )
    }
}

/// 背包物品插入模型
struct InventoryItemInsert: Codable {
    let userId: UUID
    let itemId: String
    let quantity: Int
    let quality: Double?
    let explorationSessionId: UUID?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case itemId = "item_id"
        case quantity
        case quality
        case explorationSessionId = "exploration_session_id"
    }

    init(userId: UUID, itemId: String, quantity: Int, quality: Double? = nil, explorationSessionId: UUID? = nil) {
        self.userId = userId
        self.itemId = itemId
        self.quantity = quantity
        self.quality = quality
        self.explorationSessionId = explorationSessionId
    }
}

/// 背包物品更新模型
struct InventoryItemUpdate: Codable {
    let quantity: Int
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case quantity
        case updatedAt = "updated_at"
    }

    init(quantity: Int) {
        self.quantity = quantity
        self.updatedAt = Date().ISO8601Format()
    }
}

// MARK: - 生成的奖励结果

/// 奖励生成结果
struct GeneratedRewards {
    let tier: RewardTier
    let items: [String: Int]  // itemId: quantity
    let experience: Int

    /// 物品总数
    var totalItemCount: Int {
        items.values.reduce(0, +)
    }

    /// 是否有奖励
    var hasRewards: Bool {
        tier != .none && !items.isEmpty
    }
}

// MARK: - 探索错误

/// 探索相关错误
enum ExplorationError: LocalizedError {
    case notAuthenticated
    case noActiveSession
    case sessionAlreadyActive
    case databaseError(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .noActiveSession:
            return "没有进行中的探索"
        case .sessionAlreadyActive:
            return "已有探索正在进行"
        case .databaseError(let message):
            return "数据库错误: \(message)"
        case .networkError(let message):
            return "网络错误: \(message)"
        }
    }
}

/// 背包相关错误
enum InventoryError: LocalizedError {
    case notAuthenticated
    case itemNotFound
    case insufficientQuantity
    case databaseError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .itemNotFound:
            return "物品不存在"
        case .insufficientQuantity:
            return "物品数量不足"
        case .databaseError(let message):
            return "数据库错误: \(message)"
        }
    }
}
