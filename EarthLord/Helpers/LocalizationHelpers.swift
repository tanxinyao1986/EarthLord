//
//  LocalizationHelpers.swift
//  EarthLord
//
//  Created by Claude Code
//

import SwiftUI

/// 支持实时语言切换的文本视图
struct LocalizedText: View {
    let key: String
    @ObservedObject private var languageManager = LanguageManager.shared

    init(_ key: String) {
        self.key = key
    }

    var body: some View {
        Text(key.localized())
    }
}

/// 视图扩展：添加语言切换时自动刷新的功能
extension View {
    /// 使视图在语言切换时自动刷新
    func refreshOnLanguageChange() -> some View {
        self.modifier(LanguageChangeModifier())
    }
}

/// 监听语言切换并刷新视图的修饰符
struct LanguageChangeModifier: ViewModifier {
    @ObservedObject private var languageManager = LanguageManager.shared

    func body(content: Content) -> some View {
        content
            .id(languageManager.currentLanguage.rawValue)
    }
}
