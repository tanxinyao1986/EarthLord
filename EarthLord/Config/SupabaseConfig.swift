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

    /// Supabase 匿名公钥（Anon Key）
    /// 注意：这是公开的匿名密钥，可以安全地包含在客户端代码中
    private static let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR6Znlsc3l2bnNrenZwd29tY2ltIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUyNjc1NTksImV4cCI6MjA4MDg0MzU1OX0.YpVO-Vi-vtQtpkGm8ChaKsICCqBDGji168CA0O-cZE4"

    // MARK: - 全局 Supabase 客户端

    /// 全局共享的 Supabase 客户端实例
    /// 用于整个应用中的数据库操作和认证
    /// SupabaseClient 已经是 Sendable 类型，可以安全地跨 actor 使用
    /// 使用 nonisolated(unsafe) 以允许从 nonisolated 上下文访问
    nonisolated(unsafe) static let shared: SupabaseClient = {
        guard let url = URL(string: supabaseURL) else {
            fatalError("Invalid Supabase URL")
        }

        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: supabaseKey
        )
    }()
}
