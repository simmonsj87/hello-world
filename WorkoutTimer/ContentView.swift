//
//  ContentView.swift
//  WorkoutTimer
//
//  Main content view for the Workout Timer app.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Workout.createdDate, ascending: false)],
        animation: .default
    )
    private var workouts: FetchedResults<Workout>

    var body: some View {
        NavigationView {
            List {
                if workouts.isEmpty {
                    Text("No workouts yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(workouts) { workout in
                        WorkoutRow(workout: workout)
                    }
                    .onDelete(perform: deleteWorkouts)
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addSampleWorkout) {
                        Label("Add Workout", systemImage: "plus")
                    }
                }
            }
        }
    }

    private func addSampleWorkout() {
        withAnimation {
            let workout = Workout(context: viewContext)
            workout.id = UUID()
            workout.name = "New Workout"
            workout.createdDate = Date()

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error saving workout: \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func deleteWorkouts(offsets: IndexSet) {
        withAnimation {
            offsets.map { workouts[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error deleting workout: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workout.wrappedName)
                .font(.headline)
            HStack {
                Text("\(workout.exerciseCount) exercises")
                Text(workout.formattedTotalDuration)
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    }
}
