//
//  MapTabView.swift
//  EarthLord
//
//  地图页面 - 显示真实地图并标注用户位置
//

import SwiftUI
import MapKit

struct MapTabView: View {
    // MARK: - 状态管理

    @StateObject private var locationManager = LocationManager()
    @ObservedObject private var languageManager = LanguageManager.shared

    @State private var userLocation: CLLocationCoordinate2D?  // 用户位置
    @State private var hasLocatedUser = false  // 是否已完成首次定位

    // MARK: - 视图主体

    var body: some View {
        ZStack {
            // 背景：真实地图
            if locationManager.isAuthorized {
                MapViewRepresentable(
                    userLocation: $userLocation,
                    hasLocatedUser: $hasLocatedUser,
                    trackingPath: $locationManager.pathCoordinates,
                    pathUpdateVersion: locationManager.pathUpdateVersion,
                    isTracking: locationManager.isTracking
                )
                .edgesIgnoringSafeArea(.all)
            } else {
                // 未授权时显示占位背景
                ApocalypseTheme.background
                    .edgesIgnoringSafeArea(.all)
            }

            // 前景：UI 元素
            VStack(spacing: 0) {
                // 顶部标题栏
                headerView
                    .padding(.top, 50)
                    .padding(.horizontal, 20)

                Spacer()

                // 底部：权限提示卡片（仅在被拒绝时显示）
                if locationManager.isDenied {
                    permissionDeniedCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                }
            }

            // 右下角：按钮组（圈地按钮 + 定位按钮）
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 16) {
                        // 圈地按钮
                        territoryButton

                        // 定位按钮
                        locationButton
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        .onAppear {
            // 页面出现时，检查权限并请求
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestPermission()
            } else if locationManager.isAuthorized {
                locationManager.startUpdatingLocation()
            }
        }
        .refreshOnLanguageChange()
    }

    // MARK: - 子视图组件

    /// 顶部标题栏
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("🗺️ 末日地图")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if let location = userLocation {
                    // 显示当前坐标
                    Text("📍 \(formatCoordinate(location))")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                } else {
                    Text("正在获取位置...")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            ApocalypseTheme.cardBackground.opacity(0.9)
                .cornerRadius(12)
        )
    }

    /// 权限被拒绝时的提示卡片
    private var permissionDeniedCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 40))
                .foregroundColor(ApocalypseTheme.warning)

            Text("无法获取位置")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("《地球新主》需要定位权限来显示您在末日世界中的坐标")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            // 前往设置按钮
            Button {
                openSettings()
            } label: {
                Text("前往设置")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(8)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(
            ApocalypseTheme.cardBackground
                .cornerRadius(16)
        )
    }

    /// 圈地按钮
    private var territoryButton: some View {
        Button {
            // 切换追踪状态
            if locationManager.isTracking {
                locationManager.stopPathTracking()
            } else {
                locationManager.startPathTracking()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: locationManager.isTracking ? "stop.fill" : "flag.fill")
                    .font(.system(size: 16, weight: .semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text(locationManager.isTracking ? "停止圈地" : "开始圈地")
                        .font(.system(size: 14, weight: .bold))

                    if locationManager.isTracking && locationManager.pathCoordinates.count > 0 {
                        Text("\(locationManager.pathCoordinates.count) 个点")
                            .font(.system(size: 11))
                            .opacity(0.9)
                    }
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                locationManager.isTracking
                    ? Color.red
                    : ApocalypseTheme.primary
            )
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    /// 右下角定位按钮
    private var locationButton: some View {
        Button {
            // 重新居中到用户位置
            if let location = userLocation {
                hasLocatedUser = false  // 重置标志，允许重新居中
            } else {
                locationManager.startUpdatingLocation()
            }
        } label: {
            Image(systemName: hasLocatedUser ? "location.fill" : "location")
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(ApocalypseTheme.primary)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - 辅助方法

    /// 格式化坐标为易读文本
    private func formatCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        let lat = String(format: "%.4f", coordinate.latitude)
        let lon = String(format: "%.4f", coordinate.longitude)
        return "\(lat), \(lon)"
    }

    /// 打开系统设置
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - 预览

#Preview {
    MapTabView()
}
