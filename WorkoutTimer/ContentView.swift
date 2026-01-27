//
//  ContentView.swift
//  WorkoutTimer
//
//  Main content view for the Workout Timer app with 4-tab navigation.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        TabView {
            TimerView()
                .tabItem {
                    Label("Timer", systemImage: "timer")
                }

            ExerciseListView()
                .tabItem {
                    Label("Exercises", systemImage: "list.bullet")
                }

            WorkoutListView()
                .tabItem {
                    Label("Workouts", systemImage: "figure.run")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .onAppear {
            Category.createDefaultCategories(in: viewContext)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    }
}
