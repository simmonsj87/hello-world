# Core Data Setup for WorkoutTimer

This guide explains how to integrate the Core Data model into your iOS workout timer app.

## Project Structure

```
WorkoutTimer/
└── CoreData/
    ├── WorkoutTimer.xcdatamodeld/     # Core Data model
    ├── PersistenceController.swift    # Core Data stack
    ├── Exercise+CoreDataClass.swift
    ├── Exercise+CoreDataProperties.swift
    ├── Workout+CoreDataClass.swift
    ├── Workout+CoreDataProperties.swift
    ├── WorkoutExercise+CoreDataClass.swift
    └── WorkoutExercise+CoreDataProperties.swift
```

## Setup Steps

### 1. Add Files to Xcode Project

1. Open your Xcode project
2. Right-click on your project navigator
3. Select **Add Files to "YourProject"...**
4. Navigate to the `CoreData` folder and select all files
5. Ensure **"Copy items if needed"** is checked
6. Click **Add**

### 2. Configure Your App Entry Point

Update your main App file to inject the Core Data context:

```swift
import SwiftUI

@main
struct WorkoutTimerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.viewContext)
        }
    }
}
```

### 3. Using Core Data in SwiftUI Views

#### Fetching Data with @FetchRequest

```swift
import SwiftUI
import CoreData

struct ExerciseListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Exercise.name, ascending: true)],
        animation: .default
    )
    private var exercises: FetchedResults<Exercise>

    var body: some View {
        List {
            ForEach(exercises) { exercise in
                VStack(alignment: .leading) {
                    Text(exercise.wrappedName)
                        .font(.headline)
                    Text(exercise.wrappedCategory)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .onDelete(perform: deleteExercises)
        }
    }

    private func deleteExercises(offsets: IndexSet) {
        withAnimation {
            offsets.map { exercises[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}
```

#### Creating New Objects

```swift
func addExercise(name: String, category: String) {
    let exercise = Exercise(context: viewContext)
    exercise.id = UUID()
    exercise.name = name
    exercise.category = category
    exercise.createdDate = Date()

    do {
        try viewContext.save()
    } catch {
        print("Error saving exercise: \(error)")
    }
}
```

#### Creating a Workout with Exercises

```swift
func createWorkout(name: String, exercises: [(Exercise, Int32)]) {
    let workout = Workout(context: viewContext)
    workout.id = UUID()
    workout.name = name
    workout.createdDate = Date()

    for (index, (exercise, duration)) in exercises.enumerated() {
        let workoutExercise = WorkoutExercise(context: viewContext)
        workoutExercise.id = UUID()
        workoutExercise.duration = duration
        workoutExercise.orderIndex = Int16(index)
        workoutExercise.exercise = exercise
        workoutExercise.workout = workout
    }

    do {
        try viewContext.save()
    } catch {
        print("Error saving workout: \(error)")
    }
}
```

### 4. SwiftUI Preview Support

Use the preview controller for SwiftUI previews:

```swift
struct ExerciseListView_Previews: PreviewProvider {
    static var previews: some View {
        ExerciseListView()
            .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    }
}
```

## Data Model Overview

### Exercise Entity

| Attribute   | Type   | Description                    |
|-------------|--------|--------------------------------|
| id          | UUID   | Unique identifier              |
| name        | String | Exercise name                  |
| category    | String | Category (Strength, Cardio...) |
| createdDate | Date   | When the exercise was created  |

**Relationships:**
- `workoutExercises` (to-many) → WorkoutExercise

### Workout Entity

| Attribute   | Type   | Description                   |
|-------------|--------|-------------------------------|
| id          | UUID   | Unique identifier             |
| name        | String | Workout name                  |
| createdDate | Date   | When the workout was created  |

**Relationships:**
- `workoutExercises` (to-many, cascade delete) → WorkoutExercise

### WorkoutExercise Entity (Junction Table)

| Attribute  | Type   | Description                    |
|------------|--------|--------------------------------|
| id         | UUID   | Unique identifier              |
| duration   | Int32  | Duration in seconds            |
| orderIndex | Int16  | Position in workout sequence   |

**Relationships:**
- `exercise` (to-one) → Exercise
- `workout` (to-one) → Workout

## Convenience Properties

The entity extensions include helpful computed properties:

### Exercise
- `wrappedName` - Non-optional name
- `wrappedCategory` - Non-optional category
- `workoutExercisesArray` - Sorted array of workout exercises

### Workout
- `wrappedName` - Non-optional name
- `workoutExercisesArray` - Sorted array by order index
- `totalDuration` - Sum of all exercise durations
- `formattedTotalDuration` - "M:SS" format
- `exerciseCount` - Number of exercises

### WorkoutExercise
- `exerciseName` - Name from related exercise
- `exerciseCategory` - Category from related exercise
- `formattedDuration` - "M:SS" format

## Manual .xcdatamodeld Configuration (Alternative)

If you prefer to create the model manually in Xcode:

1. **File → New → File → Data Model**
2. Name it `WorkoutTimer.xcdatamodeld`

3. **Create Exercise Entity:**
   - Click **Add Entity**
   - Name: `Exercise`
   - Add attributes:
     - `id` (UUID)
     - `name` (String)
     - `category` (String)
     - `createdDate` (Date)

4. **Create Workout Entity:**
   - Click **Add Entity**
   - Name: `Workout`
   - Add attributes:
     - `id` (UUID)
     - `name` (String)
     - `createdDate` (Date)

5. **Create WorkoutExercise Entity:**
   - Click **Add Entity**
   - Name: `WorkoutExercise`
   - Add attributes:
     - `id` (UUID)
     - `duration` (Integer 32)
     - `orderIndex` (Integer 16)

6. **Create Relationships:**

   In **Exercise**:
   - Add relationship `workoutExercises`
   - Destination: `WorkoutExercise`
   - Type: To Many
   - Delete Rule: Nullify
   - Inverse: `exercise`

   In **Workout**:
   - Add relationship `workoutExercises`
   - Destination: `WorkoutExercise`
   - Type: To Many
   - Delete Rule: Cascade
   - Inverse: `workout`

   In **WorkoutExercise**:
   - Add relationship `exercise`
   - Destination: `Exercise`
   - Type: To One
   - Inverse: `workoutExercises`

   - Add relationship `workout`
   - Destination: `Workout`
   - Type: To One
   - Inverse: `workoutExercises`

7. **Set Codegen to Manual/None:**
   - Select each entity
   - In the Data Model Inspector, set **Codegen** to **Manual/None**
   - This allows you to use the provided Swift files

## Tips

- Always use `UUID()` when creating new objects
- Set `createdDate = Date()` for new objects
- Use `viewContext.save()` after modifications
- For bulk operations, use `newBackgroundContext()`
- Delete rules: Workout uses Cascade (deletes WorkoutExercises), Exercise uses Nullify
