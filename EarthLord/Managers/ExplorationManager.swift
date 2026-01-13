//
//  ExplorationManager.swift
//  EarthLord
//
//  探索管理器 - 管理探索生命周期、GPS追踪、速度检测、奖励计算
//

import Foundation
import CoreLocation
import Supabase
import Combine

/// 探索管理器
@MainActor
class ExplorationManager: ObservableObject {
    // MARK: - 单例
    static let shared = ExplorationManager()

    // MARK: - Published 属性
    @Published var isExploring: Bool = false
    @Published var currentSession: ExplorationSessionDB?
    @Published var explorationStartTime: Date?
    @Published var explorationDuration: TimeInterval = 0
    @Published var currentDistance: Double = 0
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []
    @Published var lastExplorationResult: ExplorationResult?
    @Published var error: String?

    // 速度相关
    @Published var currentSpeed: Double = 0  // 当前速度 (m/s)
    @Published var isSpeedWarning: Bool = false  // 是否正在超速警告
    @Published var speedWarningCountdown: Int = 0  // 超速警告倒计时（秒）

    // MARK: - 私有属性
    private let supabase = SupabaseConfig.shared
    private let rewardGenerator = RewardGenerator.shared
    private let inventoryManager = InventoryManager.shared

    private var locationManager: LocationManager?
    private var durationTimer: Timer?
    private var distanceUpdateTimer: Timer?
    private var speedWarningTimer: Timer?
    private var lastRecordedLocation: CLLocation?
    private var lastLocationUpdateTime: Date?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 配置常量

    /// GPS 位置精度阈值（米）- 精度差于此值的点会被忽略
    private let accuracyThreshold: Double = 50.0

    /// 最小移动距离（米）- 移动距离小于此值的点会被忽略（防止GPS抖动）
    private let minimumMovementDistance: Double = 3.0

    /// 距离更新间隔（秒）
    private let distanceUpdateInterval: TimeInterval = 1.0

    /// 最大允许速度（km/h）
    private let maxSpeedKmh: Double = 30.0

    /// 最大允许速度（m/s）- 30km/h = 8.33 m/s
    private var maxSpeedMs: Double {
        return maxSpeedKmh * 1000.0 / 3600.0  // 8.333... m/s
    }

    /// 超速警告时间（秒）- 超过此时间后停止探索
    private let speedWarningDuration: Int = 10

    // MARK: - 初始化

    private init() {
        LogManager.shared.info("[ExplorationManager] 初始化完成")
    }

    /// 设置 LocationManager 引用
    func setLocationManager(_ manager: LocationManager) {
        self.locationManager = manager
        LogManager.shared.info("[ExplorationManager] LocationManager 已设置")
    }

    // MARK: - 探索控制

    /// 开始探索
    func startExploration() async throws {
        LogManager.shared.info("[ExplorationManager] 开始探索请求")

        // 检查是否已在探索中
        guard !isExploring else {
            LogManager.shared.warning("[ExplorationManager] 已有探索进行中，拒绝新请求")
            throw ExplorationError.sessionAlreadyActive
        }

        // 获取用户 ID
        guard let userId = try? await supabase.auth.session.user.id else {
            LogManager.shared.error("[ExplorationManager] 用户未登录")
            throw ExplorationError.notAuthenticated
        }

        LogManager.shared.info("[ExplorationManager] 用户ID: \(userId.uuidString)")

        // 创建探索会话
        let sessionInsert = ExplorationSessionInsert(userId: userId)

        do {
            let response: ExplorationSessionDB = try await supabase
                .from("exploration_sessions")
                .insert(sessionInsert)
                .select()
                .single()
                .execute()
                .value

            // 更新本地状态
            currentSession = response
            isExploring = true
            explorationStartTime = Date()
            explorationDuration = 0
            currentDistance = 0
            currentSpeed = 0
            pathCoordinates = []
            lastRecordedLocation = nil
            lastLocationUpdateTime = nil
            error = nil
            isSpeedWarning = false
            speedWarningCountdown = 0

            // 开始计时器
            startDurationTimer()

            // 开始距离和速度追踪
            startDistanceTracking()

            LogManager.shared.success("[ExplorationManager] 探索已开始")
            LogManager.shared.info("[ExplorationManager] 会话ID: \(response.id)")
            LogManager.shared.info("[ExplorationManager] 最大速度限制: \(maxSpeedKmh) km/h (\(String(format: "%.2f", maxSpeedMs)) m/s)")

        } catch {
            LogManager.shared.error("[ExplorationManager] 创建探索会话失败: \(error.localizedDescription)")
            throw ExplorationError.databaseError(error.localizedDescription)
        }
    }

    /// 结束探索并计算奖励
    func stopExploration() async throws -> ExplorationResult {
        LogManager.shared.info("[ExplorationManager] 结束探索请求")

        guard isExploring, let session = currentSession else {
            LogManager.shared.error("[ExplorationManager] 没有进行中的探索")
            throw ExplorationError.noActiveSession
        }

        // 停止计时器
        stopTimers()

        // 计算最终数据
        let finalDistance = currentDistance
        let duration = Int(explorationDuration)
        let endTime = Date()

        LogManager.shared.info("[ExplorationManager] 探索统计:")
        LogManager.shared.info("[ExplorationManager] - 总距离: \(Int(finalDistance))米")
        LogManager.shared.info("[ExplorationManager] - 总时长: \(duration)秒")
        LogManager.shared.info("[ExplorationManager] - 路径点数: \(pathCoordinates.count)")

        // 加载物品定义并生成奖励
        let itemDefinitions: [ItemDefinition]
        if inventoryManager.itemDefinitions.isEmpty {
            LogManager.shared.info("[ExplorationManager] 加载物品定义...")
            itemDefinitions = try await inventoryManager.loadItemDefinitions()
        } else {
            itemDefinitions = inventoryManager.itemDefinitions
        }

        let rewards = rewardGenerator.generateRewards(
            distance: finalDistance,
            itemDefinitions: itemDefinitions
        )

        LogManager.shared.info("[ExplorationManager] 奖励计算:")
        LogManager.shared.info("[ExplorationManager] - 奖励等级: \(rewards.tier.displayName)")
        LogManager.shared.info("[ExplorationManager] - 物品数量: \(rewards.totalItemCount)")
        LogManager.shared.info("[ExplorationManager] - 经验值: \(rewards.experience)")

        // 更新会话记录
        let updateData = ExplorationSessionUpdate(
            endedAt: endTime,
            durationSeconds: duration,
            distanceWalked: finalDistance,
            rewardTier: rewards.tier.rawValue,
            itemsFound: rewards.items.isEmpty ? nil : rewards.items,
            experienceGained: rewards.experience,
            status: ExplorationSessionStatus.completed.rawValue
        )

        do {
            try await supabase
                .from("exploration_sessions")
                .update(updateData)
                .eq("id", value: session.id.uuidString)
                .execute()

            LogManager.shared.info("[ExplorationManager] 数据库会话已更新")

            // 添加物品到背包（如果有奖励）
            if !rewards.items.isEmpty {
                LogManager.shared.info("[ExplorationManager] 添加物品到背包...")
                try await inventoryManager.addItems(rewards.items, explorationSessionId: session.id)
                LogManager.shared.success("[ExplorationManager] 物品已添加到背包")
            }

            // 构建探索结果（移除面积相关字段）
            let result = ExplorationResult(
                distanceWalked: finalDistance,
                duration: TimeInterval(duration),
                itemsFound: rewards.items,
                experienceGained: rewards.experience,
                totalDistanceWalked: finalDistance,  // TODO: 从统计表获取累计数据
                distanceRanking: 0,  // TODO: 从排行榜获取
                timestamp: endTime
            )

            // 重置状态
            resetState()
            lastExplorationResult = result

            LogManager.shared.success("[ExplorationManager] 探索完成！")
            LogManager.shared.info("[ExplorationManager] 距离: \(Int(finalDistance))m, 奖励等级: \(rewards.tier.displayName)")

            return result

        } catch {
            LogManager.shared.error("[ExplorationManager] 更新探索会话失败: \(error.localizedDescription)")
            throw ExplorationError.databaseError(error.localizedDescription)
        }
    }

    /// 因超速停止探索（失败）
    func stopExplorationDueToSpeed() async {
        LogManager.shared.warning("[ExplorationManager] 因超速停止探索")

        guard isExploring, let session = currentSession else { return }

        // 停止计时器
        stopTimers()

        // 更新会话状态为失败
        do {
            try await supabase
                .from("exploration_sessions")
                .update(["status": "failed"])
                .eq("id", value: session.id.uuidString)
                .execute()

            LogManager.shared.info("[ExplorationManager] 探索会话已标记为失败")
        } catch {
            LogManager.shared.error("[ExplorationManager] 更新探索状态失败: \(error.localizedDescription)")
        }

        // 设置错误信息
        error = "探索失败：移动速度超过 \(Int(maxSpeedKmh)) km/h 限制"

        // 重置状态
        resetState()

        LogManager.shared.error("[ExplorationManager] 探索因超速失败")
    }

    /// 取消探索
    func cancelExploration() async {
        LogManager.shared.info("[ExplorationManager] 取消探索请求")

        guard isExploring, let session = currentSession else { return }

        // 停止计时器
        stopTimers()

        // 更新会话状态为已取消
        do {
            try await supabase
                .from("exploration_sessions")
                .update(["status": ExplorationSessionStatus.cancelled.rawValue])
                .eq("id", value: session.id.uuidString)
                .execute()

            LogManager.shared.info("[ExplorationManager] 探索已取消")

        } catch {
            LogManager.shared.error("[ExplorationManager] 取消探索失败: \(error.localizedDescription)")
        }

        // 重置状态
        resetState()
    }

    // MARK: - 私有方法

    /// 开始探索时长计时器
    private func startDurationTimer() {
        LogManager.shared.info("[ExplorationManager] 启动时长计时器")

        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isExploring else { return }
                self.explorationDuration += 1
            }
        }
    }

    /// 开始距离和速度追踪
    private func startDistanceTracking() {
        LogManager.shared.info("[ExplorationManager] 启动距离追踪，间隔: \(distanceUpdateInterval)秒")

        distanceUpdateTimer = Timer.scheduledTimer(withTimeInterval: distanceUpdateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDistanceAndSpeed()
            }
        }
    }

    /// 更新行走距离和速度
    private func updateDistanceAndSpeed() {
        guard isExploring else { return }

        // 获取当前位置
        guard let locationManager = locationManager,
              let currentCoordinate = locationManager.userLocation else {
            LogManager.shared.warning("[ExplorationManager] 无法获取当前位置")
            return
        }

        let currentLocation = CLLocation(
            latitude: currentCoordinate.latitude,
            longitude: currentCoordinate.longitude
        )
        let currentTime = Date()

        // 计算与上一个点的距离和速度
        if let lastLocation = lastRecordedLocation, let lastTime = lastLocationUpdateTime {
            let distance = currentLocation.distance(from: lastLocation)
            let timeInterval = currentTime.timeIntervalSince(lastTime)

            // 计算速度（m/s）
            let speed = timeInterval > 0 ? distance / timeInterval : 0
            currentSpeed = speed

            let speedKmh = speed * 3.6  // 转换为 km/h

            // 检查速度是否超限
            if speed > maxSpeedMs {
                handleSpeedExceeded(speedKmh: speedKmh)
            } else {
                // 速度恢复正常
                if isSpeedWarning {
                    LogManager.shared.info("[ExplorationManager] 速度恢复正常: \(String(format: "%.1f", speedKmh)) km/h")
                    cancelSpeedWarning()
                }

                // 只有移动超过最小距离且速度正常才记录
                if distance >= minimumMovementDistance {
                    currentDistance += distance
                    pathCoordinates.append(currentCoordinate)
                    lastRecordedLocation = currentLocation
                    lastLocationUpdateTime = currentTime

                    // 详细日志
                    LogManager.shared.info("[ExplorationManager] 位置更新:")
                    LogManager.shared.info("  - 移动距离: \(String(format: "%.1f", distance))m")
                    LogManager.shared.info("  - 当前速度: \(String(format: "%.1f", speedKmh)) km/h")
                    LogManager.shared.info("  - 累计距离: \(Int(currentDistance))m")
                    LogManager.shared.info("  - 路径点数: \(pathCoordinates.count)")
                }
            }
        } else {
            // 记录起始点
            lastRecordedLocation = currentLocation
            lastLocationUpdateTime = currentTime
            pathCoordinates.append(currentCoordinate)

            LogManager.shared.info("[ExplorationManager] 记录起始点:")
            LogManager.shared.info("  - 坐标: (\(String(format: "%.6f", currentCoordinate.latitude)), \(String(format: "%.6f", currentCoordinate.longitude)))")
        }
    }

    /// 处理超速情况
    private func handleSpeedExceeded(speedKmh: Double) {
        if !isSpeedWarning {
            // 开始超速警告
            isSpeedWarning = true
            speedWarningCountdown = speedWarningDuration

            LogManager.shared.warning("[ExplorationManager] 检测到超速！")
            LogManager.shared.warning("[ExplorationManager] 当前速度: \(String(format: "%.1f", speedKmh)) km/h (限制: \(Int(maxSpeedKmh)) km/h)")
            LogManager.shared.warning("[ExplorationManager] 开始 \(speedWarningDuration) 秒倒计时警告")

            startSpeedWarningTimer()
        } else {
            // 更新当前超速状态
            LogManager.shared.warning("[ExplorationManager] 持续超速: \(String(format: "%.1f", speedKmh)) km/h, 剩余 \(speedWarningCountdown) 秒")
        }
    }

    /// 开始超速警告计时器
    private func startSpeedWarningTimer() {
        speedWarningTimer?.invalidate()

        speedWarningTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }

                if self.speedWarningCountdown > 0 {
                    self.speedWarningCountdown -= 1
                    LogManager.shared.warning("[ExplorationManager] 超速警告倒计时: \(self.speedWarningCountdown) 秒")

                    if self.speedWarningCountdown == 0 {
                        // 倒计时结束，停止探索
                        LogManager.shared.error("[ExplorationManager] 超速警告时间到，强制结束探索")
                        await self.stopExplorationDueToSpeed()
                    }
                }
            }
        }
    }

    /// 取消超速警告
    private func cancelSpeedWarning() {
        isSpeedWarning = false
        speedWarningCountdown = 0
        speedWarningTimer?.invalidate()
        speedWarningTimer = nil

        LogManager.shared.info("[ExplorationManager] 超速警告已取消")
    }

    /// 停止所有计时器
    private func stopTimers() {
        LogManager.shared.info("[ExplorationManager] 停止所有计时器")

        durationTimer?.invalidate()
        durationTimer = nil

        distanceUpdateTimer?.invalidate()
        distanceUpdateTimer = nil

        speedWarningTimer?.invalidate()
        speedWarningTimer = nil
    }

    /// 重置状态
    private func resetState() {
        LogManager.shared.info("[ExplorationManager] 重置状态")

        isExploring = false
        currentSession = nil
        explorationStartTime = nil
        explorationDuration = 0
        currentDistance = 0
        currentSpeed = 0
        pathCoordinates = []
        lastRecordedLocation = nil
        lastLocationUpdateTime = nil
        isSpeedWarning = false
        speedWarningCountdown = 0
    }

    // MARK: - 辅助方法

    /// 格式化探索时长
    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60

        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }

    /// 格式化距离
    func formatDistance(_ distance: Double) -> String {
        if distance >= 1000 {
            return String(format: "%.1f公里", distance / 1000)
        } else {
            return "\(Int(distance))米"
        }
    }

    /// 格式化速度
    func formatSpeed(_ speedMs: Double) -> String {
        let speedKmh = speedMs * 3.6
        return String(format: "%.1f km/h", speedKmh)
    }

    /// 获取当前奖励等级预览
    var currentRewardTierPreview: RewardTier {
        return RewardTier.fromDistance(currentDistance)
    }

    /// 获取下一等级所需距离
    var distanceToNextTier: Double? {
        let currentTier = currentRewardTierPreview

        switch currentTier {
        case .none:
            return 200 - currentDistance
        case .bronze:
            return 500 - currentDistance
        case .silver:
            return 1000 - currentDistance
        case .gold:
            return 2000 - currentDistance
        case .diamond:
            return nil  // 已是最高等级
        }
    }
}

// MARK: - 测试辅助

extension ExplorationManager {
    /// 模拟探索（用于测试）
    func simulateExploration(distance: Double) async throws -> ExplorationResult {
        LogManager.shared.info("[ExplorationManager] 模拟探索，距离: \(Int(distance))米")

        // 获取用户 ID
        guard let userId = try? await supabase.auth.session.user.id else {
            throw ExplorationError.notAuthenticated
        }

        // 加载物品定义
        let itemDefinitions: [ItemDefinition]
        if inventoryManager.itemDefinitions.isEmpty {
            itemDefinitions = try await inventoryManager.loadItemDefinitions()
        } else {
            itemDefinitions = inventoryManager.itemDefinitions
        }

        // 生成奖励
        let rewards = rewardGenerator.generateRewards(
            distance: distance,
            itemDefinitions: itemDefinitions
        )

        // 创建探索会话记录
        let sessionInsert = ExplorationSessionInsert(userId: userId)

        let session: ExplorationSessionDB = try await supabase
            .from("exploration_sessions")
            .insert(sessionInsert)
            .select()
            .single()
            .execute()
            .value

        // 更新为已完成状态
        let updateData = ExplorationSessionUpdate(
            endedAt: Date(),
            durationSeconds: Int(distance / 1.5),  // 假设平均速度 1.5m/s
            distanceWalked: distance,
            rewardTier: rewards.tier.rawValue,
            itemsFound: rewards.items.isEmpty ? nil : rewards.items,
            experienceGained: rewards.experience,
            status: ExplorationSessionStatus.completed.rawValue
        )

        try await supabase
            .from("exploration_sessions")
            .update(updateData)
            .eq("id", value: session.id.uuidString)
            .execute()

        // 添加物品到背包
        if !rewards.items.isEmpty {
            try await inventoryManager.addItems(rewards.items, explorationSessionId: session.id)
        }

        // 构建结果（移除面积相关）
        let result = ExplorationResult(
            distanceWalked: distance,
            duration: TimeInterval(Int(distance / 1.5)),
            itemsFound: rewards.items,
            experienceGained: rewards.experience,
            totalDistanceWalked: distance,
            distanceRanking: 0,
            timestamp: Date()
        )

        lastExplorationResult = result

        LogManager.shared.success("[ExplorationManager] 模拟探索完成")
        return result
    }
}
