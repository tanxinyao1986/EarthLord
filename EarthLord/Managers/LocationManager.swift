//
//  LocationManager.swift
//  EarthLord
//
//  GPS 定位管理器 - 负责请求定位权限和获取用户位置
//

import Foundation
import CoreLocation
import Combine  // ⚠️ 重要：@Published 需要这个框架

// MARK: - LocationManager 主类
class LocationManager: NSObject, ObservableObject {
    // MARK: - 单例
    static let shared = LocationManager()

    // MARK: - Published 属性（自动通知 SwiftUI 更新）

    /// 用户当前位置坐标
    @Published var userLocation: CLLocationCoordinate2D?

    /// 定位授权状态
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// 错误信息（用于显示提示）
    @Published var locationError: String?

    /// 是否正在追踪路径
    @Published var isTracking: Bool = false

    /// 路径坐标数组（存储原始 WGS-84 坐标）
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []

    /// 路径更新版本号（每次更新 +1，触发 SwiftUI 刷新）
    @Published var pathUpdateVersion: Int = 0

    /// 路径是否闭合（Day16 会用）
    @Published var isPathClosed: Bool = false

    /// 速度警告信息（超速时显示）
    @Published var speedWarning: String?

    /// 是否超速（用于UI判断）
    @Published var isOverSpeed: Bool = false

    // MARK: - 验证状态属性

    /// 领地验证是否通过
    @Published var territoryValidationPassed: Bool = false

    /// 领地验证错误信息
    @Published var territoryValidationError: String? = nil

    /// 计算得到的领地面积（平方米）
    @Published var calculatedArea: Double = 0

    // MARK: - Day22: POI 地理围栏属性

    /// 当前进入的 POI（用于触发弹窗）
    @Published var enteredPOI: POI?

    /// 正在监控的 POI 列表
    private(set) var monitoredPOIs: [String: POI] = [:]

    // MARK: - 私有属性

    /// CoreLocation 定位管理器
    private let locationManager = CLLocationManager()

    /// 当前位置（用于定时器采点和位置上报）
    private(set) var currentLocation: CLLocation?

    /// 路径追踪定时器（每 2 秒采一次点）
    private var pathUpdateTimer: Timer?


    // MARK: - 验证常量配置

    /// 闭环距离阈值（米）- 已调整为原来的一半，方便小空间测试
    private let closureDistanceThreshold: Double = 15.0

    /// 最少路径点数（闭环需要至少这么多点）
    private let minimumPathPoints: Int = 10

    /// 最小行走距离（米）
    private let minimumTotalDistance: Double = 50.0

    /// 最小领地面积（平方米）
    private let minimumEnclosedArea: Double = 100.0

    // MARK: - 初始化

    override init() {
        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest  // 最高精度
        locationManager.distanceFilter = 5  // 移动 5 米才更新一次（方便小空间测试）

        // 获取当前授权状态
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - 公开方法

    /// 请求定位权限（使用 App 期间）
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// 开始定位
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }

    /// 停止定位
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - 路径追踪方法

    /// 开始追踪路径（启动定时器，每 2 秒采点）
    func startPathTracking() {
        isTracking = true
        pathCoordinates.removeAll()  // 清空旧路径
        isPathClosed = false
        pathUpdateVersion = 0
        speedWarning = nil  // 清除速度警告
        isOverSpeed = false

        // 启动定时器（每 2 秒检查一次是否需要记录新点）
        pathUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.recordPathPoint()
        }

        print("✅ 开始路径追踪")
        LogManager.shared.info("开始圈地追踪")
    }

    /// 停止追踪路径（停止定时器并重置所有状态）
    func stopPathTracking() {
        isTracking = false
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil

        // 重置验证状态
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0

        // 清除路径数据
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        isPathClosed = false

        print("⏹️ 停止路径追踪并重置所有状态")
        LogManager.shared.info("停止追踪并重置状态")
    }

    /// 清除路径
    func clearPath() {
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        isPathClosed = false
        print("🗑️ 路径已清除")
    }

    /// 记录路径点（定时器回调）
    private func recordPathPoint() {
        // 获取当前位置
        guard let location = currentLocation else {
            print("⚠️ 无法记录路径点：位置未获取")
            return
        }

        // ⭐ 速度检测：防止作弊（坐车、开车等）
        if !validateMovementSpeed(newLocation: location) {
            print("🚫 速度超标，跳过此点记录")
            return
        }

        let coordinate = location.coordinate

        // 判断是否需要记录新点（距离上个点 > 5 米）- 已调整为原来的一半，方便小空间测试
        if let lastCoordinate = pathCoordinates.last {
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let distance = location.distance(from: lastLocation)

            // 距离太近，不记录
            if distance < 5 {
                print("⏭️ 距离上个点 \(String(format: "%.1f", distance)) 米，跳过记录")
                return
            }
        }

        // 记录新点
        pathCoordinates.append(coordinate)
        pathUpdateVersion += 1

        print("📍 记录路径点 #\(pathCoordinates.count)：\(coordinate.latitude), \(coordinate.longitude)")
        LogManager.shared.info("记录路径点 #\(pathCoordinates.count)")

        // ⭐ 闭环检测：检查是否走回起点
        checkPathClosure()
    }

    /// 验证移动速度（防止作弊）
    /// - Parameter newLocation: 新位置
    /// - Returns: true = 速度正常，false = 速度超标
    private func validateMovementSpeed(newLocation: CLLocation) -> Bool {
        // ⭐ 使用 GPS 直接提供的速度（m/s），避免手动计算导致的误差
        let speedInMetersPerSecond = newLocation.speed

        // 速度值无效（< 0 表示 GPS 无法测量速度）
        guard speedInMetersPerSecond >= 0 else {
            print("⚠️ GPS 速度无效，跳过检测")
            return true
        }

        // 转换为 km/h
        let speedInKmPerHour = speedInMetersPerSecond * 3.6

        print("🏃 当前速度：\(String(format: "%.1f", speedInKmPerHour)) km/h（GPS 直接测量）")

        // 速度超过 30 km/h → 严重超速，暂停追踪
        if speedInKmPerHour > 30 {
            speedWarning = "⚠️ 速度超过 30 km/h，已暂停追踪"
            isOverSpeed = true
            stopPathTracking()
            print("🚨 严重超速！已暂停追踪")
            LogManager.shared.error("速度超过 30 km/h（\(String(format: "%.1f", speedInKmPerHour)) km/h），已暂停追踪")
            return false
        }

        // 速度超过 15 km/h → 警告
        if speedInKmPerHour > 15 {
            speedWarning = "⚠️ 速度超过 15 km/h，请减速"
            isOverSpeed = true
            print("⚠️ 警告：速度过快")
            LogManager.shared.warning("速度较快 \(String(format: "%.1f", speedInKmPerHour)) km/h")
            return true  // 仍然记录点，但显示警告
        }

        // 速度正常，清除警告
        speedWarning = nil
        isOverSpeed = false
        return true
    }

    /// 检查路径是否闭合（走回起点）
    private func checkPathClosure() {
        // 已经闭合，不再检查
        guard !isPathClosed else { return }

        // 点数不足，无法闭合
        guard pathCoordinates.count >= minimumPathPoints else {
            print("📊 当前点数：\(pathCoordinates.count)/\(minimumPathPoints)，尚未达到闭环检测条件")
            return
        }

        // 获取起点和当前点
        guard let startPoint = pathCoordinates.first,
              let currentPoint = pathCoordinates.last else { return }

        // 计算当前点到起点的距离
        let startLocation = CLLocation(latitude: startPoint.latitude, longitude: startPoint.longitude)
        let currentLocation = CLLocation(latitude: currentPoint.latitude, longitude: currentPoint.longitude)
        let distance = currentLocation.distance(from: startLocation)

        print("🎯 闭环检测：当前距起点 \(String(format: "%.1f", distance)) 米")

        // 距离小于阈值，判定为闭合
        if distance <= closureDistanceThreshold {
            isPathClosed = true
            pathUpdateVersion += 1  // 触发 UI 更新
            print("✅ 闭环检测成功！距起点 \(String(format: "%.1f", distance)) 米，已自动闭合路径")
            LogManager.shared.success("闭环成功！距起点 \(String(format: "%.1f", distance)) 米")

            // ⭐ 闭环成功后，立即进行领地验证
            let validationResult = validateTerritory()
            if validationResult.isValid {
                TerritoryLogger.shared.log("领地验证通过！面积: \(String(format: "%.0f", calculatedArea))m²", type: .success)
            } else {
                TerritoryLogger.shared.log("领地验证失败：\(validationResult.errorMessage ?? "未知错误")", type: .error)
            }
        }
    }

    // MARK: - 距离与面积计算

    /// 计算路径总距离（米）- 公开方法供 ExplorationManager 使用
    func calculateTotalPathDistance() -> Double {
        guard pathCoordinates.count >= 2 else { return 0 }

        var totalDistance: Double = 0

        // 遍历相邻点，累加距离
        for i in 0..<(pathCoordinates.count - 1) {
            let current = pathCoordinates[i]
            let next = pathCoordinates[i + 1]

            let currentLocation = CLLocation(latitude: current.latitude, longitude: current.longitude)
            let nextLocation = CLLocation(latitude: next.latitude, longitude: next.longitude)

            totalDistance += currentLocation.distance(from: nextLocation)
        }

        return totalDistance
    }

    /// 计算多边形面积（平方米，使用鞋带公式，考虑地球曲率）
    private func calculatePolygonArea() -> Double {
        guard pathCoordinates.count >= 3 else { return 0 }

        let earthRadius: Double = 6371000  // 地球半径（米）
        var area: Double = 0

        // 鞋带公式（球面修正版本）
        for i in 0..<pathCoordinates.count {
            let current = pathCoordinates[i]
            let next = pathCoordinates[(i + 1) % pathCoordinates.count]  // 循环取点

            // 经纬度转弧度
            let lat1 = current.latitude * .pi / 180
            let lon1 = current.longitude * .pi / 180
            let lat2 = next.latitude * .pi / 180
            let lon2 = next.longitude * .pi / 180

            // 鞋带公式（球面修正）
            area += (lon2 - lon1) * (2 + sin(lat1) + sin(lat2))
        }

        area = abs(area * earthRadius * earthRadius / 2.0)
        return area
    }

    // MARK: - 自相交检测

    /// 判断两条线段是否相交（使用 CCW 算法）
    /// - Parameters:
    ///   - p1: 第一条线段的起点
    ///   - p2: 第一条线段的终点
    ///   - p3: 第二条线段的起点
    ///   - p4: 第二条线段的终点
    /// - Returns: true = 相交，false = 不相交
    private func segmentsIntersect(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
                                    p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D) -> Bool {
        /// CCW 辅助函数：判断三点是否逆时针排列
        /// - Parameters:
        ///   - A: 第一个点
        ///   - B: 第二个点
        ///   - C: 第三个点
        /// - Returns: true = 逆时针，false = 顺时针或共线
        func ccw(A: CLLocationCoordinate2D, B: CLLocationCoordinate2D, C: CLLocationCoordinate2D) -> Bool {
            // ⚠️ 坐标映射：longitude = X轴，latitude = Y轴
            let crossProduct = (C.latitude - A.latitude) * (B.longitude - A.longitude) -
                               (B.latitude - A.latitude) * (C.longitude - A.longitude)
            return crossProduct > 0
        }

        // 两条线段相交的充要条件：
        // ccw(p1, p3, p4) ≠ ccw(p2, p3, p4) 且 ccw(p1, p2, p3) ≠ ccw(p1, p2, p4)
        return ccw(A: p1, B: p3, C: p4) != ccw(A: p2, B: p3, C: p4) &&
               ccw(A: p1, B: p2, C: p3) != ccw(A: p1, B: p2, C: p4)
    }

    /// 检测整条路径是否自相交（防止"8"字形轨迹）
    /// - Returns: true = 有自交，false = 无自交
    func hasPathSelfIntersection() -> Bool {
        // ✅ 防御性检查：至少需要4个点才可能自交
        guard pathCoordinates.count >= 4 else { return false }

        // ✅ 创建路径快照的深拷贝，避免并发修改问题
        let pathSnapshot = Array(pathCoordinates)

        // ✅ 再次检查快照是否有效
        guard pathSnapshot.count >= 4 else { return false }

        let segmentCount = pathSnapshot.count - 1

        // ✅ 防御性检查：确保有足够的线段
        guard segmentCount >= 2 else { return false }

        // ✅ 闭环时需要跳过的首尾线段数量（防止正常圈地被误判）
        let skipHeadCount = 2
        let skipTailCount = 2

        // 遍历所有线段对
        for i in 0..<segmentCount {
            guard i < pathSnapshot.count - 1 else { break }

            let p1 = pathSnapshot[i]
            let p2 = pathSnapshot[i + 1]

            let startJ = i + 2
            guard startJ < segmentCount else { continue }

            for j in startJ..<segmentCount {
                guard j < pathSnapshot.count - 1 else { break }

                // ✅ 跳过首尾附近线段的比较
                let isHeadSegment = i < skipHeadCount
                let isTailSegment = j >= segmentCount - skipTailCount

                if isHeadSegment && isTailSegment {
                    continue
                }

                let p3 = pathSnapshot[j]
                let p4 = pathSnapshot[j + 1]

                // 检测线段相交
                if segmentsIntersect(p1: p1, p2: p2, p3: p3, p4: p4) {
                    TerritoryLogger.shared.log("自交检测: 线段\(i)-\(i+1) 与 线段\(j)-\(j+1) 相交", type: .error)
                    return true
                }
            }
        }

        TerritoryLogger.shared.log("自交检测: 无交叉 ✓", type: .info)
        return false
    }

    // MARK: - 综合验证

    /// 综合验证领地是否符合规则
    /// - Returns: (isValid: 是否通过验证, errorMessage: 错误信息)
    func validateTerritory() -> (isValid: Bool, errorMessage: String?) {
        TerritoryLogger.shared.log("开始领地验证", type: .info)

        // 1. 点数检查
        if pathCoordinates.count < minimumPathPoints {
            let errorMsg = "点数不足: \(pathCoordinates.count)个点 (需≥\(minimumPathPoints)个点)"
            TerritoryLogger.shared.log("点数检查: \(errorMsg)", type: .error)
            TerritoryLogger.shared.log("领地验证失败", type: .error)

            // 更新状态
            territoryValidationPassed = false
            territoryValidationError = errorMsg
            calculatedArea = 0

            return (false, errorMsg)
        }
        TerritoryLogger.shared.log("点数检查: \(pathCoordinates.count)个点 ✓", type: .info)

        // 2. 距离检查
        let totalDistance = calculateTotalPathDistance()
        if totalDistance < minimumTotalDistance {
            let errorMsg = "距离不足: \(String(format: "%.0f", totalDistance))m (需≥\(String(format: "%.0f", minimumTotalDistance))m)"
            TerritoryLogger.shared.log("距离检查: \(errorMsg)", type: .error)
            TerritoryLogger.shared.log("领地验证失败", type: .error)

            // 更新状态
            territoryValidationPassed = false
            territoryValidationError = errorMsg
            calculatedArea = 0

            return (false, errorMsg)
        }
        TerritoryLogger.shared.log("距离检查: \(String(format: "%.0f", totalDistance))m ✓", type: .info)

        // 3. 自交检测
        if hasPathSelfIntersection() {
            let errorMsg = "轨迹自相交，请勿画8字形"
            TerritoryLogger.shared.log("领地验证失败", type: .error)

            // 更新状态
            territoryValidationPassed = false
            territoryValidationError = errorMsg
            calculatedArea = 0

            return (false, errorMsg)
        }

        // 4. 面积检查
        let area = calculatePolygonArea()
        if area < minimumEnclosedArea {
            let errorMsg = "面积不足: \(String(format: "%.0f", area))m² (需≥\(String(format: "%.0f", minimumEnclosedArea))m²)"
            TerritoryLogger.shared.log("面积检查: \(errorMsg)", type: .error)
            TerritoryLogger.shared.log("领地验证失败", type: .error)

            // 更新状态
            territoryValidationPassed = false
            territoryValidationError = errorMsg
            calculatedArea = area

            return (false, errorMsg)
        }
        TerritoryLogger.shared.log("面积检查: \(String(format: "%.0f", area))m² ✓", type: .info)

        // ✅ 所有验证通过
        TerritoryLogger.shared.log("领地验证通过！面积: \(String(format: "%.0f", area))m²", type: .success)

        // 更新状态
        territoryValidationPassed = true
        territoryValidationError = nil
        calculatedArea = area

        return (true, nil)
    }

    // MARK: - 计算属性

    /// 是否已授权定位
    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    /// 是否被拒绝定位
    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    // MARK: - Day22: POI 地理围栏方法

    /// POI 围栏半径（米）
    private let poiGeofenceRadius: Double = 50.0

    /// 开始监控 POI 地理围栏
    /// - Parameter pois: 要监控的 POI 列表
    func startMonitoringPOIs(_ pois: [POI]) {
        // 先停止所有现有监控
        stopMonitoringAllPOIs()

        LogManager.shared.info("[LocationManager] 开始监控 \(pois.count) 个 POI 围栏")

        for poi in pois {
            // 创建圆形围栏区域
            let region = CLCircularRegion(
                center: poi.coordinate,
                radius: poiGeofenceRadius,
                identifier: poi.id
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false  // 只监控进入

            // 保存 POI 映射关系
            monitoredPOIs[poi.id] = poi

            // 开始监控
            locationManager.startMonitoring(for: region)

            LogManager.shared.info("[LocationManager] 围栏已创建: \(poi.category.emoji) \(poi.name)")
        }

        LogManager.shared.success("[LocationManager] POI 围栏监控已启动")
    }

    /// 停止监控所有 POI 地理围栏
    func stopMonitoringAllPOIs() {
        // 停止所有正在监控的区域
        for region in locationManager.monitoredRegions {
            if monitoredPOIs[region.identifier] != nil {
                locationManager.stopMonitoring(for: region)
            }
        }

        // 清空映射
        monitoredPOIs.removeAll()
        enteredPOI = nil

        LogManager.shared.info("[LocationManager] 所有 POI 围栏监控已停止")
    }

    /// 停止监控单个 POI
    /// - Parameter poiId: POI ID
    func stopMonitoringPOI(_ poiId: String) {
        for region in locationManager.monitoredRegions {
            if region.identifier == poiId {
                locationManager.stopMonitoring(for: region)
                monitoredPOIs.removeValue(forKey: poiId)
                LogManager.shared.info("[LocationManager] 已停止监控 POI: \(poiId)")
                break
            }
        }
    }

    /// 清除当前进入的 POI 状态
    func clearEnteredPOI() {
        enteredPOI = nil
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    /// 授权状态改变时调用
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        // 如果已授权，开始定位
        if isAuthorized {
            startUpdatingLocation()
            locationError = nil
        } else if isDenied {
            locationError = "定位权限被拒绝，无法获取您的位置"
        }
    }

    /// 成功获取位置时调用
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // ⚠️ 关键：更新当前位置（Timer 需要用这个）
        self.currentLocation = location

        // 更新用户位置
        DispatchQueue.main.async {
            self.userLocation = location.coordinate
            self.locationError = nil
        }

        // Day23: 触发位置上报检查（移动50米触发）
        Task { @MainActor in
            await PlayerDensityManager.shared.checkAndReportIfNeeded(location)
        }
    }

    /// 定位失败时调用
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = "定位失败：\(error.localizedDescription)"
        }
        LogManager.shared.error("定位失败：\(error.localizedDescription)")
    }

    // MARK: - Day22: 地理围栏代理方法

    /// 进入地理围栏区域时调用
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }

        // 查找对应的 POI
        if let poi = monitoredPOIs[circularRegion.identifier] {
            LogManager.shared.info("[LocationManager] 进入 POI 围栏: \(poi.category.emoji) \(poi.name)")

            // 更新状态，触发弹窗
            DispatchQueue.main.async {
                self.enteredPOI = poi
            }
        }
    }

    /// 离开地理围栏区域时调用（当前不使用）
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        // 暂不处理离开事件
    }

    /// 地理围栏监控失败时调用
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        if let region = region {
            LogManager.shared.error("[LocationManager] 围栏监控失败 \(region.identifier): \(error.localizedDescription)")
        } else {
            LogManager.shared.error("[LocationManager] 围栏监控失败: \(error.localizedDescription)")
        }
    }
}
