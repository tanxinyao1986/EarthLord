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

    // MARK: - 私有属性

    /// CoreLocation 定位管理器
    private let locationManager = CLLocationManager()

    /// 当前位置（用于定时器采点）
    private var currentLocation: CLLocation?

    /// 路径追踪定时器（每 2 秒采一次点）
    private var pathUpdateTimer: Timer?


    // MARK: - 常量配置

    /// 闭环距离阈值（米）- 已调整为原来的一半，方便小空间测试
    private let closureDistanceThreshold: Double = 15.0

    /// 最少路径点数（闭环需要至少这么多点）
    private let minimumPathPoints: Int = 10

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

    /// 停止追踪路径（停止定时器）
    func stopPathTracking() {
        isTracking = false
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil

        print("⏹️ 停止路径追踪，共记录 \(pathCoordinates.count) 个点")
        LogManager.shared.info("停止追踪，共记录 \(pathCoordinates.count) 个点")
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
        }
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
    }

    /// 定位失败时调用
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = "定位失败：\(error.localizedDescription)"
        }
        LogManager.shared.error("定位失败：\(error.localizedDescription)")
    }
}
