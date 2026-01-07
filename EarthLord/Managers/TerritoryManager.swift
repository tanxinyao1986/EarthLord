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

        let territories = try JSONDecoder().decode([Territory].self, from: response.data)

        LogManager.shared.log("✅ 加载了 \(territories.count) 个领地", level: .success)

        return territories
    }
}
