//
//  MoreTabView.swift
//  EarthLord
//
//  Created by Claude on 2025/12/24.
//

import SwiftUI

struct MoreTabView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("开发测试") {
                    NavigationLink(destination: SupabaseTestView()) {
                        Label("Supabase 连接测试", systemImage: "network")
                    }
                }
            }
            .navigationTitle("更多")
        }
    }
}

#Preview {
    MoreTabView()
}
