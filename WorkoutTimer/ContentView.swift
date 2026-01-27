//
//  ContentView.swift
//  WorkoutTimer
//
//  Main content view for the Workout Timer app with tab navigation.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        TabView {
            WorkoutListView()
                .tabItem {
                    Label("Workouts", systemImage: "figure.run")
                }

            ExerciseListView()
                .tabItem {
                    Label("Exercises", systemImage: "list.bullet")
                }
        }
        .onAppear {
            Category.createDefaultCategories(in: viewContext)
        }
    }
}

struct WorkoutListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Workout.createdDate, ascending: false)],
        animation: .default
    )
    private var workouts: FetchedResults<Workout>

    var body: some View {
        NavigationView {
            Group {
                if workouts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No Workouts Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Tap the + button to create your first workout")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(workouts) { workout in
                            WorkoutRow(workout: workout)
                        }
                        .onDelete(perform: deleteWorkouts)
                    }
                    .listStyle(.insetGrouped)
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
