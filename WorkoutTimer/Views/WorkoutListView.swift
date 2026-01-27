//
//  WorkoutListView.swift
//  WorkoutTimer
//
//  View displaying all workouts with add, edit, and delete functionality.
//

import SwiftUI
import CoreData

struct WorkoutListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Workout.createdDate, ascending: false)],
        animation: .default
    )
    private var workouts: FetchedResults<Workout>

    @State private var showingWorkoutBuilder = false
    @State private var workoutToEdit: Workout?

    var body: some View {
        NavigationView {
            Group {
                if workouts.isEmpty {
                    emptyStateView
                } else {
                    workoutListContent
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingWorkoutBuilder = true }) {
                        Label("Add Workout", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingWorkoutBuilder) {
                WorkoutBuilderView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(item: $workoutToEdit) { workout in
                WorkoutBuilderView(existingWorkout: workout)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
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

            Button(action: { showingWorkoutBuilder = true }) {
                Label("Create Workout", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .padding()
    }

    // MARK: - Workout List Content

    private var workoutListContent: some View {
        List {
            ForEach(workouts) { workout in
                WorkoutRow(workout: workout)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        workoutToEdit = workout
                    }
            }
            .onDelete(perform: deleteWorkouts)
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Actions

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

// MARK: - Workout Row

struct WorkoutRow: View {
    @ObservedObject var workout: Workout

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.wrappedName)
                    .font(.headline)

                HStack(spacing: 12) {
                    Label("\(workout.exerciseCount)", systemImage: "figure.mixed.cardio")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Label(workout.formattedTotalDuration, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

struct WorkoutListView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutListView()
            .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    }
}
