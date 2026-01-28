//
//  Exercise+CoreDataProperties.swift
//  WorkoutTimer
//
//  Properties and fetch request for Exercise entity.
//

import Foundation
import CoreData

extension Exercise {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Exercise> {
        return NSFetchRequest<Exercise>(entityName: "Exercise")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var category: String?
    @NSManaged public var createdDate: Date?
    @NSManaged public var isEnabled: Bool
    @NSManaged public var workoutExercises: NSSet?

}

// MARK: - Generated Accessors for workoutExercises

extension Exercise {

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

extension Exercise: Identifiable {

}

// MARK: - Convenience Properties

extension Exercise {

    /// Unwrapped name with a default value.
    public var wrappedName: String {
        name ?? "Unknown Exercise"
    }

    /// Unwrapped category with a default value.
    public var wrappedCategory: String {
        category ?? "Uncategorized"
    }

    /// Unwrapped created date with a default value.
    public var wrappedCreatedDate: Date {
        createdDate ?? Date()
    }

    /// Sorted array of workout exercises using this exercise.
    public var workoutExercisesArray: [WorkoutExercise] {
        let set = workoutExercises as? Set<WorkoutExercise> ?? []
        return set.sorted { $0.orderIndex < $1.orderIndex }
    }
}
