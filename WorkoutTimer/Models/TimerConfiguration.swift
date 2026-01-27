//
//  TimerConfiguration.swift
//  WorkoutTimer
//
//  Configuration model for interval timer settings.
//

import Foundation

struct TimerConfiguration: Codable, Equatable {
    /// Duration of work intervals in seconds
    var workDuration: Int

    /// Duration of rest intervals in seconds
    var restDuration: Int

    /// Number of work/rest cycles per round
    var cycles: Int

    /// Total number of rounds
    var rounds: Int

    /// Rest duration between rounds in seconds
    var restBetweenRounds: Int

    /// Default configuration for a standard interval workout
    static let `default` = TimerConfiguration(
        workDuration: 30,
        restDuration: 10,
        cycles: 4,
        rounds: 3,
        restBetweenRounds: 60
    )

    /// Total workout duration in seconds
    var totalDuration: Int {
        let cycleTime = (workDuration + restDuration) * cycles
        let roundRestTime = restBetweenRounds * (rounds - 1)
        return (cycleTime * rounds) + roundRestTime
    }

    /// Formatted total duration string (e.g., "12:30")
    var formattedTotalDuration: String {
        let minutes = totalDuration / 60
        let seconds = totalDuration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
