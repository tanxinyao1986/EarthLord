//
//  MockExplorationData.swift
//  EarthLord
//
//  Created by Claude Code
//

import Foundation
import CoreLocation

// MARK: - 物品稀有度枚举
/// 物品的稀有程度
enum ItemRarity: String, Codable {
    case common = "普通"      // 常见物品
    case uncommon = "罕见"    // 不太常见
    case rare = "稀有"        // 稀有物品
    case epic = "史诗"        // 非常稀有
}

// MARK: - 物品分类枚举
/// 物品的类型分类
enum ItemCategory: String, Codable {
    case water = "水源"       // 饮用水
    case food = "食物"        // 食品
    case medical = "医疗"     // 医疗用品
    case material = "材料"    // 建筑/制作材料
    case tool = "工具"        // 工具类物品
}

// MARK: - POI 状态枚举
/// 兴趣点的发现和搜刮状态
enum POIStatus: String, Codable {
    case undiscovered = "未发现"   // 尚未被发现
    case discovered = "已发现"     // 已发现，未完全搜刮
    case depleted = "已搜空"       // 已被搜刮一空
}

// MARK: - 物品定义
/// 物品的基础定义信息（游戏物品表）
struct ItemDefinition: Codable, Identifiable {
    let id: String              // 物品唯一标识符
    let name: String            // 物品中文名称
    let category: ItemCategory  // 物品分类
    let weight: Double          // 单个物品重量（千克）
    let volume: Double          // 单个物品体积（升）
    let rarity: ItemRarity      // 稀有度
    let description: String     // 物品描述
}

// MARK: - 背包物品
/// 玩家背包中的物品实例
struct InventoryItem: Codable, Identifiable {
    let id: String              // 物品实例ID
    let itemId: String          // 对应的物品定义ID
    var quantity: Int           // 数量
    var quality: Double?        // 品质（0-100，部分物品没有品质概念）
    let acquiredAt: Date        // 获得时间

    /// 获取物品定义
    var definition: ItemDefinition? {
        MockExplorationData.itemDefinitions.first { $0.id == itemId }
    }

    /// 计算总重量
    var totalWeight: Double {
        (definition?.weight ?? 0) * Double(quantity)
    }
}

// MARK: - 兴趣点（POI）
/// 地图上的兴趣点位置
struct PointOfInterest: Codable, Identifiable {
    let id: String                  // POI唯一标识符
    let name: String                // 地点名称
    let coordinate: CLLocationCoordinate2D  // 地理坐标
    let type: String                // 地点类型（超市、医院等）
    var status: POIStatus           // 发现和搜刮状态
    let estimatedResources: [String: Int]?  // 预估资源（仅已发现的显示）
    let dangerLevel: Int            // 危险等级（1-5）
    let description: String         // 地点描述

    enum CodingKeys: String, CodingKey {
        case id, name, type, status, estimatedResources, dangerLevel, description
        case latitude, longitude
    }

    init(id: String, name: String, latitude: Double, longitude: Double, type: String, status: POIStatus, estimatedResources: [String: Int]?, dangerLevel: Int, description: String) {
        self.id = id
        self.name = name
        self.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        self.type = type
        self.status = status
        self.estimatedResources = estimatedResources
        self.dangerLevel = dangerLevel
        self.description = description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        type = try container.decode(String.self, forKey: .type)
        status = try container.decode(POIStatus.self, forKey: .status)
        estimatedResources = try container.decodeIfPresent([String: Int].self, forKey: .estimatedResources)
        dangerLevel = try container.decode(Int.self, forKey: .dangerLevel)
        description = try container.decode(String.self, forKey: .description)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(type, forKey: .type)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(estimatedResources, forKey: .estimatedResources)
        try container.encode(dangerLevel, forKey: .dangerLevel)
        try container.encode(description, forKey: .description)
    }
}

// MARK: - 探索结果
/// 单次探索行动的统计结果
struct ExplorationResult: Codable {
    // 本次探索数据
    let distanceWalked: Double          // 本次行走距离（米）
    let areaExplored: Double            // 本次探索面积（平方米）
    let duration: TimeInterval          // 探索时长（秒）
    let itemsFound: [String: Int]       // 获得的物品（物品ID: 数量）
    let experienceGained: Int           // 获得经验值

    // 累计数据
    let totalDistanceWalked: Double     // 累计行走距离（米）
    let totalAreaExplored: Double       // 累计探索面积（平方米）

    // 排名数据
    let distanceRanking: Int            // 行走距离排名
    let areaRanking: Int                // 探索面积排名

    let timestamp: Date                 // 探索完成时间
}

// MARK: - 模拟数据
/// 探索模块的测试假数据
struct MockExplorationData {

    // MARK: - 物品定义表
    /// 游戏中所有可获得物品的定义
    static let itemDefinitions: [ItemDefinition] = [
        // 水源类
        ItemDefinition(
            id: "water_mineral",
            name: "矿泉水",
            category: .water,
            weight: 0.5,
            volume: 0.5,
            rarity: .common,
            description: "瓶装纯净水，末日前的产品，仍可安全饮用"
        ),

        // 食物类
        ItemDefinition(
            id: "food_canned",
            name: "罐头食品",
            category: .food,
            weight: 0.4,
            volume: 0.3,
            rarity: .common,
            description: "密封罐头，保质期长，是珍贵的食物来源"
        ),

        // 医疗类
        ItemDefinition(
            id: "medical_bandage",
            name: "绷带",
            category: .medical,
            weight: 0.05,
            volume: 0.1,
            rarity: .common,
            description: "医用绷带，可以包扎伤口"
        ),
        ItemDefinition(
            id: "medical_medicine",
            name: "药品",
            category: .medical,
            weight: 0.1,
            volume: 0.05,
            rarity: .uncommon,
            description: "各类常用药品，在末日中价值极高"
        ),

        // 材料类
        ItemDefinition(
            id: "material_wood",
            name: "木材",
            category: .material,
            weight: 2.0,
            volume: 5.0,
            rarity: .common,
            description: "可用于建造和修复的木材"
        ),
        ItemDefinition(
            id: "material_metal",
            name: "废金属",
            category: .material,
            weight: 3.0,
            volume: 2.0,
            rarity: .uncommon,
            description: "废弃的金属零件，可以回收利用"
        ),

        // 工具类
        ItemDefinition(
            id: "tool_flashlight",
            name: "手电筒",
            category: .tool,
            weight: 0.3,
            volume: 0.2,
            rarity: .uncommon,
            description: "LED手电筒，夜间探索的必需品"
        ),
        ItemDefinition(
            id: "tool_rope",
            name: "绳子",
            category: .tool,
            weight: 1.0,
            volume: 1.5,
            rarity: .common,
            description: "尼龙绳，多种用途"
        )
    ]

    // MARK: - POI 列表
    /// 地图上的兴趣点（5个不同状态）
    static let pointsOfInterest: [PointOfInterest] = [
        // 1. 废弃超市 - 已发现，有物资
        PointOfInterest(
            id: "poi_supermarket_01",
            name: "废弃超市",
            latitude: 31.2304,
            longitude: 121.4737,
            type: "超市",
            status: .discovered,
            estimatedResources: [
                "water_mineral": 8,
                "food_canned": 12,
                "material_wood": 5
            ],
            dangerLevel: 2,
            description: "一家中型超市，货架大多已空，但角落可能还有物资"
        ),

        // 2. 医院废墟 - 已发现，已搜空
        PointOfInterest(
            id: "poi_hospital_01",
            name: "医院废墟",
            latitude: 31.2305,
            longitude: 121.4740,
            type: "医院",
            status: .depleted,
            estimatedResources: nil,
            dangerLevel: 3,
            description: "曾经的救护中心，现已被搜刮一空"
        ),

        // 3. 加油站 - 未发现
        PointOfInterest(
            id: "poi_gasstation_01",
            name: "加油站",
            latitude: 31.2308,
            longitude: 121.4735,
            type: "加油站",
            status: .undiscovered,
            estimatedResources: nil,
            dangerLevel: 2,
            description: "路边加油站，可能有燃料和便利店物资"
        ),

        // 4. 药店废墟 - 已发现，有物资
        PointOfInterest(
            id: "poi_pharmacy_01",
            name: "药店废墟",
            latitude: 31.2302,
            longitude: 121.4742,
            type: "药店",
            status: .discovered,
            estimatedResources: [
                "medical_bandage": 15,
                "medical_medicine": 6
            ],
            dangerLevel: 1,
            description: "小型药店，可能还有一些医疗用品"
        ),

        // 5. 工厂废墟 - 未发现
        PointOfInterest(
            id: "poi_factory_01",
            name: "工厂废墟",
            latitude: 31.2310,
            longitude: 121.4730,
            type: "工厂",
            status: .undiscovered,
            estimatedResources: nil,
            dangerLevel: 4,
            description: "废弃的机械厂，可能有金属材料和工具"
        )
    ]

    // MARK: - 背包物品
    /// 玩家当前背包中的物品（6-8种不同类型）
    static let inventoryItems: [InventoryItem] = [
        // 水类
        InventoryItem(
            id: "inv_001",
            itemId: "water_mineral",
            quantity: 6,
            quality: nil,  // 水没有品质概念
            acquiredAt: Date().addingTimeInterval(-86400)  // 1天前获得
        ),

        // 食物
        InventoryItem(
            id: "inv_002",
            itemId: "food_canned",
            quantity: 8,
            quality: 85.0,  // 品质良好
            acquiredAt: Date().addingTimeInterval(-172800)  // 2天前获得
        ),

        // 医疗 - 绷带
        InventoryItem(
            id: "inv_003",
            itemId: "medical_bandage",
            quantity: 12,
            quality: nil,  // 绷带没有品质概念
            acquiredAt: Date().addingTimeInterval(-259200)  // 3天前获得
        ),

        // 医疗 - 药品
        InventoryItem(
            id: "inv_004",
            itemId: "medical_medicine",
            quantity: 4,
            quality: 92.0,  // 品质优秀
            acquiredAt: Date().addingTimeInterval(-432000)  // 5天前获得
        ),

        // 材料 - 木材
        InventoryItem(
            id: "inv_005",
            itemId: "material_wood",
            quantity: 15,
            quality: 70.0,  // 品质一般
            acquiredAt: Date().addingTimeInterval(-7200)  // 2小时前获得
        ),

        // 材料 - 废金属
        InventoryItem(
            id: "inv_006",
            itemId: "material_metal",
            quantity: 8,
            quality: 65.0,  // 品质一般
            acquiredAt: Date().addingTimeInterval(-3600)  // 1小时前获得
        ),

        // 工具 - 手电筒
        InventoryItem(
            id: "inv_007",
            itemId: "tool_flashlight",
            quantity: 2,
            quality: 88.0,  // 品质良好
            acquiredAt: Date().addingTimeInterval(-604800)  // 7天前获得
        ),

        // 工具 - 绳子
        InventoryItem(
            id: "inv_008",
            itemId: "tool_rope",
            quantity: 3,
            quality: 75.0,  // 品质中等
            acquiredAt: Date().addingTimeInterval(-10800)  // 3小时前获得
        )
    ]

    // MARK: - 探索结果示例
    /// 一次探索行动的结果示例
    static let sampleExplorationResult = ExplorationResult(
        // 本次探索
        distanceWalked: 2500,           // 本次行走2500米
        areaExplored: 50000,            // 本次探索5万平方米
        duration: 1800,                 // 探索时长30分钟（1800秒）
        itemsFound: [
            "material_wood": 5,         // 获得木材 x5
            "water_mineral": 3,         // 获得矿泉水 x3
            "food_canned": 2            // 获得罐头 x2
        ],
        experienceGained: 150,          // 获得150经验值

        // 累计数据
        totalDistanceWalked: 15000,     // 累计行走15000米
        totalAreaExplored: 250000,      // 累计探索25万平方米

        // 排名
        distanceRanking: 42,            // 行走距离排名第42
        areaRanking: 38,                // 探索面积排名第38

        timestamp: Date()               // 当前时间
    )

    // MARK: - 辅助方法

    /// 根据ID获取物品定义
    static func getItemDefinition(id: String) -> ItemDefinition? {
        itemDefinitions.first { $0.id == id }
    }

    /// 根据ID获取POI
    static func getPOI(id: String) -> PointOfInterest? {
        pointsOfInterest.first { $0.id == id }
    }

    /// 计算背包总重量
    static func calculateTotalInventoryWeight() -> Double {
        inventoryItems.reduce(0) { $0 + $1.totalWeight }
    }

    /// 按分类获取背包物品
    static func getInventoryItems(byCategory category: ItemCategory) -> [InventoryItem] {
        inventoryItems.filter { item in
            item.definition?.category == category
        }
    }

    /// 获取已发现的POI列表
    static var discoveredPOIs: [PointOfInterest] {
        pointsOfInterest.filter { $0.status != .undiscovered }
    }

    /// 获取未发现的POI数量
    static var undiscoveredPOICount: Int {
        pointsOfInterest.filter { $0.status == .undiscovered }.count
    }
}
