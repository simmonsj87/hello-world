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
    @ObservedObject private var timerTracker = ActiveTimerTracker.shared
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                TimerView()
                    .tabItem {
                        Label("Timer", systemImage: "timer")
                    }
                    .tag(0)

                ExerciseListView()
                    .tabItem {
                        Label("Exercises", systemImage: "list.bullet")
                    }
                    .tag(1)

                WorkoutListView()
                    .tabItem {
                        Label("Workouts", systemImage: "figure.run")
                    }
                    .tag(2)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(3)
            }
            .onAppear {
                Category.createDefaultCategories(in: viewContext)
            }

            // Mini timer bar: visible when the interval timer is running
            // and the user has navigated away from the Timer tab.
            if timerTracker.isIntervalTimerActive && selectedTab != 0 {
                MiniTimerBar(
                    time: timerTracker.displayTime,
                    state: timerTracker.displayState
                ) {
                    selectedTab = 0
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: timerTracker.isIntervalTimerActive)
                .zIndex(1)
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Mini Timer Bar

struct MiniTimerBar: View {
    let time: String
    let state: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "timer")
                    .font(.caption)
                    .foregroundColor(.white)

                Text(state.uppercased())
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                Text(time)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.green.opacity(0.95))
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            )
        }
        .padding(.horizontal, 40)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    }
}
