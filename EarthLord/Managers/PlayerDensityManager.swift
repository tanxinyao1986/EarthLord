//
//  PlayerDensityManager.swift
//  EarthLord
//
//  Created by Claude on 2026-01-14.
//  附近玩家密度检测管理器
//

import Foundation
import CoreLocation
import Supabase
import Combine

class PlayerDensityManager: ObservableObject {
    // MARK: - 单例
    static let shared = PlayerDensityManager()

    // MARK: - Published 属性

    @MainActor @Published var nearbyPlayerCount: Int = 0
    @MainActor @Published var densityLevel: DensityLevel = .solo
    @MainActor @Published var isReporting: Bool = false

    // MARK: - 私有属性

    private let supabase = SupabaseConfig.shared
    private var reportTimer: Timer?
    private var lastReportedLocation: CLLocation?
    private var lastReportTime: Date?
    private var cachedCurrentLocation: CLLocation?

    // MARK: - 配置常量

    private let reportInterval: TimeInterval = 30
    private let minMovementDistance: Double = 50
    private let queryRadiusMeters: Double = 1000

    // MARK: - 初始化

    private init() {
        LogManager.shared.info("[PlayerDensityManager] 初始化完成")
    }

    // MARK: - 公开方法

    @MainActor
    func startReporting() {
        guard !isReporting else {
            LogManager.shared.warning("[PlayerDensityManager] 位置上报已在运行")
            return
        }

        isReporting = true
        startReportTimer()
        LogManager.shared.success("[PlayerDensityManager] 位置上报已启动，间隔: \(reportInterval)秒")
    }

    @MainActor
    func stopReporting() {
        guard isReporting else { return }

        isReporting = false
        stopReportTimer()
        LogManager.shared.info("[PlayerDensityManager] 位置上报已停止")
    }

    func reportLocation(_ location: CLLocation) async {
        await _reportLocation(location: location, isOnline: true)
    }

    @MainActor
    func checkAndReportIfNeeded(_ location: CLLocation) async {
        guard isReporting else { return }

        cachedCurrentLocation = location

        guard let lastLocation = lastReportedLocation else {
            await reportLocation(location)
            return
        }

        let distance = location.distance(from: lastLocation)

        if distance >= minMovementDistance {
            LogManager.shared.info("""
            [PlayerDensityManager] 移动距离触发上报
            - 移动距离: \(String(format: "%.1f", distance))米
            - 触发阈值: \(minMovementDistance)米
            """)
            await reportLocation(location)
        }
    }

    func queryNearbyPlayerDensity(_ location: CLLocation) async throws -> DensityLevel {
        let count = await _queryNearbyPlayers(location: location)
        let densityLevel = DensityLevel.from(playerCount: count)

        await MainActor.run {
            self.nearbyPlayerCount = count
            self.densityLevel = densityLevel
        }

        LogManager.shared.success("""
        [PlayerDensityManager] 密度查询成功
        - 附近玩家数量: \(count)人
        - 密度等级: \(densityLevel.description)
        - 建议POI数量: \(densityLevel.poiCount)个
        - 查询半径: \(queryRadiusMeters)米
        """)

        return densityLevel
    }

    @MainActor
    func markOffline() async {
        guard let lastLocation = lastReportedLocation else {
            LogManager.shared.warning("[PlayerDensityManager] 无法标记离线：没有上次位置记录")
            return
        }

        await _reportLocation(location: lastLocation, isOnline: false)
    }

    func markOnline(_ location: CLLocation) async {
        await _reportLocation(location: location, isOnline: true)
    }

    // MARK: - 私有方法

    private nonisolated func _reportLocation(location: CLLocation, isOnline: Bool) async {
        // 在函数内部定义结构体，避免 MainActor 隔离问题
        struct Request: Encodable {
            let p_user_id: String
            let p_latitude: Double
            let p_longitude: Double
            let p_accuracy: Double?
            let p_is_online: Bool
        }

        do {
            let supabaseClient = SupabaseConfig.shared
            let session = try await supabaseClient.auth.session
            let userId = session.user.id

            let request = Request(
                p_user_id: userId.uuidString,
                p_latitude: location.coordinate.latitude,
                p_longitude: location.coordinate.longitude,
                p_accuracy: location.horizontalAccuracy > 0 ? location.horizontalAccuracy : nil,
                p_is_online: isOnline
            )

            _ = try await supabaseClient
                .rpc("upsert_user_location", params: request)
                .execute()

            await MainActor.run {
                self.lastReportedLocation = location
                self.lastReportTime = Date()
            }

            LogManager.shared.success("""
            [PlayerDensityManager] 位置上报成功(\(isOnline ? "在线" : "离线"))
            - 位置: (\(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude)))
            - 精度: \(String(format: "%.1f", location.horizontalAccuracy))米
            """)

        } catch {
            LogManager.shared.error("[PlayerDensityManager] 位置上报失败: \(error.localizedDescription)")
        }
    }

    private nonisolated func _queryNearbyPlayers(location: CLLocation) async -> Int {
        // 在函数内部定义结构体
        struct Request: Encodable {
            let p_user_id: String
            let p_latitude: Double
            let p_longitude: Double
            let p_radius_meters: Double
        }

        do {
            let supabaseClient = SupabaseConfig.shared
            let session = try await supabaseClient.auth.session
            let userId = session.user.id

            let queryRadius = await MainActor.run { queryRadiusMeters }

            let request = Request(
                p_user_id: userId.uuidString,
                p_latitude: location.coordinate.latitude,
                p_longitude: location.coordinate.longitude,
                p_radius_meters: queryRadius
            )

            let response = try await supabaseClient
                .rpc("get_nearby_online_players_count", params: request)
                .execute()

            // response.data 是 Data 类型（非可选）
            let data = response.data
            if let jsonString = String(data: data, encoding: .utf8),
               let parsedCount = Int(jsonString) {
                return parsedCount
            } else {
                LogManager.shared.warning("[PlayerDensityManager] 无法解析密度查询响应，使用默认值0")
                return 0
            }

        } catch {
            LogManager.shared.error("[PlayerDensityManager] 密度查询失败: \(error.localizedDescription)")
            return 0
        }
    }

    @MainActor
    private func startReportTimer() {
        stopReportTimer()

        reportTimer = Timer.scheduledTimer(
            withTimeInterval: reportInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                LogManager.shared.info("[PlayerDensityManager] 定时器触发位置上报")

                if let currentLocation = self.cachedCurrentLocation {
                    await self.reportLocation(currentLocation)
                } else {
                    LogManager.shared.warning("[PlayerDensityManager] 定时器触发时位置不可用（尚未缓存）")
                }
            }
        }

        Task { @MainActor [weak self] in
            guard let self = self else { return }

            if let currentLocation = self.cachedCurrentLocation {
                LogManager.shared.info("[PlayerDensityManager] 启动时立即上报位置")
                await self.reportLocation(currentLocation)
            } else {
                LogManager.shared.info("[PlayerDensityManager] 启动时位置尚未缓存，等待GPS更新")
            }
        }
    }

    @MainActor
    private func stopReportTimer() {
        reportTimer?.invalidate()
        reportTimer = nil
    }
}
