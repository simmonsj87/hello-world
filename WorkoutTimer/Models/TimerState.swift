//
//  TimerState.swift
//  WorkoutTimer
//
//  Enum representing the current state of the interval timer.
//

import Foundation
import SwiftUI

enum TimerState: Equatable {
    /// Timer is not running and ready to start
    case idle

    /// Currently in a work interval
    case working

    /// Currently in a rest interval between cycles
    case resting

    /// Currently in a longer rest between rounds
    case roundRest

    /// Workout has finished all rounds and cycles
    case completed

    /// Display name for the current state
    var displayName: String {
        switch self {
        case .idle:
            return "Ready"
        case .working:
            return "Work"
        case .resting:
            return "Rest"
        case .roundRest:
            return "Round Rest"
        case .completed:
            return "Complete"
        }
    }

    /// Color associated with the current state
    var color: Color {
        switch self {
        case .idle:
            return .gray
        case .working:
            return .green
        case .resting:
            return .orange
        case .roundRest:
            return .blue
        case .completed:
            return .purple
        }
    }

    /// SF Symbol icon for the current state
    var iconName: String {
        switch self {
        case .idle:
            return "play.circle"
        case .working:
            return "flame.fill"
        case .resting:
            return "pause.circle"
        case .roundRest:
            return "bed.double.fill"
        case .completed:
            return "checkmark.circle.fill"
        }
    }
}
