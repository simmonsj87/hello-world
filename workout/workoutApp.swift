//
//  workoutApp.swift
//  workout
//
//  Created by Justin Simmons on 1/27/26.
//

import SwiftUI
import CoreData

@main
struct workoutApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
