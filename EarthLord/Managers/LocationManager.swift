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

    // MARK: - 私有属性

    /// CoreLocation 定位管理器
    private let locationManager = CLLocationManager()

    // MARK: - 初始化

    override init() {
        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest  // 最高精度
        locationManager.distanceFilter = 10  // 移动 10 米才更新一次

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
    }
}
