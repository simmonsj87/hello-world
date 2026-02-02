//
//  TimerConfiguration.swift
//  WorkoutTimer
//
//  Configuration model for interval timer settings.
//

import Foundation
import Combine
import SwiftUI

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

// MARK: - Saved Timer Preset

struct SavedTimerPreset: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var configuration: TimerConfiguration
    var createdDate: Date

    init(name: String, configuration: TimerConfiguration) {
        self.id = UUID()
        self.name = name
        self.configuration = configuration
        self.createdDate = Date()
    }
}

// MARK: - Timer Presets Manager

class TimerPresetsManager: ObservableObject {
    static let shared = TimerPresetsManager()

    private let key = "savedTimerPresets"

    @Published var presets: [SavedTimerPreset] = []

    private init() {
        load()
    }

    func save(_ preset: SavedTimerPreset) {
        // Check if a preset with the same name already exists
        if let index = presets.firstIndex(where: { $0.name == preset.name }) {
            presets[index] = preset
        } else {
            presets.append(preset)
        }
        persist()
    }

    func delete(_ preset: SavedTimerPreset) {
        presets.removeAll { $0.id == preset.id }
        persist()
    }

    func delete(at offsets: IndexSet) {
        presets.remove(atOffsets: offsets)
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }

        do {
            presets = try JSONDecoder().decode([SavedTimerPreset].self, from: data)
        } catch {
            print("Error loading timer presets: \(error)")
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(presets)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("Error saving timer presets: \(error)")
        }
    }
}
