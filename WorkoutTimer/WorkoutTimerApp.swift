//
//  WorkoutTimerApp.swift
//  WorkoutTimer
//
//  Main entry point for the Workout Timer app.
//

import SwiftUI

@main
struct WorkoutTimerApp: App {
    let persistenceController = PersistenceController.shared
    @ObservedObject private var settingsManager = SettingsManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.viewContext)
                .environmentObject(settingsManager)
        }
    }
}
