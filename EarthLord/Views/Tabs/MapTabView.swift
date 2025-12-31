//
//  MapTabView.swift
//  EarthLord
//
//  Created by Claude on 2025/12/24.
//

import SwiftUI

struct MapTabView: View {
    @ObservedObject private var languageManager = LanguageManager.shared

    var body: some View {
        PlaceholderView(
            icon: "map.fill",
            title: "地图",
            subtitle: "探索和圈占领地"
        )
        .refreshOnLanguageChange()
    }
}

#Preview {
    MapTabView()
}
