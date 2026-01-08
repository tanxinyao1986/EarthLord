//
//  TerritoryManager.swift
//  EarthLord
//
//  Created by Claude Code
//

import Foundation
import CoreLocation
import Supabase

/// 领地管理器
/// 负责领地的上传和拉取
@MainActor
class TerritoryManager {

    // MARK: - Singleton

    static let shared = TerritoryManager()

    // MARK: - Properties

    private let supabase = SupabaseConfig.shared

    /// 已加载的所有领地（用于碰撞检测）
    var territories: [Territory] = []

    // MARK: - Initialization

    private init() {}

    // MARK: - Data Conversion

    /// 将坐标数组转换为 path JSON 格式
    /// - Parameter coordinates: 坐标数组
    /// - Returns: [{"lat": x, "lon": y}, ...]
    private func coordinatesToPathJSON(_ coordinates: [CLLocationCoordinate2D]) -> [[String: Double]] {
        return coordinates.map { coordinate in
            [
                "lat": coordinate.latitude,
                "lon": coordinate.longitude
            ]
        }
    }

    /// 将坐标数组转换为 WKT (Well-Known Text) 格式
    /// - Parameter coordinates: 坐标数组
    /// - Returns: WKT 格式的 POLYGON 字符串
    /// - Note: ⚠️ WKT 格式是「经度在前，纬度在后」
    /// - Note: ⚠️ 多边形必须闭合（首尾相同）
    private func coordinatesToWKT(_ coordinates: [CLLocationCoordinate2D]) -> String {
        // 确保多边形闭合
        var closedCoordinates = coordinates
        if let first = coordinates.first, let last = coordinates.last {
            // 检查首尾是否相同
            if first.latitude != last.latitude || first.longitude != last.longitude {
                closedCoordinates.append(first)
            }
        }

        // 转换为 WKT 格式：经度在前，纬度在后
        let coordinatesString = closedCoordinates
            .map { "\($0.longitude) \($0.latitude)" }
            .joined(separator: ", ")

        return "SRID=4326;POLYGON((\(coordinatesString)))"
    }

    /// 计算边界框
    /// - Parameter coordinates: 坐标数组
    /// - Returns: (minLat, maxLat, minLon, maxLon)
    private func calculateBoundingBox(_ coordinates: [CLLocationCoordinate2D]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        guard !coordinates.isEmpty else {
            return (0, 0, 0, 0)
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        return (minLat, maxLat, minLon, maxLon)
    }

    // MARK: - Upload Territory

    /// 领地上传数据结构
    private struct TerritoryUploadData: Encodable {
        let userId: String
        let path: [[String: Double]]
        let polygon: String
        let bboxMinLat: Double
        let bboxMaxLat: Double
        let bboxMinLon: Double
        let bboxMaxLon: Double
        let area: Double
        let pointCount: Int
        let startedAt: String
        let isActive: Bool

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case path
            case polygon
            case bboxMinLat = "bbox_min_lat"
            case bboxMaxLat = "bbox_max_lat"
            case bboxMinLon = "bbox_min_lon"
            case bboxMaxLon = "bbox_max_lon"
            case area
            case pointCount = "point_count"
            case startedAt = "started_at"
            case isActive = "is_active"
        }
    }

    /// 上传领地到 Supabase
    /// - Parameters:
    ///   - coordinates: 领地路径坐标数组
    ///   - area: 领地面积（平方米）
    ///   - startTime: 开始圈地时间
    /// - Throws: 上传失败时抛出错误
    func uploadTerritory(
        coordinates: [CLLocationCoordinate2D],
        area: Double,
        startTime: Date
    ) async throws {
        // 获取当前用户 ID
        guard let userId = try? await supabase.auth.session.user.id else {
            throw NSError(
                domain: "TerritoryManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "用户未登录"]
            )
        }

        // 转换数据格式
        let pathJSON = coordinatesToPathJSON(coordinates)
        let wktPolygon = coordinatesToWKT(coordinates)
        let bbox = calculateBoundingBox(coordinates)

        // 构建上传数据
        let territoryData = TerritoryUploadData(
            userId: userId.uuidString,
            path: pathJSON,
            polygon: wktPolygon,
            bboxMinLat: bbox.minLat,
            bboxMaxLat: bbox.maxLat,
            bboxMinLon: bbox.minLon,
            bboxMaxLon: bbox.maxLon,
            area: area,
            pointCount: coordinates.count,
            startedAt: startTime.ISO8601Format(),
            isActive: true
        )

        // 记录上传开始
        TerritoryLogger.shared.log(
            "开始上传领地：面积 \(String(format: "%.0f", area))m², 点数 \(coordinates.count)",
            type: .info
        )

        // 上传到 Supabase
        try await supabase
            .from("territories")
            .insert(territoryData)
            .execute()

        // 记录上传成功
        TerritoryLogger.shared.log(
            "领地上传成功！面积: \(String(format: "%.0f", area))m²",
            type: .success
        )
        LogManager.shared.log("✅ 领地上传成功", level: .success)
    }

    // MARK: - Load Territories

    /// 加载所有活跃的领地
    /// - Returns: 领地数组
    /// - Throws: 加载失败时抛出错误
    func loadAllTerritories() async throws -> [Territory] {
        let response = try await supabase
            .from("territories")
            .select()
            .eq("is_active", value: true)
            .execute()

        let loadedTerritories = try JSONDecoder().decode([Territory].self, from: response.data)

        // 更新本地缓存（用于碰撞检测）
        self.territories = loadedTerritories

        LogManager.shared.log("✅ 加载了 \(loadedTerritories.count) 个领地", level: .success)

        return loadedTerritories
    }

    /// 加载我的领地
    /// - Returns: 当前用户的领地数组
    /// - Throws: 加载失败时抛出错误
    func loadMyTerritories() async throws -> [Territory] {
        // 获取当前用户 ID
        guard let userId = try? await supabase.auth.session.user.id else {
            throw NSError(
                domain: "TerritoryManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "未登录"]
            )
        }

        let response = try await supabase
            .from("territories")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("is_active", value: true)
            .order("created_at", ascending: false)
            .execute()

        let territories = try JSONDecoder().decode([Territory].self, from: response.data)

        LogManager.shared.log("✅ 加载了 \(territories.count) 个我的领地", level: .success)

        return territories
    }

    // MARK: - Delete Territory

    /// 删除领地
    /// - Parameter territoryId: 领地 ID
    /// - Returns: 删除是否成功
    func deleteTerritory(territoryId: String) async -> Bool {
        do {
            try await supabase
                .from("territories")
                .delete()
                .eq("id", value: territoryId)
                .execute()

            LogManager.shared.log("✅ 删除领地成功: \(territoryId)", level: .success)
            TerritoryLogger.shared.log("删除领地成功", type: .success)

            return true
        } catch {
            LogManager.shared.log("❌ 删除领地失败: \(error.localizedDescription)", level: .error)
            TerritoryLogger.shared.log("删除领地失败: \(error.localizedDescription)", type: .error)

            return false
        }
    }

    // MARK: - 碰撞检测算法

    /// 射线法判断点是否在多边形内
    func isPointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }

        var inside = false
        let x = point.longitude
        let y = point.latitude

        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude

            let intersect = ((yi > y) != (yj > y)) &&
                           (x < (xj - xi) * (y - yi) / (yj - yi) + xi)

            if intersect {
                inside.toggle()
            }
            j = i
        }

        return inside
    }

    /// 检查起始点是否在他人领地内
    func checkPointCollision(location: CLLocationCoordinate2D, currentUserId: String) -> CollisionResult {
        let otherTerritories = territories.filter { territory in
            territory.userId.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else {
            return .safe
        }

        for territory in otherTerritories {
            let polygon = territory.toCoordinates()
            guard polygon.count >= 3 else { continue }

            if isPointInPolygon(point: location, polygon: polygon) {
                TerritoryLogger.shared.log("起点碰撞：位于他人领地内", type: .error)
                return CollisionResult(
                    hasCollision: true,
                    collisionType: .pointInTerritory,
                    message: "不能在他人领地内开始圈地！",
                    closestDistance: 0,
                    warningLevel: .violation
                )
            }
        }

        return .safe
    }

    /// 判断两条线段是否相交（CCW 算法）
    private func segmentsIntersect(
        p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
        p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D
    ) -> Bool {
        func ccw(_ A: CLLocationCoordinate2D, _ B: CLLocationCoordinate2D, _ C: CLLocationCoordinate2D) -> Bool {
            return (C.latitude - A.latitude) * (B.longitude - A.longitude) >
                   (B.latitude - A.latitude) * (C.longitude - A.longitude)
        }

        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 检查路径是否穿越他人领地边界
    func checkPathCrossTerritory(path: [CLLocationCoordinate2D], currentUserId: String) -> CollisionResult {
        guard path.count >= 2 else { return .safe }

        let otherTerritories = territories.filter { territory in
            territory.userId.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else { return .safe }

        for i in 0..<(path.count - 1) {
            let pathStart = path[i]
            let pathEnd = path[i + 1]

            for territory in otherTerritories {
                let polygon = territory.toCoordinates()
                guard polygon.count >= 3 else { continue }

                // 检查与领地每条边的相交
                for j in 0..<polygon.count {
                    let boundaryStart = polygon[j]
                    let boundaryEnd = polygon[(j + 1) % polygon.count]

                    if segmentsIntersect(p1: pathStart, p2: pathEnd, p3: boundaryStart, p4: boundaryEnd) {
                        TerritoryLogger.shared.log("路径碰撞：轨迹穿越他人领地边界", type: .error)
                        return CollisionResult(
                            hasCollision: true,
                            collisionType: .pathCrossTerritory,
                            message: "轨迹不能穿越他人领地！",
                            closestDistance: 0,
                            warningLevel: .violation
                        )
                    }
                }

                // 检查路径点是否在领地内
                if isPointInPolygon(point: pathEnd, polygon: polygon) {
                    TerritoryLogger.shared.log("路径碰撞：轨迹点进入他人领地", type: .error)
                    return CollisionResult(
                        hasCollision: true,
                        collisionType: .pointInTerritory,
                        message: "轨迹不能进入他人领地！",
                        closestDistance: 0,
                        warningLevel: .violation
                    )
                }
            }
        }

        return .safe
    }

    /// 计算当前位置到他人领地的最近距离
    func calculateMinDistanceToTerritories(location: CLLocationCoordinate2D, currentUserId: String) -> Double {
        let otherTerritories = territories.filter { territory in
            territory.userId.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else { return Double.infinity }

        var minDistance = Double.infinity
        let currentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)

        for territory in otherTerritories {
            let polygon = territory.toCoordinates()

            for vertex in polygon {
                let vertexLocation = CLLocation(latitude: vertex.latitude, longitude: vertex.longitude)
                let distance = currentLocation.distance(from: vertexLocation)
                minDistance = min(minDistance, distance)
            }
        }

        return minDistance
    }

    /// 综合碰撞检测（主方法）
    func checkPathCollisionComprehensive(path: [CLLocationCoordinate2D], currentUserId: String) -> CollisionResult {
        guard path.count >= 2 else { return .safe }

        // 1. 检查路径是否穿越他人领地
        let crossResult = checkPathCrossTerritory(path: path, currentUserId: currentUserId)
        if crossResult.hasCollision {
            return crossResult
        }

        // 2. 计算到最近领地的距离
        guard let lastPoint = path.last else { return .safe }
        let minDistance = calculateMinDistanceToTerritories(location: lastPoint, currentUserId: currentUserId)

        // 3. 根据距离确定预警级别和消息
        let warningLevel: WarningLevel
        let message: String?

        if minDistance > 100 {
            warningLevel = .safe
            message = nil
        } else if minDistance > 50 {
            warningLevel = .caution
            message = "注意：距离他人领地 \(Int(minDistance))m"
        } else if minDistance > 25 {
            warningLevel = .warning
            message = "警告：正在靠近他人领地（\(Int(minDistance))m）"
        } else {
            warningLevel = .danger
            message = "危险：即将进入他人领地！（\(Int(minDistance))m）"
        }

        if warningLevel != .safe {
            TerritoryLogger.shared.log("距离预警：\(warningLevel.description)，距离 \(Int(minDistance))m", type: .warning)
        }

        return CollisionResult(
            hasCollision: false,
            collisionType: nil,
            message: message,
            closestDistance: minDistance,
            warningLevel: warningLevel
        )
    }
}
