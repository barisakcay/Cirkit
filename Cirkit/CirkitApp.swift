//
//  CirkitApp.swift
//  Cirkit
//
//  Created by Baris Akcay on 2.03.2026.
//

import SwiftUI
import SwiftData

@main
struct CirkitApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Component.self,
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
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

