//
//  ContentView.swift
//  EarthLord
//
//  Created by 昕尧 on 2025/12/24.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 原本的名字
                Text("EarthLord")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.primary)

                // 进入测试页按钮
                NavigationLink(destination: TestView()) {
                    Text("进入测试页")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: 200)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(10)
                }

                Spacer()

                // 原有的主界面
                MainTabView()
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
