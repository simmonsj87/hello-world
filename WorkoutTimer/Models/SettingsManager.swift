//
//  SettingsManager.swift
//  WorkoutTimer
//
//  Centralized settings manager with UserDefaults persistence.
//

import Foundation
import Combine
import UIKit

class SettingsManager: ObservableObject {
    // MARK: - Singleton

    static let shared = SettingsManager()

    // MARK: - Voice Settings

    @Published var voiceEnabled: Bool {
        didSet { save(.voiceEnabled, value: voiceEnabled) }
    }

    @Published var selectedVoiceIdentifier: String {
        didSet { save(.selectedVoiceIdentifier, value: selectedVoiceIdentifier) }
    }

    @Published var speechRate: Float {
        didSet { save(.speechRate, value: speechRate) }
    }

    @Published var speechVolume: Float {
        didSet { save(.speechVolume, value: speechVolume) }
    }

    // MARK: - Workout Defaults

    @Published var defaultExerciseDuration: Int {
        didSet { save(.defaultExerciseDuration, value: defaultExerciseDuration) }
    }

    @Published var defaultRestBetweenExercises: Int {
        didSet { save(.defaultRestBetweenExercises, value: defaultRestBetweenExercises) }
    }

    @Published var defaultRestBetweenRounds: Int {
        didSet { save(.defaultRestBetweenRounds, value: defaultRestBetweenRounds) }
    }

    @Published var autoStartNextExercise: Bool {
        didSet { save(.autoStartNextExercise, value: autoStartNextExercise) }
    }

    // MARK: - Timer Defaults

    @Published var defaultWorkDuration: Int {
        didSet { save(.defaultWorkDuration, value: defaultWorkDuration) }
    }

    @Published var defaultRestDuration: Int {
        didSet { save(.defaultRestDuration, value: defaultRestDuration) }
    }

    @Published var defaultCycles: Int {
        didSet { save(.defaultCycles, value: defaultCycles) }
    }

    @Published var defaultRounds: Int {
        didSet { save(.defaultRounds, value: defaultRounds) }
    }

    // MARK: - App Preferences

    @Published var keepScreenAwake: Bool {
        didSet {
            save(.keepScreenAwake, value: keepScreenAwake)
            updateIdleTimer()
        }
    }

    @Published var showNotifications: Bool {
        didSet { save(.showNotifications, value: showNotifications) }
    }

    @Published var hapticFeedbackEnabled: Bool {
        didSet { save(.hapticFeedbackEnabled, value: hapticFeedbackEnabled) }
    }

    @Published var soundEffectsEnabled: Bool {
        didSet { save(.soundEffectsEnabled, value: soundEffectsEnabled) }
    }

    // MARK: - Settings Keys

    private enum SettingsKey: String {
        // Voice
        case voiceEnabled
        case selectedVoiceIdentifier
        case speechRate
        case speechVolume

        // Workout
        case defaultExerciseDuration
        case defaultRestBetweenExercises
        case defaultRestBetweenRounds
        case autoStartNextExercise

        // Timer
        case defaultWorkDuration
        case defaultRestDuration
        case defaultCycles
        case defaultRounds

        // App
        case keepScreenAwake
        case showNotifications
        case hapticFeedbackEnabled
        case soundEffectsEnabled

        // Quick Start Preset
        case quickStartPresetSaved
    }

    // MARK: - Default Values

    private struct Defaults {
        // Voice
        static let voiceEnabled = true
        static let selectedVoiceIdentifier = ""
        static let speechRate: Float = 0.5
        static let speechVolume: Float = 0.8

        // Workout
        static let defaultExerciseDuration = 30
        static let defaultRestBetweenExercises = 15
        static let defaultRestBetweenRounds = 60
        static let autoStartNextExercise = true

        // Timer
        static let defaultWorkDuration = 30
        static let defaultRestDuration = 10
        static let defaultCycles = 4
        static let defaultRounds = 3

        // App
        static let keepScreenAwake = true
        static let showNotifications = true
        static let hapticFeedbackEnabled = true
        static let soundEffectsEnabled = true
    }

    // MARK: - Initialization

    private init() {
        // Voice
        self.voiceEnabled = UserDefaults.standard.object(forKey: SettingsKey.voiceEnabled.rawValue) as? Bool ?? Defaults.voiceEnabled
        self.selectedVoiceIdentifier = UserDefaults.standard.string(forKey: SettingsKey.selectedVoiceIdentifier.rawValue) ?? Defaults.selectedVoiceIdentifier
        self.speechRate = UserDefaults.standard.object(forKey: SettingsKey.speechRate.rawValue) as? Float ?? Defaults.speechRate
        self.speechVolume = UserDefaults.standard.object(forKey: SettingsKey.speechVolume.rawValue) as? Float ?? Defaults.speechVolume

        // Workout
        self.defaultExerciseDuration = UserDefaults.standard.object(forKey: SettingsKey.defaultExerciseDuration.rawValue) as? Int ?? Defaults.defaultExerciseDuration
        self.defaultRestBetweenExercises = UserDefaults.standard.object(forKey: SettingsKey.defaultRestBetweenExercises.rawValue) as? Int ?? Defaults.defaultRestBetweenExercises
        self.defaultRestBetweenRounds = UserDefaults.standard.object(forKey: SettingsKey.defaultRestBetweenRounds.rawValue) as? Int ?? Defaults.defaultRestBetweenRounds
        self.autoStartNextExercise = UserDefaults.standard.object(forKey: SettingsKey.autoStartNextExercise.rawValue) as? Bool ?? Defaults.autoStartNextExercise

        // Timer
        self.defaultWorkDuration = UserDefaults.standard.object(forKey: SettingsKey.defaultWorkDuration.rawValue) as? Int ?? Defaults.defaultWorkDuration
        self.defaultRestDuration = UserDefaults.standard.object(forKey: SettingsKey.defaultRestDuration.rawValue) as? Int ?? Defaults.defaultRestDuration
        self.defaultCycles = UserDefaults.standard.object(forKey: SettingsKey.defaultCycles.rawValue) as? Int ?? Defaults.defaultCycles
        self.defaultRounds = UserDefaults.standard.object(forKey: SettingsKey.defaultRounds.rawValue) as? Int ?? Defaults.defaultRounds

        // App
        self.keepScreenAwake = UserDefaults.standard.object(forKey: SettingsKey.keepScreenAwake.rawValue) as? Bool ?? Defaults.keepScreenAwake
        self.showNotifications = UserDefaults.standard.object(forKey: SettingsKey.showNotifications.rawValue) as? Bool ?? Defaults.showNotifications
        self.hapticFeedbackEnabled = UserDefaults.standard.object(forKey: SettingsKey.hapticFeedbackEnabled.rawValue) as? Bool ?? Defaults.hapticFeedbackEnabled
        self.soundEffectsEnabled = UserDefaults.standard.object(forKey: SettingsKey.soundEffectsEnabled.rawValue) as? Bool ?? Defaults.soundEffectsEnabled
    }

    // MARK: - Persistence

    private func save(_ key: SettingsKey, value: Any) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    // MARK: - Quick Start Preset

    var hasQuickStartPreset: Bool {
        UserDefaults.standard.bool(forKey: SettingsKey.quickStartPresetSaved.rawValue)
    }

    func saveAsQuickStartPreset() {
        UserDefaults.standard.set(true, forKey: SettingsKey.quickStartPresetSaved.rawValue)
    }

    func getTimerConfiguration() -> TimerConfiguration {
        TimerConfiguration(
            workDuration: defaultWorkDuration,
            restDuration: defaultRestDuration,
            cycles: defaultCycles,
            rounds: defaultRounds,
            restBetweenRounds: defaultRestBetweenRounds
        )
    }

    // MARK: - Reset

    func resetToDefaults() {
        // Voice
        voiceEnabled = Defaults.voiceEnabled
        selectedVoiceIdentifier = Defaults.selectedVoiceIdentifier
        speechRate = Defaults.speechRate
        speechVolume = Defaults.speechVolume

        // Workout
        defaultExerciseDuration = Defaults.defaultExerciseDuration
        defaultRestBetweenExercises = Defaults.defaultRestBetweenExercises
        defaultRestBetweenRounds = Defaults.defaultRestBetweenRounds
        autoStartNextExercise = Defaults.autoStartNextExercise

        // Timer
        defaultWorkDuration = Defaults.defaultWorkDuration
        defaultRestDuration = Defaults.defaultRestDuration
        defaultCycles = Defaults.defaultCycles
        defaultRounds = Defaults.defaultRounds

        // App
        keepScreenAwake = Defaults.keepScreenAwake
        showNotifications = Defaults.showNotifications
        hapticFeedbackEnabled = Defaults.hapticFeedbackEnabled
        soundEffectsEnabled = Defaults.soundEffectsEnabled
    }

    // MARK: - Screen Wake

    private func updateIdleTimer() {
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = self.keepScreenAwake
        }
    }

    func enableScreenAwakeForWorkout() {
        if keepScreenAwake {
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = true
            }
        }
    }

    func disableScreenAwakeAfterWorkout() {
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - Haptic Feedback

    func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard hapticFeedbackEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    func triggerNotificationHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard hapticFeedbackEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}

// MARK: - Data Export Model

struct AppDataExport: Codable {
    let exportDate: Date
    let appVersion: String
    let exercises: [ExerciseExport]
    let workouts: [WorkoutExport]
    let categories: [CategoryExport]
}

struct ExerciseExport: Codable {
    let id: UUID
    let name: String
    let category: String
    let createdDate: Date
}

struct WorkoutExport: Codable {
    let id: UUID
    let name: String
    let createdDate: Date
    let rounds: Int
    let timePerExercise: Int
    let restBetweenExercises: Int
    let restBetweenRounds: Int
    let executionMode: String
    let exercises: [WorkoutExerciseExport]
}

struct WorkoutExerciseExport: Codable {
    let exerciseId: UUID
    let duration: Int
    let orderIndex: Int
}

struct CategoryExport: Codable {
    let id: UUID
    let name: String
    let isDefault: Bool
    let orderIndex: Int
}
