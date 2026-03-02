//
//  CirkitApp.swift
//  Cirkit
//
//  Created by Baris Akcay on 2.03.2026.
//

import SwiftUI
import SwiftData

@main
struct Cirkit: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Component.self)
    }
}

