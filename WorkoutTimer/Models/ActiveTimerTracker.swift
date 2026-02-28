//
//  ActiveTimerTracker.swift
//  WorkoutTimer
//
//  Shared singleton that tracks active timer state so ContentView
//  can display a mini bar when the user navigates away from the timer.
//

import Foundation
import Combine

class ActiveTimerTracker: ObservableObject {
    static let shared = ActiveTimerTracker()

    @Published var isIntervalTimerActive: Bool = false
    @Published var isWorkoutActive: Bool = false
    @Published var displayTime: String = ""
    @Published var displayState: String = ""

    var isActive: Bool { isIntervalTimerActive || isWorkoutActive }

    private init() {}

    func updateInterval(active: Bool, time: String = "", state: String = "") {
        DispatchQueue.main.async {
            self.isIntervalTimerActive = active
            if active {
                self.displayTime = time
                self.displayState = state
            }
        }
    }

    func updateWorkout(active: Bool, time: String = "", state: String = "") {
        DispatchQueue.main.async {
            self.isWorkoutActive = active
            if active {
                self.displayTime = time
                self.displayState = state
            }
        }
    }
}
