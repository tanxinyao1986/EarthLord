//
//  SupabaseConfig.swift
//  EarthLord
//
//  Created by Claude Code
//

import Foundation
import Supabase

/// Supabase 客户端配置
/// 提供全局的 Supabase 客户端实例
struct SupabaseConfig {

    // MARK: - Supabase 配置信息

    /// Supabase 项目 URL
    private static let supabaseURL = "https://dzfylsyvnskzvpwomcim.supabase.co"

    /// Supabase 匿名公钥（Publishable Key）
    /// 注意：这是公开的匿名密钥，可以安全地包含在客户端代码中
    private static let supabaseKey = "sb_publishable_KJcs3naUpYADIqbnpMeAeQ_tycx9k8o"

    // MARK: - 全局 Supabase 客户端

    /// 全局共享的 Supabase 客户端实例
    /// 用于整个应用中的数据库操作和认证
    static let shared: SupabaseClient = {
        guard let url = URL(string: supabaseURL) else {
            fatalError("Invalid Supabase URL")
        }

        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: supabaseKey
        )
    }()
}
