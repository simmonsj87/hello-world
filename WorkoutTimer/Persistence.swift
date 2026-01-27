//
//  Persistence.swift
//  WorkoutTimer
//
//  Core Data stack for the Workout Timer app.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // Create sample exercises
        let exercises = [
            ("Push-ups", "Strength"),
            ("Squats", "Strength"),
            ("Plank", "Core"),
            ("Jumping Jacks", "Cardio"),
            ("Rest", "Recovery")
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
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "WorkoutTimer")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }
}
