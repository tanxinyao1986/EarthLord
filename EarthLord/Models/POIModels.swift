//
//  POIModels.swift
//  EarthLord
//
//  Day22: POI搜刮系统数据模型
//

import Foundation
import CoreLocation
import MapKit

// MARK: - POI 分类

/// POI 分类枚举
enum POICategory: String, Codable, CaseIterable {
    case store = "商店"
    case hospital = "医院"
    case pharmacy = "药店"
    case gasStation = "加油站"
    case restaurant = "餐厅"
    case cafe = "咖啡店"
    case convenience = "便利店"
    case supermarket = "超市"

    /// 显示图标
    var icon: String {
        switch self {
        case .store: return "bag.fill"
        case .hospital: return "cross.case.fill"
        case .pharmacy: return "pills.fill"
        case .gasStation: return "fuelpump.fill"
        case .restaurant: return "fork.knife"
        case .cafe: return "cup.and.saucer.fill"
        case .convenience: return "storefront.fill"
        case .supermarket: return "cart.fill"
        }
    }

    /// 地图上的表情符号图标
    var emoji: String {
        switch self {
        case .store: return "🏪"
        case .hospital: return "🏥"
        case .pharmacy: return "💊"
        case .gasStation: return "⛽"
        case .restaurant: return "🍽️"
        case .cafe: return "☕"
        case .convenience: return "🏬"
        case .supermarket: return "🛒"
        }
    }

    /// 对应的 MapKit POI 类别
    var mapPointOfInterestCategory: MKPointOfInterestCategory {
        switch self {
        case .store: return .store
        case .hospital: return .hospital
        case .pharmacy: return .pharmacy
        case .gasStation: return .gasStation
        case .restaurant: return .restaurant
        case .cafe: return .cafe
        case .convenience: return .store
        case .supermarket: return .store
        }
    }

    /// 从 MapKit 类别转换
    static func from(mapCategory: MKPointOfInterestCategory?) -> POICategory {
        guard let category = mapCategory else { return .store }

        switch category {
        case .hospital: return .hospital
        case .pharmacy: return .pharmacy
        case .gasStation: return .gasStation
        case .restaurant: return .restaurant
        case .cafe: return .cafe
        case .store: return .store
        default: return .store
        }
    }

    /// 搜索关键词
    var searchKeywords: [String] {
        switch self {
        case .store: return ["商店", "店铺"]
        case .hospital: return ["医院", "诊所"]
        case .pharmacy: return ["药店", "药房"]
        case .gasStation: return ["加油站", "油站"]
        case .restaurant: return ["餐厅", "饭店"]
        case .cafe: return ["咖啡", "咖啡店"]
        case .convenience: return ["便利店", "711", "全家"]
        case .supermarket: return ["超市", "市场"]
        }
    }
}

// MARK: - POI 模型

/// 兴趣点模型
struct POI: Identifiable, Equatable {
    let id: String
    let name: String                      // 真实地点名称
    let coordinate: CLLocationCoordinate2D
    let category: POICategory
    var isScavenged: Bool = false         // 是否已搜刮
    let dangerLevel: Int                  // 危险等级 (1-5)

    // MARK: - 危险值生成

    /// 根据 POI 类别获取基础危险值
    static func baseDangerLevel(for category: POICategory) -> Int {
        switch category {
        case .pharmacy: return 1       // 药店：低危
        case .cafe: return 1           // 咖啡店：低危
        case .convenience: return 2    // 便利店：低危
        case .restaurant: return 2     // 餐厅：低危
        case .supermarket: return 3    // 超市：中危
        case .store: return 3          // 商店：中危
        case .gasStation: return 4     // 加油站：高危
        case .hospital: return 5       // 医院：极危
        }
    }

    /// 根据基础值随机浮动生成最终危险值
    static func generateDangerLevel(for category: POICategory) -> Int {
        let base = baseDangerLevel(for: category)
        let variation = Int.random(in: -1...1)
        return max(1, min(5, base + variation))
    }

    /// 创建唯一 ID
    static func generateId(from mapItem: MKMapItem) -> String {
        let coord = mapItem.location.coordinate
        return "\(mapItem.name ?? "unknown")_\(coord.latitude)_\(coord.longitude)"
    }

    /// 从 MKMapItem 创建（用于 MKLocalPointsOfInterestRequest）
    static func from(mapItem: MKMapItem) -> POI {
        let category = POICategory.from(mapCategory: mapItem.pointOfInterestCategory)
        return POI(
            id: generateId(from: mapItem),
            name: mapItem.name ?? "未知地点",
            coordinate: mapItem.location.coordinate,
            category: category,
            dangerLevel: generateDangerLevel(for: category)
        )
    }

    /// 从关键词搜索结果创建（用于 MKLocalSearch，兼容中国大陆）
    static func fromKeywordSearch(mapItem: MKMapItem) -> POI {
        let coordinate = mapItem.location.coordinate
        let id = "\(mapItem.name ?? "unknown")_\(coordinate.latitude)_\(coordinate.longitude)"
        let category = POICategory.from(mapCategory: mapItem.pointOfInterestCategory)
        return POI(
            id: id,
            name: mapItem.name ?? "未知地点",
            coordinate: coordinate,
            category: category,
            dangerLevel: generateDangerLevel(for: category)
        )
    }

    /// 计算到指定坐标的距离（米）
    func distance(to coordinate: CLLocationCoordinate2D) -> Double {
        let from = CLLocation(latitude: self.coordinate.latitude, longitude: self.coordinate.longitude)
        let to = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return from.distance(from: to)
    }

    // Equatable
    static func == (lhs: POI, rhs: POI) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - 搜刮结果

/// POI 搜刮结果
struct ScavengeResult {
    let poi: POI
    let items: [String: Int]  // itemId: quantity

    /// 转换为 ExplorationResult 用于显示
    func toExplorationResult() -> ExplorationResult {
        return ExplorationResult(
            distanceWalked: 0,
            duration: 0,
            itemsFound: items,
            experienceGained: items.values.reduce(0, +) * 10, // 每个物品10经验
            totalDistanceWalked: 0,
            distanceRanking: 0,
            timestamp: Date()
        )
    }
}

// MARK: - POI Annotation

/// 用于地图显示的 POI 标注
class POIAnnotation: NSObject, MKAnnotation {
    let poi: POI

    var coordinate: CLLocationCoordinate2D {
        return poi.coordinate
    }

    var title: String? {
        return poi.name
    }

    var subtitle: String? {
        return poi.category.rawValue
    }

    init(poi: POI) {
        self.poi = poi
        super.init()
    }
}
