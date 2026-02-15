//
//  Workout+CoreDataProperties.swift
//  WorkoutTimer
//
//  Properties and fetch request for Workout entity.
//

import Foundation
import CoreData

extension Workout {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Workout> {
        return NSFetchRequest<Workout>(entityName: "Workout")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var createdDate: Date?
    @NSManaged public var rounds: Int16
    @NSManaged public var timePerExercise: Int32
    @NSManaged public var restBetweenExercises: Int32
    @NSManaged public var restBetweenRounds: Int32
    @NSManaged public var executionMode: String?
    @NSManaged public var workoutExercises: NSSet?

}

// MARK: - Generated Accessors for workoutExercises

extension Workout {

    @objc(addWorkoutExercisesObject:)
    @NSManaged public func addToWorkoutExercises(_ value: WorkoutExercise)

    @objc(removeWorkoutExercisesObject:)
    @NSManaged public func removeFromWorkoutExercises(_ value: WorkoutExercise)

    @objc(addWorkoutExercises:)
    @NSManaged public func addToWorkoutExercises(_ values: NSSet)

    @objc(removeWorkoutExercises:)
    @NSManaged public func removeFromWorkoutExercises(_ values: NSSet)

}

// MARK: - Identifiable Conformance

extension Workout: Identifiable {

}

// MARK: - Convenience Properties

extension Workout {

    /// Unwrapped name with a default value.
    public var wrappedName: String {
        name ?? "Unnamed Workout"
    }

    /// Unwrapped created date with a default value.
    public var wrappedCreatedDate: Date {
        createdDate ?? Date()
    }

    /// Sorted array of workout exercises by order index.
    public var workoutExercisesArray: [WorkoutExercise] {
        let set = workoutExercises as? Set<WorkoutExercise> ?? []
        return set.sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Total duration of the workout in seconds.
    public var totalDuration: Int32 {
        workoutExercisesArray.reduce(0) { $0 + $1.duration }
    }

    /// Formatted total duration string (e.g., "5:30").
    /// Uses calculatedTotalDuration which accounts for rounds, rest periods, and warmup.
    public var formattedTotalDuration: String {
        let total = calculatedTotalDuration
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Number of exercises in the workout.
    public var exerciseCount: Int {
        workoutExercisesArray.count
    }

    /// Unwrapped execution mode with a default value.
    public var wrappedExecutionMode: String {
        executionMode ?? "sequential"
    }

    /// Whether this workout uses round-robin execution.
    public var isRoundRobin: Bool {
        wrappedExecutionMode == "roundRobin"
    }

    /// Warmup duration in minutes (stored in UserDefaults since CoreData schema hasn't been migrated)
    public var warmupDuration: Int32 {
        get {
            guard let workoutId = id else { return 0 }
            return Int32(UserDefaults.standard.integer(forKey: "workout_warmup_\(workoutId.uuidString)"))
        }
        set {
            guard let workoutId = id else { return }
            UserDefaults.standard.set(Int(newValue), forKey: "workout_warmup_\(workoutId.uuidString)")
        }
    }

    /// Calculated total workout duration based on settings.
    public var calculatedTotalDuration: Int32 {
        let warmupTime = warmupDuration * 60  // Convert minutes to seconds
        let exerciseTime = timePerExercise * Int32(workoutExercisesArray.count)
        let restTime = restBetweenExercises * Int32(max(0, workoutExercisesArray.count - 1))
        let roundTime = exerciseTime + restTime
        let totalRoundTime = roundTime * Int32(rounds)
        let roundRestTime = restBetweenRounds * Int32(max(0, Int(rounds) - 1))
        return warmupTime + totalRoundTime + roundRestTime
    }

    /// Formatted calculated duration string.
    public var formattedCalculatedDuration: String {
        let total = calculatedTotalDuration
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
