//
//  WorkoutExecutionState.swift
//  WorkoutTimer
//
//  Enum representing the state of workout execution.
//

import Foundation

enum WorkoutExecutionState: Equatable {
    case ready
    case warmup      // Warmup timer before workout starts
    case countdown
    case running
    case resting
    case roundRest
    case paused
    case completed
}
