//
//  maestroApp.swift
//  maestro
//
//  Created by Maor Kima on 25/04/2026.
//

import SwiftUI
import SwiftData

@main
struct maestroApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: Recipe.self)
        }
    }
}
