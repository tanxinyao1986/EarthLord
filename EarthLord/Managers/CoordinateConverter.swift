//
//  CoordinateConverter.swift
//  EarthLord
//
//  坐标转换工具 - 解决中国 GPS 偏移问题（WGS-84 → GCJ-02）
//

import Foundation
import CoreLocation

// MARK: - CoordinateConverter 坐标转换器
struct CoordinateConverter {
    // MARK: - 常量定义

    /// 长半轴（地球赤道半径，米）
    private static let a: Double = 6378245.0

    /// 扁率（地球扁平程度）
    private static let ee: Double = 0.00669342162296594323

    // MARK: - 公开方法

    /// 将 WGS-84 坐标（GPS 原始坐标）转换为 GCJ-02 坐标（火星坐标）
    /// - Parameter wgs84: WGS-84 坐标（GPS 芯片返回的原始坐标）
    /// - Returns: GCJ-02 坐标（中国地图使用的加密坐标）
    static func wgs84ToGcj02(_ wgs84: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 如果不在中国境内，不需要转换
        if !isInChina(wgs84) {
            return wgs84
        }

        // 计算偏移量
        let dlat = transformLatitude(wgs84.longitude - 105.0, wgs84.latitude - 35.0)
        let dlon = transformLongitude(wgs84.longitude - 105.0, wgs84.latitude - 35.0)

        let radLat = wgs84.latitude / 180.0 * Double.pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)

        let dlatFinal = (dlat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * Double.pi)
        let dlonFinal = (dlon * 180.0) / (a / sqrtMagic * cos(radLat) * Double.pi)

        let gcj02Lat = wgs84.latitude + dlatFinal
        let gcj02Lon = wgs84.longitude + dlonFinal

        return CLLocationCoordinate2D(latitude: gcj02Lat, longitude: gcj02Lon)
    }

    /// 批量转换坐标数组（用于路径轨迹转换）
    /// - Parameter wgs84Array: WGS-84 坐标数组
    /// - Returns: GCJ-02 坐标数组
    static func wgs84ArrayToGcj02(_ wgs84Array: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        return wgs84Array.map { wgs84ToGcj02($0) }
    }

    // MARK: - 私有方法

    /// 判断坐标是否在中国境内（粗略判断）
    /// - Parameter coordinate: 待判断的坐标
    /// - Returns: 是否在中国境内
    private static func isInChina(_ coordinate: CLLocationCoordinate2D) -> Bool {
        // 中国大陆经度范围：73.66°E - 135.05°E
        // 中国大陆纬度范围：3.86°N - 53.55°N
        // 这是粗略判断，不包括港澳台等特殊地区
        return coordinate.longitude >= 73.66 &&
               coordinate.longitude <= 135.05 &&
               coordinate.latitude >= 3.86 &&
               coordinate.latitude <= 53.55
    }

    /// 纬度偏移量转换（内部算法）
    private static func transformLatitude(_ x: Double, _ y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * Double.pi) + 40.0 * sin(y / 3.0 * Double.pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * Double.pi) + 320 * sin(y * Double.pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    /// 经度偏移量转换（内部算法）
    private static func transformLongitude(_ x: Double, _ y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * Double.pi) + 40.0 * sin(x / 3.0 * Double.pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * Double.pi) + 300.0 * sin(x / 30.0 * Double.pi)) * 2.0 / 3.0
        return ret
    }
}

// MARK: - 使用示例

/*
 // 单个坐标转换
 let wgs84 = CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)  // GPS 原始坐标
 let gcj02 = CoordinateConverter.wgs84ToGcj02(wgs84)  // 转换为地图坐标
 print("转换后：\(gcj02.latitude), \(gcj02.longitude)")

 // 批量转换（用于路径轨迹）
 let pathWGS84 = [
     CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
     CLLocationCoordinate2D(latitude: 31.2305, longitude: 121.4738)
 ]
 let pathGCJ02 = CoordinateConverter.wgs84ArrayToGcj02(pathWGS84)
 */
