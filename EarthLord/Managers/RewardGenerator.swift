//
//  RewardGenerator.swift
//  EarthLord
//
//  奖励生成器 - 根据行走距离生成随机奖励物品
//

import Foundation

/// 奖励生成器
class RewardGenerator {
    // MARK: - 单例
    static let shared = RewardGenerator()

    private init() {}

    // MARK: - 公开方法

    /// 根据行走距离生成奖励
    /// - Parameters:
    ///   - distance: 行走距离（米）
    ///   - itemDefinitions: 可用的物品定义列表
    /// - Returns: 生成的奖励结果
    func generateRewards(distance: Double, itemDefinitions: [ItemDefinition]) -> GeneratedRewards {
        // 1. 计算奖励等级
        let tier = RewardTier.fromDistance(distance)

        // 2. 如果无奖励，直接返回空结果
        guard tier != .none else {
            return GeneratedRewards(tier: .none, items: [:], experience: 0)
        }

        // 3. 获取该等级的物品数量
        let itemCount = tier.itemCount

        // 4. 生成随机物品
        var selectedItems: [String: Int] = [:]

        for _ in 0..<itemCount {
            // 随机选择稀有度
            let rarity = selectRarity(probabilities: tier.rarityProbabilities)

            // 根据稀有度筛选物品
            let eligibleItems = itemDefinitions.filter { $0.rarity == rarity }

            // 随机选择一个物品
            if let randomItem = eligibleItems.randomElement() {
                selectedItems[randomItem.id, default: 0] += 1
            } else {
                // 如果该稀有度没有物品，降级到普通物品
                let commonItems = itemDefinitions.filter { $0.rarity == .common }
                if let fallbackItem = commonItems.randomElement() {
                    selectedItems[fallbackItem.id, default: 0] += 1
                }
            }
        }

        // 5. 计算经验值
        // 基础经验 = 距离 / 10，然后乘以等级系数
        let baseExperience = Int(distance / 10.0)
        let experience = Int(Double(baseExperience) * tier.experienceMultiplier)

        return GeneratedRewards(tier: tier, items: selectedItems, experience: experience)
    }

    /// 计算奖励等级
    /// - Parameter distance: 行走距离（米）
    /// - Returns: 奖励等级
    func calculateRewardTier(distance: Double) -> RewardTier {
        return RewardTier.fromDistance(distance)
    }

    // MARK: - 私有方法

    /// 根据概率分布随机选择稀有度
    /// - Parameter probabilities: 各稀有度的概率
    /// - Returns: 选中的稀有度
    private func selectRarity(probabilities: [ItemRarity: Double]) -> ItemRarity {
        let random = Double.random(in: 0...1)
        var cumulative: Double = 0

        // 按概率从高到低排序，确保结果稳定
        let sortedProbabilities = probabilities.sorted { $0.value > $1.value }

        for (rarity, probability) in sortedProbabilities {
            cumulative += probability
            if random <= cumulative {
                return rarity
            }
        }

        // 默认返回普通稀有度
        return .common
    }
}

// MARK: - 测试辅助

extension RewardGenerator {
    /// 生成测试奖励（使用 MockExplorationData 中的物品定义）
    func generateTestRewards(distance: Double) -> GeneratedRewards {
        let itemDefinitions = MockExplorationData.itemDefinitions
        return generateRewards(distance: distance, itemDefinitions: itemDefinitions)
    }

    /// 打印奖励等级概率表（用于调试）
    func printRewardTable() {
        print("=== 奖励等级表 ===")
        for tier in RewardTier.allCases {
            print("\(tier.icon) \(tier.displayName):")
            print("  - 物品数量: \(tier.itemCount)")
            print("  - 经验倍率: \(tier.experienceMultiplier)x")
            print("  - 稀有度概率: \(tier.rarityProbabilities)")
        }
    }
}
