//
//  PlaceholderView.swift
//  EarthLord
//
//  Created by Claude on 2025/12/24.
//

import SwiftUI

/// 通用占位视图
struct PlaceholderView: View {
    let icon: String
    let title: String
    let subtitle: String

    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.primary)

                Text(title.localized())
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(subtitle.localized())
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .id(languageManager.currentLanguage.rawValue)
    }
}

#Preview {
    PlaceholderView(
        icon: "map.fill",
        title: "地图",
        subtitle: "探索和圈占领地"
    )
}
