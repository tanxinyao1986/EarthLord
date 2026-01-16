//
//  POISearchManager.swift
//  EarthLord
//
//  Day22: POI搜索管理器 - 使用 MapKit 搜索附近真实地点
//

import Foundation
import MapKit
import CoreLocation

/// POI 搜索错误
enum POISearchError: Error, LocalizedError {
    case locationNotAvailable
    case searchFailed(String)
    case noResults

    var errorDescription: String? {
        switch self {
        case .locationNotAvailable:
            return "无法获取当前位置"
        case .searchFailed(let message):
            return "搜索失败: \(message)"
        case .noResults:
            return "附近没有找到可探索的地点"
        }
    }
}

/// POI 搜索管理器
class POISearchManager {
    // MARK: - 单例
    static let shared = POISearchManager()

    private init() {}

    // MARK: - 配置常量

    /// 搜索半径（米）
    private let searchRadius: Double = 1000

    /// 最大返回 POI 数量（iOS 地理围栏限制为 20 个）
    private let maxPOICount: Int = 20

    /// 需要搜索的 POI 类型
    private let searchCategories: [MKPointOfInterestCategory] = [
        .store,
        .hospital,
        .pharmacy,
        .gasStation,
        .restaurant,
        .cafe
    ]

    // MARK: - 公开方法

    /// 搜索附近 POI
    /// - Parameters:
    ///   - center: 搜索中心点坐标
    ///   - radius: 搜索半径（米），默认 1000 米
    ///   - limit: POI数量限制（默认20个，用于动态调整）
    /// - Returns: POI 数组
    func searchNearbyPOIs(center: CLLocationCoordinate2D, radius: Double? = nil, limit: Int? = nil) async throws -> [POI] {
        let effectiveRadius = radius ?? searchRadius
        let effectiveLimit = limit ?? maxPOICount

        LogManager.shared.info("[POISearchManager] 开始搜索附近 POI")
        LogManager.shared.info("[POISearchManager] 中心点: (\(String(format: "%.6f", center.latitude)), \(String(format: "%.6f", center.longitude)))")
        LogManager.shared.info("[POISearchManager] 搜索半径: \(Int(effectiveRadius))米")
        LogManager.shared.info("[POISearchManager] POI数量限制: \(effectiveLimit)个")

        var allPOIs: [POI] = []

        // 并行搜索多种类型
        await withTaskGroup(of: [POI].self) { group in
            for category in searchCategories {
                group.addTask {
                    do {
                        let pois = try await self.searchPOIs(center: center, radius: effectiveRadius, category: category)
                        return pois
                    } catch {
                        // 某些类型可能没有结果，这不是错误
                        return []
                    }
                }
            }

            for await pois in group {
                allPOIs.append(contentsOf: pois)
            }
        }

        // 去重（基于 ID）
        var uniquePOIs: [String: POI] = [:]
        for poi in allPOIs {
            if uniquePOIs[poi.id] == nil {
                uniquePOIs[poi.id] = poi
            }
        }

        // 按距离排序并限制数量
        var sortedPOIs = Array(uniquePOIs.values).sorted { poi1, poi2 in
            poi1.distance(to: center) < poi2.distance(to: center)
        }

        // Day23: 限制POI数量（动态调整）
        if sortedPOIs.count > effectiveLimit {
            sortedPOIs = Array(sortedPOIs.prefix(effectiveLimit))
        }

        // Day23: 保底策略 - 如果1公里内没有POI，扩展到2公里搜索
        if sortedPOIs.isEmpty && effectiveRadius <= 1000 {
            LogManager.shared.warning("[POISearchManager] 1公里内无POI，扩展到2公里搜索")
            return try await searchNearbyPOIs(center: center, radius: 2000, limit: effectiveLimit)
        }

        LogManager.shared.success("[POISearchManager] 搜索完成，找到 \(sortedPOIs.count) 个 POI（限制: \(effectiveLimit)个）")

        // 打印找到的 POI
        for (index, poi) in sortedPOIs.enumerated() {
            let distance = poi.distance(to: center)
            LogManager.shared.info("[POISearchManager] \(index + 1). \(poi.category.emoji) \(poi.name) - \(Int(distance))m")
        }

        return sortedPOIs
    }

    // MARK: - 私有方法

    /// 搜索特定类型的 POI（使用关键词搜索，兼容中国大陆）
    private func searchPOIs(center: CLLocationCoordinate2D, radius: Double, category: MKPointOfInterestCategory) async throws -> [POI] {
        // 获取搜索关键词
        let keyword = getSearchKeyword(for: category)
        print("🔍 [POI搜索] 开始搜索: \(keyword)")

        // 创建搜索区域
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )

        // 创建关键词搜索请求（兼容中国大陆）
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = keyword
        request.region = region

        // 执行搜索
        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            let mapItems = response.mapItems
            print("🔍 [POI搜索] \(keyword) 返回 \(mapItems.count) 个结果")

            // 打印每个 MapItem 的详细信息
            for item in mapItems.prefix(3) {  // 只打印前3个
                let coord = item.location.coordinate
                print("🔍 [POI搜索]   - \(item.name ?? "无名") @ (\(coord.latitude), \(coord.longitude))")
            }

            // 转换为 POI，并设置正确的类型
            let pois = mapItems.map { mapItem -> POI in
                let poiCategory = POICategory.from(mapCategory: category)
                return POI(
                    id: POI.generateId(from: mapItem),
                    name: mapItem.name ?? "未知地点",
                    coordinate: mapItem.location.coordinate,
                    category: poiCategory,
                    dangerLevel: POI.generateDangerLevel(for: poiCategory)
                )
            }
            print("🔍 [POI搜索] \(keyword) 转换为 \(pois.count) 个 POI")
            return pois
        } catch {
            print("🔍 [POI搜索] \(keyword) 搜索失败: \(error.localizedDescription)")
            return []
        }
    }

    /// 获取搜索关键词
    private func getSearchKeyword(for category: MKPointOfInterestCategory) -> String {
        switch category {
        case .store: return "超市 便利店"
        case .hospital: return "医院"
        case .pharmacy: return "药店 药房"
        case .gasStation: return "加油站"
        case .restaurant: return "餐厅 饭店"
        case .cafe: return "咖啡店"
        default: return "商店"
        }
    }

    /// 使用关键词搜索 POI（备用方法）
    func searchPOIsByKeyword(center: CLLocationCoordinate2D, keyword: String, radius: Double? = nil) async throws -> [POI] {
        let effectiveRadius = radius ?? searchRadius

        // 创建搜索区域
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: effectiveRadius * 2,
            longitudinalMeters: effectiveRadius * 2
        )

        // 创建搜索请求
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = keyword
        request.region = region

        // 执行搜索
        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            let pois = response.mapItems.map { POI.from(mapItem: $0) }
            return pois
        } catch {
            throw POISearchError.searchFailed(error.localizedDescription)
        }
    }
}

