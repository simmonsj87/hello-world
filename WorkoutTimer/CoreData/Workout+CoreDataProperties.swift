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
    public var formattedTotalDuration: String {
        let minutes = totalDuration / 60
        let seconds = totalDuration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Number of exercises in the workout.
    public var exerciseCount: Int {
        workoutExercisesArray.count
    }
}
