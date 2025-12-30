//
//  EarthLordApp.swift
//  EarthLord
//
//  Created by 昕尧 on 2025/12/24.
//

import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct EarthLordApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    print("📱 收到 URL 回调: \(url.absoluteString)")
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
