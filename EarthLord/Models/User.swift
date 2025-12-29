//
//  User.swift
//  EarthLord
//
//  Created by Claude Code
//

import Foundation

/// 用户模型
/// 对应 Supabase 的 auth.users 和 profiles 表
struct User: Codable, Identifiable {

    // MARK: - Properties

    /// 用户唯一标识符（来自 auth.users）
    let id: UUID

    /// 邮箱地址
    let email: String

    /// 用户名
    var username: String?

    /// 头像 URL
    var avatarUrl: String?

    /// 账号创建时间
    let createdAt: Date

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }

    // MARK: - Initializers

    /// 从 Supabase Auth User 创建 User 对象
    init(id: UUID, email: String, username: String? = nil, avatarUrl: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.email = email
        self.username = username
        self.avatarUrl = avatarUrl
        self.createdAt = createdAt
    }
}
