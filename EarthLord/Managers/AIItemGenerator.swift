//
//  AIItemGenerator.swift
//  EarthLord
//
//  AI 物品生成器 - 调用 Edge Function 生成独特物品
//

import Foundation
import Combine
import Supabase

/// AI 物品生成器
@MainActor
class AIItemGenerator: ObservableObject {
    // MARK: - 单例
    static let shared = AIItemGenerator()

    // MARK: - Published 属性
    @Published var isGenerating: Bool = false
    @Published var lastError: String?

    // MARK: - 私有属性
    private let supabase = SupabaseConfig.shared
    private let edgeFunctionName = "generate-ai-item"

    // MARK: - 配置
    private let requestTimeout: TimeInterval = 15.0
    private let maxRetries: Int = 2

    // MARK: - 初始化
    private init() {
        LogManager.shared.info("[AIItemGenerator] 初始化完成")
    }

    // MARK: - 公开方法

    /// 为 POI 生成 AI 物品
    /// - Parameters:
    ///   - poi: 目标 POI
    ///   - itemCount: 生成物品数量（默认 1-3 随机）
    /// - Returns: 生成的物品列表
    func generateItems(for poi: POI, itemCount: Int? = nil) async throws -> [AIGeneratedItem] {
        isGenerating = true
        lastError = nil

        defer { isGenerating = false }

        let count = itemCount ?? Int.random(in: 1...3)

        LogManager.shared.info("""
        [AIItemGenerator] 开始生成物品
        - POI: \(poi.name)
        - 类型: \(poi.category.rawValue)
        - 危险等级: \(poi.dangerLevel)
        - 物品数量: \(count)
        """)

        // 构建请求
        let request = AIGenerateRequest(
            poiName: poi.name,
            poiCategory: poi.category.rawValue,
            dangerLevel: poi.dangerLevel,
            itemCount: count
        )

        // 带重试的请求
        var lastError: Error?
        for attempt in 1...maxRetries {
            do {
                let items = try await performRequest(request)
                LogManager.shared.success("[AIItemGenerator] 物品生成成功，数量: \(items.count)")
                return items
            } catch {
                lastError = error
                LogManager.shared.warning("[AIItemGenerator] 尝试 \(attempt)/\(maxRetries) 失败: \(error.localizedDescription)")

                if attempt < maxRetries {
                    // 等待后重试
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
                }
            }
        }

        // 所有重试失败，使用降级方案
        LogManager.shared.warning("[AIItemGenerator] AI 生成失败，使用降级方案")
        self.lastError = lastError?.localizedDescription
        return generateFallbackItems(for: poi, count: count)
    }

    // MARK: - 私有方法

    /// 执行 Edge Function 请求
    private func performRequest(_ request: AIGenerateRequest) async throws -> [AIGeneratedItem] {
        // 使用 Supabase SDK 调用 Edge Function
        let response: AIGenerateResponse = try await supabase.functions
            .invoke(
                edgeFunctionName,
                options: FunctionInvokeOptions(body: request)
            )

        if let error = response.error {
            throw AIGeneratorError.serverError(error)
        }

        guard !response.items.isEmpty else {
            throw AIGeneratorError.emptyResponse
        }

        return response.items
    }

    /// 降级：生成默认物品
    func generateFallbackItems(for poi: POI, count: Int) -> [AIGeneratedItem] {
        let rarities = generateRarities(for: poi.dangerLevel, count: count)

        let categoryItems: [(name: String, category: String, story: String)] = {
            switch poi.category {
            case .supermarket, .convenience, .store:
                return [
                    ("罐头食品", "食物", "在\(poi.name)的货架深处找到的罐头。"),
                    ("瓶装水", "水源", "收银台下的矿泉水，还算干净。"),
                    ("废弃杂物", "材料", "可以拆解利用的包装材料。")
                ]
            case .hospital, .pharmacy:
                return [
                    ("医疗绷带", "医疗", "急诊室抽屉里的医疗用品。"),
                    ("止痛药", "医疗", "药房残留的基础药物。"),
                    ("急救包", "医疗", "还算完整的急救套装。")
                ]
            case .restaurant, .cafe:
                return [
                    ("剩余食材", "食物", "厨房里还能用的食材。"),
                    ("瓶装饮料", "水源", "冰柜里已经不冰的饮料。"),
                    ("餐具", "工具", "还算干净的餐具。")
                ]
            case .gasStation:
                return [
                    ("工具零件", "工具", "维修区遗留的工具。"),
                    ("便利店食品", "食物", "便利店货架上的零食。"),
                    ("金属废料", "材料", "可以回收利用的金属部件。")
                ]
            }
        }()

        var items: [AIGeneratedItem] = []
        for i in 0..<count {
            let itemInfo = categoryItems[i % categoryItems.count]
            let rarity = rarities[i]
            items.append(AIGeneratedItem(
                uniqueName: itemInfo.0,
                baseCategory: itemInfo.1,
                rarity: rarity,
                backstory: itemInfo.2,
                quantity: Int.random(in: 1...3)
            ))
        }

        return items
    }

    /// 根据危险值生成稀有度列表
    private func generateRarities(for dangerLevel: Int, count: Int) -> [String] {
        let distribution: [(String, Double)] = {
            switch dangerLevel {
            case 1, 2:
                return [("普通", 0.70), ("罕见", 0.25), ("稀有", 0.05)]
            case 3:
                return [("普通", 0.50), ("罕见", 0.30), ("稀有", 0.15), ("史诗", 0.05)]
            case 4:
                return [("罕见", 0.40), ("稀有", 0.35), ("史诗", 0.20), ("传说", 0.05)]
            case 5:
                return [("稀有", 0.30), ("史诗", 0.40), ("传说", 0.30)]
            default:
                return [("普通", 0.70), ("罕见", 0.25), ("稀有", 0.05)]
            }
        }()

        return (0..<count).map { _ in
            let rand = Double.random(in: 0...1)
            var cumulative: Double = 0
            for (rarity, prob) in distribution {
                cumulative += prob
                if rand <= cumulative {
                    return rarity
                }
            }
            return "普通"
        }
    }
}

// MARK: - 错误定义

enum AIGeneratorError: LocalizedError {
    case invalidURL
    case httpError(Int)
    case serverError(String)
    case parseError
    case timeout
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的服务器地址"
        case .httpError(let code):
            return "服务器错误: \(code)"
        case .serverError(let message):
            return "AI 服务错误: \(message)"
        case .parseError:
            return "响应解析失败"
        case .timeout:
            return "请求超时"
        case .emptyResponse:
            return "服务器返回空响应"
        }
    }
}
