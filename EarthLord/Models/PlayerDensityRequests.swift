//
//  PlayerDensityRequests.swift
//  EarthLord
//
//  Created by Claude on 2026-01-14.
//  附近玩家检测请求参数
//

import Foundation

// MARK: - 位置上报请求

struct LocationReportRequest: Encodable, Sendable {
    let p_user_id: String
    let p_latitude: Double
    let p_longitude: Double
    let p_accuracy: Double?
    let p_is_online: Bool
}

// MARK: - 附近玩家查询请求

struct NearbyPlayersRequest: Encodable, Sendable {
    let p_user_id: String
    let p_latitude: Double
    let p_longitude: Double
    let p_radius_meters: Double
}
