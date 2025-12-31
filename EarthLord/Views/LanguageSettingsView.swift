//
//  LanguageSettingsView.swift
//  EarthLord
//
//  Created by Claude Code
//

import SwiftUI

/// 语言设置页面
struct LanguageSettingsView: View {
    /// 语言管理器
    @ObservedObject private var languageManager = LanguageManager.shared

    /// 环境变量 - 用于返回上一页
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(AppLanguage.allCases) { language in
                languageRow(language: language)
            }
        }
        .navigationTitle(Text("语言".localized()))
        .navigationBarTitleDisplayMode(.inline)
        .refreshOnLanguageChange()
    }

    // MARK: - 语言选项行

    /// 语言选项行
    /// - Parameter language: 语言选项
    /// - Returns: 语言行视图
    private func languageRow(language: AppLanguage) -> some View {
        Button(action: {
            // 切换语言
            languageManager.switchLanguage(to: language)

            // 延迟返回，让用户看到选中效果
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismiss()
            }
        }) {
            HStack {
                Text(language.displayName)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)

                Spacer()

                // 选中标记
                if languageManager.currentLanguage == language {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationStack {
        LanguageSettingsView()
    }
}
