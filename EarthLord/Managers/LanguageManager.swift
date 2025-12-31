//
//  LanguageManager.swift
//  EarthLord
//
//  Created by Claude Code
//

import Foundation
import SwiftUI
import Combine

/// App 支持的语言
enum AppLanguage: String, CaseIterable, Identifiable {
    /// 跟随系统
    case system = "system"
    /// 简体中文
    case chinese = "zh-Hans"
    /// 英文
    case english = "en"

    var id: String { rawValue }

    /// 显示名称（用中文显示，因为用户需要能看懂切换选项）
    var displayName: String {
        switch self {
        case .system:
            return "跟随系统"
        case .chinese:
            return "简体中文"
        case .english:
            return "English"
        }
    }

    /// 获取对应的 Locale 标识符
    /// - Returns: 语言代码，如果是跟随系统则返回 nil
    var localeIdentifier: String? {
        switch self {
        case .system:
            return nil
        case .chinese:
            return "zh-Hans"
        case .english:
            return "en"
        }
    }
}

/// 语言管理器
/// 负责管理 App 内的语言切换
class LanguageManager: ObservableObject {

    // MARK: - Published Properties

    /// 当前选择的语言
    @Published var currentLanguage: AppLanguage = .system

    // MARK: - Private Properties

    /// UserDefaults 存储键
    private let languageKey = "app_language"

    // MARK: - Singleton

    /// 全局共享实例
    static let shared = LanguageManager()

    // MARK: - Initializer

    private init() {
        print("🚀 LanguageManager 初始化")

        // 从 UserDefaults 读取保存的语言设置
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
            print("📖 从 UserDefaults 加载语言: \(language.displayName) (\(savedLanguage))")
        } else {
            print("📖 未找到保存的语言设置，使用默认值: \(currentLanguage.displayName)")
        }

        // 应用语言设置
        applyLanguage()

        // 设置监听器
        setupObserver()
    }

    // MARK: - Observer

    /// 设置属性监听器
    private func setupObserver() {
        $currentLanguage
            .dropFirst() // 跳过初始值
            .sink { [weak self] newLanguage in
                guard let self = self else { return }
                self.saveLanguage()
                self.applyLanguage()
            }
            .store(in: &cancellables)
    }

    /// 用于存储订阅
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Public Methods

    /// 切换语言
    /// - Parameter language: 目标语言
    func switchLanguage(to language: AppLanguage) {
        currentLanguage = language
    }

    /// 获取当前实际使用的语言代码
    /// - Returns: 语言代码（如 "zh-Hans" 或 "en"）
    func getCurrentLocaleIdentifier() -> String {
        if let identifier = currentLanguage.localeIdentifier {
            return identifier
        } else {
            // 跟随系统，返回系统首选语言
            return Locale.preferredLanguages.first ?? "en"
        }
    }

    // MARK: - Private Methods

    /// 保存语言设置到 UserDefaults
    private func saveLanguage() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
        UserDefaults.standard.synchronize()
        print("💾 语言设置已保存: \(currentLanguage.displayName) -> \(currentLanguage.rawValue)")
    }

    /// 应用语言设置
    private func applyLanguage() {
        // 清空缓存的 Bundle，强制重新加载
        Self.cachedBundles.removeAll()

        if let localeIdentifier = currentLanguage.localeIdentifier {
            print("🌍 语言已切换到: \(currentLanguage.displayName) (\(localeIdentifier))")
        } else {
            print("🌍 语言已切换到: 跟随系统")
        }

        // 发送通知，告知语言已更改
        NotificationCenter.default.post(name: .languageDidChange, object: nil)
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    /// 语言切换通知
    static let languageDidChange = Notification.Name("languageDidChange")
}

// MARK: - String Extension for Localization

extension String {
    /// 获取本地化字符串
    /// - Returns: 本地化后的字符串
    func localized() -> String {
        return LanguageManager.shared.localizedString(for: self)
    }

    /// 获取本地化字符串（带参数）
    /// - Parameter arguments: 格式化参数
    /// - Returns: 格式化后的本地化字符串
    func localized(_ arguments: CVarArg...) -> String {
        return String(format: localized(), arguments: arguments)
    }
}

// MARK: - Bundle Extension for Language Support

extension LanguageManager {
    /// 缓存的语言 Bundle
    private static var cachedBundles: [String: Bundle] = [:]

    /// 获取指定语言的 Bundle
    /// - Parameter language: 语言代码
    /// - Returns: 对应语言的 Bundle
    private func getBundle(for language: String) -> Bundle? {
        // 检查缓存
        if let cached = Self.cachedBundles[language] {
            return cached
        }

        // 尝试创建 Bundle
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            Self.cachedBundles[language] = bundle
            return bundle
        }

        return nil
    }

    /// 获取当前语言的本地化字符串
    /// - Parameter key: 字符串的 key
    /// - Returns: 本地化后的字符串
    func localizedString(for key: String) -> String {
        let language = getCurrentLocaleIdentifier()

        print("🔍 查找翻译: '\(key)' 语言: \(language)")

        // 尝试多个可能的语言代码
        let languageCodes = [language, language.components(separatedBy: "-").first ?? language]

        for langCode in languageCodes {
            if let bundle = getBundle(for: langCode) {
                print("✅ 找到语言包: \(langCode)")

                let localizedString = NSLocalizedString(key, tableName: nil, bundle: bundle, value: "", comment: "")

                if !localizedString.isEmpty && localizedString != key {
                    print("✅ 找到翻译: '\(key)' -> '\(localizedString)'")
                    return localizedString
                } else {
                    print("⚠️ Bundle 中未找到 key: '\(key)'")
                }
            } else {
                print("❌ 未找到语言包: \(langCode).lproj")
            }
        }

        // 最后尝试直接从主 Bundle 加载
        let localizedString = NSLocalizedString(key, comment: "")
        if !localizedString.isEmpty && localizedString != key {
            print("✅ 从主 Bundle 找到翻译: '\(key)' -> '\(localizedString)'")
            return localizedString
        }

        print("⚠️ 未找到翻译，返回原文: '\(key)'")
        return key
    }
}
