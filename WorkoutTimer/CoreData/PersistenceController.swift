//
//  PersistenceController.swift
//  WorkoutTimer
//
//  Core Data stack configuration for the Workout Timer app.
//

import CoreData

struct PersistenceController {

    // MARK: - Shared Instance

    static let shared = PersistenceController()

    // MARK: - Preview Instance

    /// A preview instance for SwiftUI previews with sample data.
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext

        // Create default categories
        let defaultCategories = Category.defaultCategoryNames
        for (index, categoryName) in defaultCategories.enumerated() {
            let category = Category(context: viewContext)
            category.id = UUID()
            category.name = categoryName
            category.isDefault = true
            category.orderIndex = Int16(index)
            category.createdDate = Date()
        }

        // Add a custom category
        let customCategory = Category(context: viewContext)
        customCategory.id = UUID()
        customCategory.name = "Flexibility"
        customCategory.isDefault = false
        customCategory.orderIndex = Int16(defaultCategories.count)
        customCategory.createdDate = Date()

        // Create sample exercises with new categories
        let exercises = [
            ("Push-ups", "Upper Body"),
            ("Bench Press", "Upper Body"),
            ("Pull-ups", "Upper Body"),
            ("Squats", "Lower Body"),
            ("Lunges", "Lower Body"),
            ("Deadlifts", "Lower Body"),
            ("Plank", "Core"),
            ("Crunches", "Core"),
            ("Jumping Jacks", "Cardio"),
            ("Running", "Cardio"),
            ("Burpees", "Full Body"),
            ("Mountain Climbers", "Full Body"),
            ("Yoga Stretch", "Flexibility")
        ]

        var sampleExercises: [Exercise] = []
        for (name, category) in exercises {
            let exercise = Exercise(context: viewContext)
            exercise.id = UUID()
            exercise.name = name
            exercise.category = category
            exercise.createdDate = Date()
            sampleExercises.append(exercise)
        }

        // Create a sample workout
        let workout = Workout(context: viewContext)
        workout.id = UUID()
        workout.name = "Morning Routine"
        workout.createdDate = Date()

        // Add exercises to workout
        for (index, exercise) in sampleExercises.prefix(3).enumerated() {
            let workoutExercise = WorkoutExercise(context: viewContext)
            workoutExercise.id = UUID()
            workoutExercise.duration = Int32([30, 45, 60].randomElement()!)
            workoutExercise.orderIndex = Int16(index)
            workoutExercise.exercise = exercise
            workoutExercise.workout = workout
        }

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }

        return controller
    }()

    // MARK: - Core Data Container

    let container: NSPersistentContainer

    // MARK: - Initialization

    /// Initializes the Core Data stack.
    /// - Parameter inMemory: If `true`, uses an in-memory store (useful for previews and testing).
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "WorkoutTimer")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                /*
                 Common reasons for failure:
                 - The parent directory doesn't exist or isn't writable.
                 - The persistent store isn't accessible due to permissions or data protection.
                 - The device is out of space.
                 - The store couldn't be migrated to the current model version.

                 In production, handle this gracefully instead of crashing.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        // Automatically merge changes from parent context
        container.viewContext.automaticallyMergesChangesFromParent = true

        // Set merge policy to prefer in-memory changes
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Convenience Properties

    /// The main view context for UI operations.
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    // MARK: - Save Context

    /// Saves the view context if there are changes.
    func save() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    // MARK: - Background Context

    /// Creates a new background context for performing work off the main thread.
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    /// Performs a task on a background context.
    /// - Parameter block: The work to perform.
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask(block)
    }
}
