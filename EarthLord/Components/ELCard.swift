//
//  ELCard.swift
//  EarthLord
//
//  Created by Claude Code
//

import SwiftUI

/// 末日主题卡片组件
struct ELCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16
    var backgroundColor: Color = ApocalypseTheme.cardBackground

    init(padding: CGFloat = 16, backgroundColor: Color = ApocalypseTheme.cardBackground, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.backgroundColor = backgroundColor
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        ELCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("卡片标题")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("这是一个示例卡片内容")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding()
    }
}
