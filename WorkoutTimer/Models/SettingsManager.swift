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

// MARK: - Individual Exercise Export

struct SingleExerciseExport: Codable {
    let exportDate: Date
    let appVersion: String
    let exercise: ExerciseExport
}

// MARK: - Individual Workout Export (with embedded exercises)

struct SingleWorkoutExport: Codable {
    let exportDate: Date
    let appVersion: String
    let workout: WorkoutExport
    let exercises: [ExerciseExport]  // All exercises referenced by the workout
}

// MARK: - Exercise Library (for discovery feature)

struct ExerciseLibrary {
    static let exercises: [(name: String, category: String)] = [
        // Upper Body
        ("Push-ups", "Upper Body"),
        ("Diamond Push-ups", "Upper Body"),
        ("Wide Push-ups", "Upper Body"),
        ("Decline Push-ups", "Upper Body"),
        ("Pike Push-ups", "Upper Body"),
        ("Tricep Dips", "Upper Body"),
        ("Bench Dips", "Upper Body"),
        ("Arm Circles", "Upper Body"),
        ("Shoulder Taps", "Upper Body"),
        ("Plank to Push-up", "Upper Body"),
        ("Superman Pull", "Upper Body"),
        ("Inchworms", "Upper Body"),
        ("Bear Crawl", "Upper Body"),
        ("Commandos", "Upper Body"),
        ("Hindu Push-ups", "Upper Body"),
        ("Archer Push-ups", "Upper Body"),

        // Lower Body
        ("Squats", "Lower Body"),
        ("Jump Squats", "Lower Body"),
        ("Sumo Squats", "Lower Body"),
        ("Bulgarian Split Squats", "Lower Body"),
        ("Lunges", "Lower Body"),
        ("Reverse Lunges", "Lower Body"),
        ("Walking Lunges", "Lower Body"),
        ("Jump Lunges", "Lower Body"),
        ("Calf Raises", "Lower Body"),
        ("Single Leg Calf Raises", "Lower Body"),
        ("Wall Sit", "Lower Body"),
        ("Glute Bridges", "Lower Body"),
        ("Single Leg Glute Bridge", "Lower Body"),
        ("Hip Thrusts", "Lower Body"),
        ("Donkey Kicks", "Lower Body"),
        ("Fire Hydrants", "Lower Body"),
        ("Side Lunges", "Lower Body"),
        ("Curtsy Lunges", "Lower Body"),
        ("Step-ups", "Lower Body"),
        ("Box Jumps", "Lower Body"),
        ("Pistol Squats", "Lower Body"),

        // Core
        ("Plank", "Core"),
        ("Side Plank", "Core"),
        ("Plank with Hip Dips", "Core"),
        ("Crunches", "Core"),
        ("Bicycle Crunches", "Core"),
        ("Reverse Crunches", "Core"),
        ("Sit-ups", "Core"),
        ("V-ups", "Core"),
        ("Leg Raises", "Core"),
        ("Flutter Kicks", "Core"),
        ("Scissor Kicks", "Core"),
        ("Mountain Climbers", "Core"),
        ("Dead Bug", "Core"),
        ("Bird Dog", "Core"),
        ("Russian Twists", "Core"),
        ("Heel Taps", "Core"),
        ("Hollow Body Hold", "Core"),
        ("Ab Rollouts", "Core"),
        ("Toe Touches", "Core"),
        ("Windshield Wipers", "Core"),

        // Cardio
        ("Jumping Jacks", "Cardio"),
        ("High Knees", "Cardio"),
        ("Butt Kicks", "Cardio"),
        ("Burpees", "Cardio"),
        ("Star Jumps", "Cardio"),
        ("Tuck Jumps", "Cardio"),
        ("Skaters", "Cardio"),
        ("Mountain Climbers", "Cardio"),
        ("Fast Feet", "Cardio"),
        ("Lateral Shuffles", "Cardio"),
        ("Jump Rope", "Cardio"),
        ("Shadow Boxing", "Cardio"),
        ("Speed Skaters", "Cardio"),
        ("Sprint in Place", "Cardio"),
        ("Plyo Lunges", "Cardio"),

        // Full Body
        ("Burpees", "Full Body"),
        ("Thrusters", "Full Body"),
        ("Man Makers", "Full Body"),
        ("Devil Press", "Full Body"),
        ("Turkish Get-ups", "Full Body"),
        ("Bear Crawls", "Full Body"),
        ("Sprawls", "Full Body"),
        ("Froggers", "Full Body"),
        ("Inchworm to Push-up", "Full Body"),
        ("Squat to Press", "Full Body"),
        ("Lunge with Twist", "Full Body"),
        ("Plank Jacks", "Full Body"),
        ("Cross-body Mountain Climbers", "Full Body"),

        // Stretching/Mobility
        ("Cat-Cow Stretch", "Stretching"),
        ("Child's Pose", "Stretching"),
        ("Downward Dog", "Stretching"),
        ("Cobra Stretch", "Stretching"),
        ("Pigeon Pose", "Stretching"),
        ("Hip Flexor Stretch", "Stretching"),
        ("Hamstring Stretch", "Stretching"),
        ("Quad Stretch", "Stretching"),
        ("Shoulder Stretch", "Stretching"),
        ("Chest Stretch", "Stretching"),
        ("Tricep Stretch", "Stretching"),
        ("Neck Rolls", "Stretching"),
        ("Spinal Twist", "Stretching"),
        ("World's Greatest Stretch", "Stretching"),
        ("90/90 Hip Stretch", "Stretching"),
    ]

    static var categories: [String] {
        Array(Set(exercises.map { $0.category })).sorted()
    }

    static func exercises(for category: String) -> [(name: String, category: String)] {
        exercises.filter { $0.category == category }
    }

    static func search(_ query: String) -> [(name: String, category: String)] {
        guard !query.isEmpty else { return exercises }
        return exercises.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.category.localizedCaseInsensitiveContains(query)
        }
    }
}
