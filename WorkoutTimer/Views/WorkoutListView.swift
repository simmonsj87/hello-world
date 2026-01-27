//
//  WorkoutListView.swift
//  WorkoutTimer
//
//  View displaying all workouts with start, edit, and delete functionality.
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
    @State private var showingRandomGenerator = false
    @State private var workoutToEdit: Workout?
    @State private var workoutToRun: Workout?

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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingRandomGenerator = true }) {
                        Label("Random", systemImage: "shuffle")
                    }
                }

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
            .sheet(isPresented: $showingRandomGenerator) {
                RandomWorkoutGeneratorView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(item: $workoutToEdit) { workout in
                WorkoutBuilderView(existingWorkout: workout)
                    .environment(\.managedObjectContext, viewContext)
            }
            .fullScreenCover(item: $workoutToRun) { workout in
                WorkoutExecutionView(workout: workout)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.run")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Workouts Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Create a custom workout or generate a random one")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button(action: { showingWorkoutBuilder = true }) {
                    Label("Create", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .padding()
                        .frame(minWidth: 120)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button(action: { showingRandomGenerator = true }) {
                    Label("Random", systemImage: "shuffle")
                        .font(.headline)
                        .padding()
                        .frame(minWidth: 120)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding(.top, 8)
        }
        .padding()
    }

    // MARK: - Workout List Content

    private var workoutListContent: some View {
        List {
            ForEach(workouts) { workout in
                WorkoutRowWithActions(
                    workout: workout,
                    onStart: { workoutToRun = workout },
                    onEdit: { workoutToEdit = workout }
                )
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

// MARK: - Workout Row With Actions

struct WorkoutRowWithActions: View {
    @ObservedObject var workout: Workout
    let onStart: () -> Void
    let onEdit: () -> Void

    private var canStart: Bool {
        workout.exerciseCount > 0
    }

    var body: some View {
        HStack(spacing: 12) {
            // Start button
            Button(action: onStart) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(canStart ? .green : .gray)
            }
            .buttonStyle(.plain)
            .disabled(!canStart)

            // Workout info
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.wrappedName)
                    .font(.headline)

                HStack(spacing: 12) {
                    Label("\(workout.exerciseCount) exercises", systemImage: "figure.mixed.cardio")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Label(workout.formattedTotalDuration, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if !canStart {
                    Text("Add exercises to start")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            // Edit button
            Button(action: onEdit) {
                Image(systemName: "pencil.circle")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

struct WorkoutListView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutListView()
            .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    }
}
