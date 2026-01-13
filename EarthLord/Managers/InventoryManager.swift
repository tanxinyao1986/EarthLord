//
//  InventoryManager.swift
//  EarthLord
//
//  背包管理器 - 管理玩家背包物品，与数据库同步
//

import Foundation
import Combine
import Supabase

/// 背包管理器
@MainActor
class InventoryManager: ObservableObject {
    // MARK: - 单例
    static let shared = InventoryManager()

    // MARK: - Published 属性
    @Published var items: [InventoryItem] = []
    @Published var itemDefinitions: [ItemDefinition] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    // MARK: - 私有属性
    private let supabase = SupabaseConfig.shared

    // MARK: - 初始化
    private init() {}

    // MARK: - 公开方法

    /// 加载物品定义表
    func loadItemDefinitions() async throws -> [ItemDefinition] {
        do {
            let response: [ItemDefinitionDB] = try await supabase
                .from("item_definitions")
                .select()
                .eq("is_active", value: true)
                .execute()
                .value

            let definitions = response.map { $0.toItemDefinition() }
            self.itemDefinitions = definitions

            LogManager.shared.info("已加载 \(definitions.count) 个物品定义")
            return definitions

        } catch {
            LogManager.shared.error("加载物品定义失败: \(error.localizedDescription)")
            throw InventoryError.databaseError(error.localizedDescription)
        }
    }

    /// 加载用户背包
    func loadInventory() async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw InventoryError.notAuthenticated
        }

        isLoading = true
        error = nil

        do {
            // 1. 先加载物品定义（如果还没加载）
            if itemDefinitions.isEmpty {
                _ = try await loadItemDefinitions()
            }

            // 2. 加载背包物品
            let response: [InventoryItemDB] = try await supabase
                .from("inventory_items")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("acquired_at", ascending: false)
                .execute()
                .value

            // 3. 转换为 UI 模型
            self.items = response.map { dbItem in
                let item = dbItem.toInventoryItem()
                // 关联物品定义
                return item
            }

            isLoading = false
            LogManager.shared.info("已加载 \(items.count) 个背包物品")

        } catch {
            isLoading = false
            self.error = error.localizedDescription
            LogManager.shared.error("加载背包失败: \(error.localizedDescription)")
            throw InventoryError.databaseError(error.localizedDescription)
        }
    }

    /// 添加物品到背包
    /// - Parameters:
    ///   - items: 要添加的物品 [itemId: quantity]
    ///   - explorationSessionId: 来源探索会话 ID（可选）
    func addItems(_ newItems: [String: Int], explorationSessionId: UUID? = nil) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw InventoryError.notAuthenticated
        }

        for (itemId, quantity) in newItems {
            try await addOrUpdateItem(
                userId: userId,
                itemId: itemId,
                quantity: quantity,
                explorationSessionId: explorationSessionId
            )
        }

        // 重新加载背包
        try await loadInventory()
    }

    /// 更新物品数量
    /// - Parameters:
    ///   - itemId: 背包物品 ID
    ///   - quantity: 新数量
    func updateQuantity(itemId: UUID, quantity: Int) async throws {
        guard quantity > 0 else {
            // 数量为0或负数，删除物品
            try await removeItem(itemId: itemId)
            return
        }

        do {
            let updateData = InventoryItemUpdate(quantity: quantity)
            try await supabase
                .from("inventory_items")
                .update(updateData)
                .eq("id", value: itemId.uuidString)
                .execute()

            // 重新加载背包
            try await loadInventory()

            LogManager.shared.info("物品数量已更新")

        } catch {
            LogManager.shared.error("更新物品数量失败: \(error.localizedDescription)")
            throw InventoryError.databaseError(error.localizedDescription)
        }
    }

    /// 移除物品
    /// - Parameter itemId: 背包物品 ID
    func removeItem(itemId: UUID) async throws {
        do {
            try await supabase
                .from("inventory_items")
                .delete()
                .eq("id", value: itemId.uuidString)
                .execute()

            // 重新加载背包
            try await loadInventory()

            LogManager.shared.info("物品已移除")

        } catch {
            LogManager.shared.error("移除物品失败: \(error.localizedDescription)")
            throw InventoryError.databaseError(error.localizedDescription)
        }
    }

    /// 获取指定分类的物品
    /// - Parameter category: 物品分类
    /// - Returns: 该分类的物品列表
    func getItems(byCategory category: ItemCategory) -> [InventoryItem] {
        return items.filter { item in
            item.definition?.category == category
        }
    }

    /// 获取物品定义
    /// - Parameter itemId: 物品 ID
    /// - Returns: 物品定义（如果存在）
    func getItemDefinition(id: String) -> ItemDefinition? {
        return itemDefinitions.first { $0.id == id }
    }

    /// 计算背包总重量
    var totalWeight: Double {
        return items.reduce(0) { $0 + $1.totalWeight }
    }

    /// 清空本地缓存（用于登出时）
    func clearCache() {
        items = []
        itemDefinitions = []
        error = nil
    }

    // MARK: - 私有方法

    /// 添加或更新背包物品（支持堆叠）
    private func addOrUpdateItem(userId: UUID, itemId: String, quantity: Int, explorationSessionId: UUID?) async throws {
        // 1. 检查是否已有相同物品
        let existingItems: [InventoryItemDB] = try await supabase
            .from("inventory_items")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("item_id", value: itemId)
            .execute()
            .value

        if let existingItem = existingItems.first {
            // 2. 已有物品，更新数量（堆叠）
            let newQuantity = existingItem.quantity + quantity

            let updateData = InventoryItemUpdate(quantity: newQuantity)
            try await supabase
                .from("inventory_items")
                .update(updateData)
                .eq("id", value: existingItem.id.uuidString)
                .execute()

            LogManager.shared.info("物品已堆叠: \(itemId) x\(quantity) -> 总数 \(newQuantity)")

        } else {
            // 3. 没有该物品，插入新记录
            let newItem = InventoryItemInsert(
                userId: userId,
                itemId: itemId,
                quantity: quantity,
                explorationSessionId: explorationSessionId
            )

            try await supabase
                .from("inventory_items")
                .insert(newItem)
                .execute()

            LogManager.shared.info("新物品已添加: \(itemId) x\(quantity)")
        }
    }
}

// MARK: - 便捷扩展

extension InventoryManager {
    /// 物品是否为空
    var isEmpty: Bool {
        return items.isEmpty
    }

    /// 物品总数
    var totalItemCount: Int {
        return items.reduce(0) { $0 + $1.quantity }
    }

    /// 不同物品种类数
    var uniqueItemCount: Int {
        return items.count
    }
}
