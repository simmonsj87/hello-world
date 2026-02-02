//
//  WorkoutListView.swift
//  WorkoutTimer
//
//  View displaying all workouts with start, edit, and delete functionality.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct WorkoutListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Workout.createdDate, ascending: false)],
        animation: .default
    )
    private var workouts: FetchedResults<Workout>

    @FetchRequest(sortDescriptors: [])
    private var exercises: FetchedResults<Exercise>

    @State private var showingWorkoutBuilder = false
    @State private var showingRandomGenerator = false
    @State private var workoutToEdit: Workout?
    @State private var workoutToRun: Workout?
    @State private var workoutToDelete: Workout?
    @State private var showingDeleteConfirmation = false
    @State private var exportItem: ShareableURL?
    @State private var showingImportPicker = false
    @State private var showingImportSuccess = false
    @State private var showingImportError = false
    @State private var importErrorMessage = ""
    @State private var importedExercisesCount = 0

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
                    HStack(spacing: 16) {
                        Button(action: { showingRandomGenerator = true }) {
                            Image(systemName: "shuffle")
                        }

                        Button(action: { showingImportPicker = true }) {
                            Image(systemName: "square.and.arrow.down")
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingWorkoutBuilder = true }) {
                        Image(systemName: "plus")
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
            .sheet(item: $exportItem) { item in
                ShareSheet(items: [item.url])
            }
            .sheet(isPresented: $showingImportPicker) {
                DocumentPicker(onDocumentPicked: importFromFile)
            }
            .alert("Delete Workout?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let workout = workoutToDelete {
                        deleteWorkout(workout)
                    }
                }
                Button("Cancel", role: .cancel) {
                    workoutToDelete = nil
                }
            } message: {
                if let workout = workoutToDelete {
                    Text("Are you sure you want to delete \"\(workout.wrappedName)\"? This action cannot be undone.")
                }
            }
            .alert("Import Successful", isPresented: $showingImportSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                if importedExercisesCount > 0 {
                    Text("Workout imported successfully. \(importedExercisesCount) new exercise(s) were also added to your library.")
                } else {
                    Text("Workout imported successfully.")
                }
            }
            .alert("Import Failed", isPresented: $showingImportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importErrorMessage)
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
                .contextMenu {
                    Button(action: { workoutToRun = workout }) {
                        Label("Start Workout", systemImage: "play.fill")
                    }
                    .disabled(workout.exerciseCount == 0)

                    Button(action: { exportWorkout(workout) }) {
                        Label("Share Workout", systemImage: "square.and.arrow.up")
                    }

                    Button(action: { workoutToEdit = workout }) {
                        Label("Edit", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive) {
                        workoutToDelete = workout
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        workoutToDelete = workout
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        workoutToEdit = workout
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Actions

    private func deleteWorkout(_ workout: Workout) {
        withAnimation {
            viewContext.delete(workout)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error deleting workout: \(nsError), \(nsError.userInfo)")
            }
        }
        workoutToDelete = nil
    }

    private func exportWorkout(_ workout: Workout) {
        guard let workoutId = workout.id else { return }

        // Gather all exercises used in this workout
        var workoutExercises: [ExerciseExport] = []
        var workoutExerciseExports: [WorkoutExerciseExport] = []

        for we in workout.workoutExercisesArray {
            guard let exercise = we.exercise, let exerciseId = exercise.id else { continue }

            // Add to exercise list if not already there
            if !workoutExercises.contains(where: { $0.id == exerciseId }) {
                workoutExercises.append(ExerciseExport(
                    id: exerciseId,
                    name: exercise.wrappedName,
                    category: exercise.wrappedCategory,
                    createdDate: exercise.wrappedCreatedDate
                ))
            }

            workoutExerciseExports.append(WorkoutExerciseExport(
                exerciseId: exerciseId,
                duration: Int(we.duration),
                orderIndex: Int(we.orderIndex)
            ))
        }

        let exportData = SingleWorkoutExport(
            exportDate: Date(),
            appVersion: "1.0.0",
            workout: WorkoutExport(
                id: workoutId,
                name: workout.wrappedName,
                createdDate: workout.wrappedCreatedDate,
                rounds: Int(workout.rounds),
                timePerExercise: Int(workout.timePerExercise),
                restBetweenExercises: Int(workout.restBetweenExercises),
                restBetweenRounds: Int(workout.restBetweenRounds),
                executionMode: workout.wrappedExecutionMode,
                exercises: workoutExerciseExports
            ),
            exercises: workoutExercises
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(exportData)

            let tempDir = FileManager.default.temporaryDirectory
            let sanitizedName = workout.wrappedName.replacingOccurrences(of: " ", with: "_")
            let fileName = "Workout_\(sanitizedName).json"
            let fileURL = tempDir.appendingPathComponent(fileName)

            try data.write(to: fileURL)
            exportItem = ShareableURL(url: fileURL)
        } catch {
            print("Export error: \(error)")
        }
    }

    private func importFromFile(_ url: URL) {
        do {
            guard url.startAccessingSecurityScopedResource() else {
                importErrorMessage = "Could not access the selected file."
                showingImportError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            if let workoutExport = try? decoder.decode(SingleWorkoutExport.self, from: data) {
                importSingleWorkout(workoutExport)
            } else if let fullExport = try? decoder.decode(AppDataExport.self, from: data) {
                // Full app export - import all workouts
                for workoutExportData in fullExport.workouts {
                    let exercisesForWorkout = fullExport.exercises.filter { ex in
                        workoutExportData.exercises.contains { $0.exerciseId == ex.id }
                    }
                    let singleWorkout = SingleWorkoutExport(
                        exportDate: fullExport.exportDate,
                        appVersion: fullExport.appVersion,
                        workout: workoutExportData,
                        exercises: exercisesForWorkout
                    )
                    importSingleWorkout(singleWorkout)
                }
            } else {
                importErrorMessage = "Invalid file format. Please select a valid workout export file."
                showingImportError = true
            }
        } catch {
            importErrorMessage = "Failed to import: \(error.localizedDescription)"
            showingImportError = true
        }
    }

    private func importSingleWorkout(_ workoutExport: SingleWorkoutExport) {
        // Check if workout already exists by name
        let existingWorkout = workouts.first { $0.wrappedName == workoutExport.workout.name }
        guard existingWorkout == nil else {
            showingImportSuccess = true
            return
        }

        // First, import any missing exercises and create mapping
        var exerciseMapping: [UUID: Exercise] = [:]
        var newExercisesCount = 0

        for exerciseExport in workoutExport.exercises {
            // Check if exercise already exists by name
            if let existingExercise = exercises.first(where: { $0.wrappedName == exerciseExport.name }) {
                exerciseMapping[exerciseExport.id] = existingExercise
            } else {
                // Create new exercise
                let exercise = Exercise(context: viewContext)
                exercise.id = UUID()
                exercise.name = exerciseExport.name
                exercise.category = exerciseExport.category
                exercise.createdDate = exerciseExport.createdDate
                exercise.isEnabled = true
                exerciseMapping[exerciseExport.id] = exercise
                newExercisesCount += 1
            }
        }

        // Create the workout
        let workout = Workout(context: viewContext)
        workout.id = UUID()
        workout.name = workoutExport.workout.name
        workout.createdDate = workoutExport.workout.createdDate
        workout.rounds = Int16(workoutExport.workout.rounds)
        workout.timePerExercise = Int32(workoutExport.workout.timePerExercise)
        workout.restBetweenExercises = Int32(workoutExport.workout.restBetweenExercises)
        workout.restBetweenRounds = Int32(workoutExport.workout.restBetweenRounds)
        workout.executionMode = workoutExport.workout.executionMode

        // Add workout exercises
        for workoutExerciseExport in workoutExport.workout.exercises {
            if let exercise = exerciseMapping[workoutExerciseExport.exerciseId] {
                let workoutExercise = WorkoutExercise(context: viewContext)
                workoutExercise.id = UUID()
                workoutExercise.exercise = exercise
                workoutExercise.workout = workout
                workoutExercise.duration = Int32(workoutExerciseExport.duration)
                workoutExercise.orderIndex = Int16(workoutExerciseExport.orderIndex)
            }
        }

        do {
            try viewContext.save()
            importedExercisesCount = newExercisesCount
            showingImportSuccess = true
        } catch {
            print("Error importing workout: \(error)")
            importErrorMessage = "Failed to save workout: \(error.localizedDescription)"
            showingImportError = true
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

// MARK: - Shareable URL Wrapper

struct ShareableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Preview

struct WorkoutListView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutListView()
            .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    }
}
