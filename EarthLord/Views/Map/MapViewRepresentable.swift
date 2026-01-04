//
//  MapViewRepresentable.swift
//  EarthLord
//
//  MKMapView 的 SwiftUI 包装器 - 显示末日风格地图并自动居中到用户位置
//

import SwiftUI
import MapKit

// MARK: - MapViewRepresentable 主结构
struct MapViewRepresentable: UIViewRepresentable {
    /// 用户位置（双向绑定）
    @Binding var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位（防止重复居中）
    @Binding var hasLocatedUser: Bool

    /// 路径追踪坐标数组（WGS-84 原始坐标）
    @Binding var trackingPath: [CLLocationCoordinate2D]

    /// 路径更新版本号（触发重新渲染）
    var pathUpdateVersion: Int

    /// 是否正在追踪
    var isTracking: Bool

    // MARK: - UIViewRepresentable 协议方法

    /// 创建 MKMapView
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        // 基础配置
        mapView.mapType = .hybrid  // 卫星图 + 道路标签（符合末世风格）
        mapView.pointOfInterestFilter = .excludingAll  // 隐藏所有 POI（星巴克、餐厅等）
        mapView.showsBuildings = false  // 隐藏 3D 建筑
        mapView.showsUserLocation = true  // ⚠️ 关键：显示用户位置蓝点，触发定位
        mapView.isZoomEnabled = true  // 允许双指缩放
        mapView.isScrollEnabled = true  // 允许拖动
        mapView.isRotateEnabled = true  // 允许旋转
        mapView.isPitchEnabled = false  // 禁用倾斜（保持俯视）

        // ⚠️ 关键：设置代理，否则 didUpdate userLocation 不会被调用
        mapView.delegate = context.coordinator

        // 应用末世滤镜效果
        applyApocalypseFilter(to: mapView)

        return mapView
    }

    /// 更新 MKMapView（当路径更新时调用）
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 当路径更新版本号变化时，重新渲染轨迹
        context.coordinator.updateTrackingPath(on: uiView, path: trackingPath)
    }

    /// 创建 Coordinator（代理处理器）
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - 末世滤镜效果

    /// 应用末世滤镜：降低饱和度 + 棕褐色调（废土泛黄效果）
    private func applyApocalypseFilter(to mapView: MKMapView) {
        // 色调控制：降低饱和度和亮度
        let colorControls = CIFilter(name: "CIColorControls")
        colorControls?.setValue(-0.15, forKey: kCIInputBrightnessKey)  // 稍微变暗
        colorControls?.setValue(0.5, forKey: kCIInputSaturationKey)    // 降低饱和度

        // 棕褐色调：废土的泛黄效果
        let sepiaFilter = CIFilter(name: "CISepiaTone")
        sepiaFilter?.setValue(0.65, forKey: kCIInputIntensityKey)  // 泛黄强度

        // 应用到地图图层
        mapView.layer.filters = [colorControls!, sepiaFilter!]
    }

    // MARK: - Coordinator（地图代理）

    /// ⭐ 关键类：负责处理地图回调，实现自动居中功能
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        private var hasInitialCentered = false  // 防止重复居中（用户拖动后不会被拉回）

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        // MARK: - MKMapViewDelegate 方法

        /// ⭐⭐⭐ 关键方法：用户位置更新时调用（这是自动居中的核心！）
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // 获取位置坐标
            guard let location = userLocation.location else { return }

            // 更新绑定的位置（传递给外部）
            DispatchQueue.main.async {
                self.parent.userLocation = location.coordinate
            }

            // 如果已经居中过，不再自动居中（避免干扰用户拖动）
            guard !hasInitialCentered else { return }

            // 创建居中区域（约 1 公里范围）
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 1000,  // 纬度范围（米）
                longitudinalMeters: 1000  // 经度范围（米）
            )

            // ⭐ 平滑居中地图（animated: true 实现平滑过渡）
            mapView.setRegion(region, animated: true)

            // 标记已完成首次居中
            hasInitialCentered = true

            // 更新外部状态
            DispatchQueue.main.async {
                self.parent.hasLocatedUser = true
            }

            print("✅ 地图已自动居中到用户位置：\(location.coordinate.latitude), \(location.coordinate.longitude)")
        }

        /// 地图区域改变时调用（可用于调试）
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 可以在这里记录地图中心点变化
        }

        /// 地图加载完成时调用
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            print("✅ 地图加载完成")
        }

        // MARK: - 轨迹渲染方法

        /// 更新地图上的追踪轨迹
        func updateTrackingPath(on mapView: MKMapView, path: [CLLocationCoordinate2D]) {
            // 移除旧的轨迹线
            let oldOverlays = mapView.overlays
            mapView.removeOverlays(oldOverlays)

            // 如果路径为空或只有一个点，不绘制
            guard path.count >= 2 else { return }

            // ⚠️ 关键：将 WGS-84 坐标转换为 GCJ-02 坐标
            let gcj02Path = CoordinateConverter.wgs84ArrayToGcj02(path)

            // 创建轨迹线（MKPolyline）
            let polyline = MKPolyline(coordinates: gcj02Path, count: gcj02Path.count)

            // 添加到地图
            mapView.addOverlay(polyline)

            print("🎨 绘制轨迹线，共 \(path.count) 个点")
        }

        /// ⭐⭐⭐ 关键方法：为轨迹线提供渲染器（否则轨迹不显示！）
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.cyan  // 青色轨迹（末日科技感）
                renderer.lineWidth = 5  // 线宽
                renderer.lineCap = .round  // 圆头
                return renderer
            }

            // 默认渲染器
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
