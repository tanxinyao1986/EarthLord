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
    @ObservedObject private var authManager = AuthManager.shared
    private let territoryManager = TerritoryManager.shared

    @State private var userLocation: CLLocationCoordinate2D?  // 用户位置
    @State private var hasLocatedUser = false  // 是否已完成首次定位
    @State private var showValidationBanner: Bool = false  // 是否显示验证结果横幅

    // 上传相关状态
    @State private var isUploading: Bool = false
    @State private var uploadError: String?
    @State private var uploadSuccess: Bool = false
    @State private var showUploadAlert: Bool = false

    // 领地相关状态
    @State private var territories: [Territory] = []

    // MARK: - Day 19: 碰撞检测状态
    @State private var collisionCheckTimer: Timer?
    @State private var collisionWarning: String?
    @State private var showCollisionWarning = false
    @State private var collisionWarningLevel: WarningLevel = .safe
    @State private var trackingStartTime: Date?

    // 当前用户 ID
    private var currentUserId: String? {
        authManager.currentUser?.id.uuidString
    }

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
                    isTracking: locationManager.isTracking,
                    isPathClosed: locationManager.isPathClosed,
                    territories: territories,
                    currentUserId: authManager.currentUser?.id.uuidString
                )
                .edgesIgnoringSafeArea(.all)
            } else {
                // 未授权时显示占位背景
                ApocalypseTheme.background
                    .edgesIgnoringSafeArea(.all)
            }

            // 前景：UI 元素
            VStack(spacing: 12) {
                // 顶部标题栏
                headerView
                    .padding(.top, 50)
                    .padding(.horizontal, 20)

                // 速度警告横幅
                if locationManager.speedWarning != nil {
                    speedWarningBanner
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // 验证结果横幅（根据验证结果显示成功或失败）
                if showValidationBanner {
                    validationResultBanner
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                // 底部：权限提示卡片（仅在被拒绝时显示）
                if locationManager.isDenied {
                    permissionDeniedCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                }
            }

            // Day 19: 碰撞警告横幅（分级颜色）
            if showCollisionWarning, let warning = collisionWarning {
                collisionWarningBanner(message: warning, level: collisionWarningLevel)
            }

            // 右下角：按钮组（确认登记按钮 + 圈地按钮 + 定位按钮）
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 16) {
                        // 确认登记按钮（仅在验证通过时显示）
                        if locationManager.territoryValidationPassed {
                            confirmTerritoryButton
                        }

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
        .alert(isPresented: $showUploadAlert) {
            if uploadSuccess {
                Alert(
                    title: Text("领地登记成功"),
                    message: Text("您的领地已成功登记！"),
                    dismissButton: .default(Text("确定")) {
                        uploadSuccess = false
                    }
                )
            } else if let error = uploadError {
                Alert(
                    title: Text("上传失败"),
                    message: Text(error),
                    dismissButton: .default(Text("确定")) {
                        uploadError = nil
                    }
                )
            } else {
                Alert(title: Text("提示"))
            }
        }
        .onAppear {
            // 页面出现时，检查权限并请求
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestPermission()
            } else if locationManager.isAuthorized {
                locationManager.startUpdatingLocation()
            }

            // 加载所有领地
            Task {
                await loadTerritories()
            }
        }
        .onReceive(locationManager.$isPathClosed) { isClosed in
            // 监听闭环状态，闭环后根据验证结果显示横幅
            if isClosed {
                // 闭环后延迟一点点，等待验证结果
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        showValidationBanner = true
                    }
                    // 3 秒后自动隐藏
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showValidationBanner = false
                        }
                    }
                }
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
                // Day 19: 停止追踪时完全停止碰撞监控
                stopCollisionMonitoring()
                locationManager.stopPathTracking()
            } else {
                // Day 19: 开始圈地前检测起始点
                startClaimingWithCollisionCheck()
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
            if userLocation != nil {
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

    /// 速度警告横幅
    private var speedWarningBanner: some View {
        HStack(spacing: 12) {
            // 警告图标
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)

            // 警告文字
            Text(locationManager.speedWarning ?? "")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            // 根据是否还在追踪显示不同颜色
            locationManager.isTracking
                ? Color.orange  // 黄色：警告但还在追踪
                : Color.red     // 红色：已暂停追踪
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .onAppear {
            // 3 秒后自动消失
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    locationManager.speedWarning = nil
                }
            }
        }
    }

    /// 验证结果横幅（根据验证结果显示成功或失败）
    private var validationResultBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: locationManager.territoryValidationPassed
                  ? "checkmark.circle.fill"
                  : "xmark.circle.fill")
                .font(.body)
            if locationManager.territoryValidationPassed {
                Text("圈地成功！领地面积: \(String(format: "%.0f", locationManager.calculatedArea))m²")
                    .font(.subheadline)
                    .fontWeight(.medium)
            } else {
                Text(locationManager.territoryValidationError ?? "验证失败")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(locationManager.territoryValidationPassed ? Color.green : Color.red)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
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

    // MARK: - 确认登记按钮

    /// 确认登记领地按钮
    private var confirmTerritoryButton: some View {
        Button {
            Task {
                await uploadCurrentTerritory()
            }
        } label: {
            HStack(spacing: 8) {
                if isUploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(isUploading ? "上传中..." : "确认登记领地")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.green)
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(isUploading)
    }

    // MARK: - 上传方法

    /// 上传当前领地
    private func uploadCurrentTerritory() async {
        // ⚠️ 再次检查验证状态
        guard locationManager.territoryValidationPassed else {
            uploadError = "领地验证未通过，无法上传"
            showUploadAlert = true
            return
        }

        // 检查是否有足够的坐标点
        guard !locationManager.pathCoordinates.isEmpty else {
            uploadError = "没有记录的路径数据"
            showUploadAlert = true
            return
        }

        // 开始上传
        isUploading = true

        do {
            // 上传领地
            try await territoryManager.uploadTerritory(
                coordinates: locationManager.pathCoordinates,
                area: locationManager.calculatedArea,
                startTime: Date()  // TODO: 使用实际的开始时间
            )

            // 上传成功
            uploadSuccess = true
            showUploadAlert = true

            // ⚠️ 关键：上传成功后必须停止追踪！
            stopCollisionMonitoring()  // Day 19: 停止碰撞监控
            locationManager.stopPathTracking()

            LogManager.shared.success("领地登记成功！面积: \(Int(locationManager.calculatedArea))m²")

            // 刷新领地列表
            await loadTerritories()

        } catch {
            // 上传失败
            uploadError = error.localizedDescription
            showUploadAlert = true

            LogManager.shared.error("领地上传失败: \(error.localizedDescription)")
        }

        isUploading = false
    }

    // MARK: - 领地加载方法

    /// 从云端加载所有领地
    private func loadTerritories() async {
        do {
            territories = try await territoryManager.loadAllTerritories()
            TerritoryLogger.shared.log("加载了 \(territories.count) 个领地", type: .info)
            LogManager.shared.info("加载了 \(territories.count) 个领地")
        } catch {
            TerritoryLogger.shared.log("加载领地失败: \(error.localizedDescription)", type: .error)
            LogManager.shared.error("加载领地失败: \(error.localizedDescription)")
        }
    }

    // MARK: - Day 19: 碰撞检测方法

    /// Day 19: 带碰撞检测的开始圈地
    private func startClaimingWithCollisionCheck() {
        guard let location = locationManager.userLocation,
              let userId = currentUserId else {
            return
        }

        // 检测起始点是否在他人领地内
        let result = territoryManager.checkPointCollision(
            location: location,
            currentUserId: userId
        )

        if result.hasCollision {
            // 起点在他人领地内，显示错误并震动
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)

            TerritoryLogger.shared.log("起点碰撞：阻止圈地", type: .error)

            // 3秒后隐藏警告
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }

            return
        }

        // 起点安全，开始圈地
        TerritoryLogger.shared.log("起始点安全，开始圈地", type: .info)
        trackingStartTime = Date()
        locationManager.startPathTracking()
        startCollisionMonitoring()
    }

    /// Day 19: 启动碰撞检测监控
    private func startCollisionMonitoring() {
        // 先停止已有定时器
        stopCollisionCheckTimer()

        // 每 10 秒检测一次
        collisionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [self] _ in
            performCollisionCheck()
        }

        TerritoryLogger.shared.log("碰撞检测定时器已启动", type: .info)
    }

    /// Day 19: 仅停止定时器（不清除警告状态）
    private func stopCollisionCheckTimer() {
        collisionCheckTimer?.invalidate()
        collisionCheckTimer = nil
        TerritoryLogger.shared.log("碰撞检测定时器已停止", type: .info)
    }

    /// Day 19: 完全停止碰撞监控（停止定时器 + 清除警告）
    private func stopCollisionMonitoring() {
        stopCollisionCheckTimer()
        // 清除警告状态
        showCollisionWarning = false
        collisionWarning = nil
        collisionWarningLevel = .safe
    }

    /// Day 19: 执行碰撞检测
    private func performCollisionCheck() {
        guard locationManager.isTracking,
              let userId = currentUserId else {
            return
        }

        let path = locationManager.pathCoordinates
        guard path.count >= 2 else { return }

        let result = territoryManager.checkPathCollisionComprehensive(
            path: path,
            currentUserId: userId
        )

        // 根据预警级别处理
        switch result.warningLevel {
        case .safe:
            // 安全，隐藏警告横幅
            showCollisionWarning = false
            collisionWarning = nil
            collisionWarningLevel = .safe

        case .caution:
            // 注意（50-100m）- 黄色横幅 + 轻震 1 次
            collisionWarning = result.message
            collisionWarningLevel = .caution
            showCollisionWarning = true
            triggerHapticFeedback(level: .caution)

        case .warning:
            // 警告（25-50m）- 橙色横幅 + 中震 2 次
            collisionWarning = result.message
            collisionWarningLevel = .warning
            showCollisionWarning = true
            triggerHapticFeedback(level: .warning)

        case .danger:
            // 危险（<25m）- 红色横幅 + 强震 3 次
            collisionWarning = result.message
            collisionWarningLevel = .danger
            showCollisionWarning = true
            triggerHapticFeedback(level: .danger)

        case .violation:
            // 【关键修复】违规处理 - 必须先显示横幅，再停止！

            // 1. 先设置警告状态（让横幅显示出来）
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 2. 触发震动
            triggerHapticFeedback(level: .violation)

            // 3. 只停止定时器，不清除警告状态！
            stopCollisionCheckTimer()

            // 4. 停止圈地追踪
            locationManager.stopPathTracking()
            trackingStartTime = nil

            TerritoryLogger.shared.log("碰撞违规，自动停止圈地", type: .error)

            // 5. 5秒后再清除警告横幅
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }
        }
    }

    /// Day 19: 触发震动反馈
    private func triggerHapticFeedback(level: WarningLevel) {
        switch level {
        case .safe:
            // 安全：无震动
            break

        case .caution:
            // 注意：轻震 1 次
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)

        case .warning:
            // 警告：中震 2 次
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }

        case .danger:
            // 危险：强震 3 次
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                generator.impactOccurred()
            }

        case .violation:
            // 违规：错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
        }
    }

    /// Day 19: 碰撞警告横幅（分级颜色）
    private func collisionWarningBanner(message: String, level: WarningLevel) -> some View {
        // 根据级别确定颜色
        let backgroundColor: Color
        switch level {
        case .safe:
            backgroundColor = .green
        case .caution:
            backgroundColor = .yellow
        case .warning:
            backgroundColor = .orange
        case .danger, .violation:
            backgroundColor = .red
        }

        // 根据级别确定文字颜色（黄色背景用黑字）
        let textColor: Color = (level == .caution) ? .black : .white

        // 根据级别确定图标
        let iconName = (level == .violation) ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"

        return VStack {
            HStack {
                Image(systemName: iconName)
                    .font(.system(size: 18))

                Text(message)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(textColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(backgroundColor.opacity(0.95))
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .padding(.top, 120)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: showCollisionWarning)
    }
}

// MARK: - 预览

#Preview {
    MapTabView()
}
