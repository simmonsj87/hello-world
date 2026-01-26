//
//  WorkoutExercise+CoreDataProperties.swift
//  WorkoutTimer
//
//  Properties and fetch request for WorkoutExercise entity.
//

import Foundation
import CoreData

extension WorkoutExercise {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<WorkoutExercise> {
        return NSFetchRequest<WorkoutExercise>(entityName: "WorkoutExercise")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var duration: Int32
    @NSManaged public var orderIndex: Int16
    @NSManaged public var exercise: Exercise?
    @NSManaged public var workout: Workout?

}

// MARK: - Identifiable Conformance

extension WorkoutExercise: Identifiable {

}

// MARK: - Convenience Properties

extension WorkoutExercise {

    /// The name of the associated exercise.
    public var exerciseName: String {
        exercise?.wrappedName ?? "Unknown Exercise"
    }

    /// The category of the associated exercise.
    public var exerciseCategory: String {
        exercise?.wrappedCategory ?? "Uncategorized"
    }

    /// Formatted duration string (e.g., "0:30" or "1:15").
    public var formattedDuration: String {
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Duration in minutes (rounded).
    public var durationInMinutes: Double {
        Double(duration) / 60.0
    }
}
