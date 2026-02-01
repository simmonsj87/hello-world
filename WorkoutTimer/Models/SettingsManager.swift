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

enum Equipment: String, CaseIterable {
    case none = "No Equipment"
    case dumbbells = "Dumbbells"
    case kettlebell = "Kettlebell"
    case resistanceBands = "Resistance Bands"
    case pullUpBar = "Pull-up Bar"
    case bench = "Bench"
    case box = "Box/Step"
    case jumpRope = "Jump Rope"
    case abWheel = "Ab Wheel"

    var icon: String {
        switch self {
        case .none: return "figure.stand"
        case .dumbbells: return "dumbbell.fill"
        case .kettlebell: return "figure.strengthtraining.traditional"
        case .resistanceBands: return "arrow.left.arrow.right"
        case .pullUpBar: return "figure.climbing"
        case .bench: return "rectangle.fill"
        case .box: return "square.stack.3d.up.fill"
        case .jumpRope: return "lasso"
        case .abWheel: return "circle.circle"
        }
    }
}

struct LibraryExercise {
    let name: String
    let category: String
    let equipment: Equipment
}

struct ExerciseLibrary {
    static let exercises: [LibraryExercise] = [
        // Upper Body - No Equipment
        LibraryExercise(name: "Push-ups", category: "Upper Body", equipment: .none),
        LibraryExercise(name: "Diamond Push-ups", category: "Upper Body", equipment: .none),
        LibraryExercise(name: "Wide Push-ups", category: "Upper Body", equipment: .none),
        LibraryExercise(name: "Decline Push-ups", category: "Upper Body", equipment: .none),
        LibraryExercise(name: "Pike Push-ups", category: "Upper Body", equipment: .none),
        LibraryExercise(name: "Tricep Dips", category: "Upper Body", equipment: .none),
        LibraryExercise(name: "Arm Circles", category: "Upper Body", equipment: .none),
        LibraryExercise(name: "Shoulder Taps", category: "Upper Body", equipment: .none),
        LibraryExercise(name: "Plank to Push-up", category: "Upper Body", equipment: .none),
        LibraryExercise(name: "Superman Pull", category: "Upper Body", equipment: .none),
        LibraryExercise(name: "Inchworms", category: "Upper Body", equipment: .none),
        LibraryExercise(name: "Bear Crawl", category: "Upper Body", equipment: .none),
        LibraryExercise(name: "Commandos", category: "Upper Body", equipment: .none),
        LibraryExercise(name: "Hindu Push-ups", category: "Upper Body", equipment: .none),
        LibraryExercise(name: "Archer Push-ups", category: "Upper Body", equipment: .none),
        // Upper Body - Equipment
        LibraryExercise(name: "Bench Dips", category: "Upper Body", equipment: .bench),
        LibraryExercise(name: "Dumbbell Rows", category: "Upper Body", equipment: .dumbbells),
        LibraryExercise(name: "Dumbbell Press", category: "Upper Body", equipment: .dumbbells),
        LibraryExercise(name: "Dumbbell Flyes", category: "Upper Body", equipment: .dumbbells),
        LibraryExercise(name: "Bicep Curls", category: "Upper Body", equipment: .dumbbells),
        LibraryExercise(name: "Tricep Extensions", category: "Upper Body", equipment: .dumbbells),
        LibraryExercise(name: "Shoulder Press", category: "Upper Body", equipment: .dumbbells),
        LibraryExercise(name: "Lateral Raises", category: "Upper Body", equipment: .dumbbells),
        LibraryExercise(name: "Pull-ups", category: "Upper Body", equipment: .pullUpBar),
        LibraryExercise(name: "Chin-ups", category: "Upper Body", equipment: .pullUpBar),
        LibraryExercise(name: "Kettlebell Swings", category: "Upper Body", equipment: .kettlebell),
        LibraryExercise(name: "Band Pull-aparts", category: "Upper Body", equipment: .resistanceBands),

        // Lower Body - No Equipment
        LibraryExercise(name: "Squats", category: "Lower Body", equipment: .none),
        LibraryExercise(name: "Jump Squats", category: "Lower Body", equipment: .none),
        LibraryExercise(name: "Sumo Squats", category: "Lower Body", equipment: .none),
        LibraryExercise(name: "Lunges", category: "Lower Body", equipment: .none),
        LibraryExercise(name: "Reverse Lunges", category: "Lower Body", equipment: .none),
        LibraryExercise(name: "Walking Lunges", category: "Lower Body", equipment: .none),
        LibraryExercise(name: "Jump Lunges", category: "Lower Body", equipment: .none),
        LibraryExercise(name: "Calf Raises", category: "Lower Body", equipment: .none),
        LibraryExercise(name: "Single Leg Calf Raises", category: "Lower Body", equipment: .none),
        LibraryExercise(name: "Wall Sit", category: "Lower Body", equipment: .none),
        LibraryExercise(name: "Glute Bridges", category: "Lower Body", equipment: .none),
        LibraryExercise(name: "Single Leg Glute Bridge", category: "Lower Body", equipment: .none),
        LibraryExercise(name: "Hip Thrusts", category: "Lower Body", equipment: .none),
        LibraryExercise(name: "Donkey Kicks", category: "Lower Body", equipment: .none),
        LibraryExercise(name: "Fire Hydrants", category: "Lower Body", equipment: .none),
        LibraryExercise(name: "Side Lunges", category: "Lower Body", equipment: .none),
        LibraryExercise(name: "Curtsy Lunges", category: "Lower Body", equipment: .none),
        LibraryExercise(name: "Pistol Squats", category: "Lower Body", equipment: .none),
        // Lower Body - Equipment
        LibraryExercise(name: "Bulgarian Split Squats", category: "Lower Body", equipment: .bench),
        LibraryExercise(name: "Step-ups", category: "Lower Body", equipment: .box),
        LibraryExercise(name: "Box Jumps", category: "Lower Body", equipment: .box),
        LibraryExercise(name: "Goblet Squats", category: "Lower Body", equipment: .kettlebell),
        LibraryExercise(name: "Dumbbell Lunges", category: "Lower Body", equipment: .dumbbells),
        LibraryExercise(name: "Dumbbell Deadlifts", category: "Lower Body", equipment: .dumbbells),
        LibraryExercise(name: "Banded Squats", category: "Lower Body", equipment: .resistanceBands),

        // Core - No Equipment
        LibraryExercise(name: "Plank", category: "Core", equipment: .none),
        LibraryExercise(name: "Side Plank", category: "Core", equipment: .none),
        LibraryExercise(name: "Plank with Hip Dips", category: "Core", equipment: .none),
        LibraryExercise(name: "Crunches", category: "Core", equipment: .none),
        LibraryExercise(name: "Bicycle Crunches", category: "Core", equipment: .none),
        LibraryExercise(name: "Reverse Crunches", category: "Core", equipment: .none),
        LibraryExercise(name: "Sit-ups", category: "Core", equipment: .none),
        LibraryExercise(name: "V-ups", category: "Core", equipment: .none),
        LibraryExercise(name: "Leg Raises", category: "Core", equipment: .none),
        LibraryExercise(name: "Flutter Kicks", category: "Core", equipment: .none),
        LibraryExercise(name: "Scissor Kicks", category: "Core", equipment: .none),
        LibraryExercise(name: "Mountain Climbers", category: "Core", equipment: .none),
        LibraryExercise(name: "Dead Bug", category: "Core", equipment: .none),
        LibraryExercise(name: "Bird Dog", category: "Core", equipment: .none),
        LibraryExercise(name: "Russian Twists", category: "Core", equipment: .none),
        LibraryExercise(name: "Heel Taps", category: "Core", equipment: .none),
        LibraryExercise(name: "Hollow Body Hold", category: "Core", equipment: .none),
        LibraryExercise(name: "Toe Touches", category: "Core", equipment: .none),
        LibraryExercise(name: "Windshield Wipers", category: "Core", equipment: .none),
        // Core - Equipment
        LibraryExercise(name: "Ab Rollouts", category: "Core", equipment: .abWheel),
        LibraryExercise(name: "Hanging Leg Raises", category: "Core", equipment: .pullUpBar),
        LibraryExercise(name: "Weighted Russian Twists", category: "Core", equipment: .dumbbells),

        // Cardio - No Equipment
        LibraryExercise(name: "Jumping Jacks", category: "Cardio", equipment: .none),
        LibraryExercise(name: "High Knees", category: "Cardio", equipment: .none),
        LibraryExercise(name: "Butt Kicks", category: "Cardio", equipment: .none),
        LibraryExercise(name: "Burpees", category: "Cardio", equipment: .none),
        LibraryExercise(name: "Star Jumps", category: "Cardio", equipment: .none),
        LibraryExercise(name: "Tuck Jumps", category: "Cardio", equipment: .none),
        LibraryExercise(name: "Skaters", category: "Cardio", equipment: .none),
        LibraryExercise(name: "Fast Feet", category: "Cardio", equipment: .none),
        LibraryExercise(name: "Lateral Shuffles", category: "Cardio", equipment: .none),
        LibraryExercise(name: "Shadow Boxing", category: "Cardio", equipment: .none),
        LibraryExercise(name: "Speed Skaters", category: "Cardio", equipment: .none),
        LibraryExercise(name: "Sprint in Place", category: "Cardio", equipment: .none),
        LibraryExercise(name: "Plyo Lunges", category: "Cardio", equipment: .none),
        // Cardio - Equipment
        LibraryExercise(name: "Jump Rope", category: "Cardio", equipment: .jumpRope),
        LibraryExercise(name: "Box Jumps", category: "Cardio", equipment: .box),

        // Full Body - No Equipment
        LibraryExercise(name: "Burpees", category: "Full Body", equipment: .none),
        LibraryExercise(name: "Bear Crawls", category: "Full Body", equipment: .none),
        LibraryExercise(name: "Sprawls", category: "Full Body", equipment: .none),
        LibraryExercise(name: "Froggers", category: "Full Body", equipment: .none),
        LibraryExercise(name: "Inchworm to Push-up", category: "Full Body", equipment: .none),
        LibraryExercise(name: "Lunge with Twist", category: "Full Body", equipment: .none),
        LibraryExercise(name: "Plank Jacks", category: "Full Body", equipment: .none),
        LibraryExercise(name: "Cross-body Mountain Climbers", category: "Full Body", equipment: .none),
        // Full Body - Equipment
        LibraryExercise(name: "Thrusters", category: "Full Body", equipment: .dumbbells),
        LibraryExercise(name: "Man Makers", category: "Full Body", equipment: .dumbbells),
        LibraryExercise(name: "Devil Press", category: "Full Body", equipment: .dumbbells),
        LibraryExercise(name: "Turkish Get-ups", category: "Full Body", equipment: .kettlebell),
        LibraryExercise(name: "Squat to Press", category: "Full Body", equipment: .dumbbells),
        LibraryExercise(name: "Kettlebell Swings", category: "Full Body", equipment: .kettlebell),

        // Stretching/Mobility - No Equipment
        LibraryExercise(name: "Cat-Cow Stretch", category: "Stretching", equipment: .none),
        LibraryExercise(name: "Child's Pose", category: "Stretching", equipment: .none),
        LibraryExercise(name: "Downward Dog", category: "Stretching", equipment: .none),
        LibraryExercise(name: "Cobra Stretch", category: "Stretching", equipment: .none),
        LibraryExercise(name: "Pigeon Pose", category: "Stretching", equipment: .none),
        LibraryExercise(name: "Hip Flexor Stretch", category: "Stretching", equipment: .none),
        LibraryExercise(name: "Hamstring Stretch", category: "Stretching", equipment: .none),
        LibraryExercise(name: "Quad Stretch", category: "Stretching", equipment: .none),
        LibraryExercise(name: "Shoulder Stretch", category: "Stretching", equipment: .none),
        LibraryExercise(name: "Chest Stretch", category: "Stretching", equipment: .none),
        LibraryExercise(name: "Tricep Stretch", category: "Stretching", equipment: .none),
        LibraryExercise(name: "Neck Rolls", category: "Stretching", equipment: .none),
        LibraryExercise(name: "Spinal Twist", category: "Stretching", equipment: .none),
        LibraryExercise(name: "World's Greatest Stretch", category: "Stretching", equipment: .none),
        LibraryExercise(name: "90/90 Hip Stretch", category: "Stretching", equipment: .none),
    ]

    static var categories: [String] {
        Array(Set(exercises.map { $0.category })).sorted()
    }

    static var equipmentTypes: [Equipment] {
        Equipment.allCases
    }

    static func filter(category: String? = nil, equipment: Equipment? = nil, search: String = "") -> [LibraryExercise] {
        var results = exercises

        if let category = category {
            results = results.filter { $0.category == category }
        }

        if let equipment = equipment {
            results = results.filter { $0.equipment == equipment }
        }

        if !search.isEmpty {
            results = results.filter {
                $0.name.localizedCaseInsensitiveContains(search) ||
                $0.category.localizedCaseInsensitiveContains(search)
            }
        }

        return results
    }
}
