//
//  WorkoutBuilderView.swift
//  WorkoutTimer
//
//  View for creating and editing workouts with exercise selection and reordering.
//

import SwiftUI
import CoreData

struct WorkoutBuilderView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // Workout being edited (nil for new workout)
    var existingWorkout: Workout?

    @State private var workoutName: String = ""
    @State private var selectedExercises: [SelectedExercise] = []
    @State private var showingExercisePicker = false
    @State private var showingDiscardAlert = false

    private var isEditing: Bool {
        existingWorkout != nil
    }

    private var hasChanges: Bool {
        !workoutName.isEmpty || !selectedExercises.isEmpty
    }

    private var totalDuration: Int {
        selectedExercises.reduce(0) { $0 + $1.duration }
    }

    private var formattedTotalDuration: String {
        let minutes = totalDuration / 60
        let seconds = totalDuration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        NavigationView {
            Form {
                // Workout Name Section
                Section(header: Text("Workout Details")) {
                    TextField("Workout Name", text: $workoutName)
                        .textInputAutocapitalization(.words)

                    if !selectedExercises.isEmpty {
                        HStack {
                            Text("Total Duration")
                            Spacer()
                            Text(formattedTotalDuration)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Exercises Section
                Section(header: exercisesSectionHeader) {
                    if selectedExercises.isEmpty {
                        Button(action: { showingExercisePicker = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                                Text("Add Exercises")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    } else {
                        ForEach($selectedExercises) { $exercise in
                            ExerciseRowView(exercise: $exercise, onDelete: {
                                deleteExercise(exercise)
                            })
                        }
                        .onMove(perform: moveExercises)
                        .onDelete(perform: deleteExercises)

                        Button(action: { showingExercisePicker = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                                Text("Add More Exercises")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }

                // Save Section
                Section {
                    Button(action: saveWorkout) {
                        HStack {
                            Spacer()
                            Text(isEditing ? "Update Workout" : "Save Workout")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedExercises.isEmpty)
                }
            }
            .navigationTitle(isEditing ? "Edit Workout" : "New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasChanges {
                            showingDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                        .disabled(selectedExercises.isEmpty)
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerSheet(selectedExercises: $selectedExercises)
                    .environment(\.managedObjectContext, viewContext)
            }
            .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) { }
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
            .onAppear {
                loadExistingWorkout()
            }
        }
    }

    // MARK: - Section Headers

    private var exercisesSectionHeader: some View {
        HStack {
            Text("Exercises")
            Spacer()
            if !selectedExercises.isEmpty {
                Text("\(selectedExercises.count) exercises")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func loadExistingWorkout() {
        guard let workout = existingWorkout else { return }

        workoutName = workout.wrappedName

        selectedExercises = workout.workoutExercisesArray.compactMap { workoutExercise in
            guard let exercise = workoutExercise.exercise else { return nil }
            return SelectedExercise(
                exercise: exercise,
                duration: Int(workoutExercise.duration)
            )
        }
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        selectedExercises.move(fromOffsets: source, toOffset: destination)
    }

    private func deleteExercises(at offsets: IndexSet) {
        selectedExercises.remove(atOffsets: offsets)
    }

    private func deleteExercise(_ exercise: SelectedExercise) {
        if let index = selectedExercises.firstIndex(where: { $0.id == exercise.id }) {
            selectedExercises.remove(at: index)
        }
    }

    private func saveWorkout() {
        let trimmedName = workoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !selectedExercises.isEmpty else { return }

        withAnimation {
            let workout: Workout
            if let existing = existingWorkout {
                workout = existing
                // Remove old workout exercises
                for workoutExercise in workout.workoutExercisesArray {
                    viewContext.delete(workoutExercise)
                }
            } else {
                workout = Workout(context: viewContext)
                workout.id = UUID()
                workout.createdDate = Date()
            }

            workout.name = trimmedName

            // Create new workout exercises
            for (index, selectedExercise) in selectedExercises.enumerated() {
                let workoutExercise = WorkoutExercise(context: viewContext)
                workoutExercise.id = UUID()
                workoutExercise.duration = Int32(selectedExercise.duration)
                workoutExercise.orderIndex = Int16(index)
                workoutExercise.exercise = selectedExercise.exercise
                workoutExercise.workout = workout
            }

            do {
                try viewContext.save()
                dismiss()
            } catch {
                let nsError = error as NSError
                print("Error saving workout: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

// MARK: - Selected Exercise Model

struct SelectedExercise: Identifiable, Equatable {
    let id = UUID()
    let exercise: Exercise
    var duration: Int

    init(exercise: Exercise, duration: Int = 30) {
        self.exercise = exercise
        self.duration = duration
    }

    static func == (lhs: SelectedExercise, rhs: SelectedExercise) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Exercise Row View

struct ExerciseRowView: View {
    @Binding var exercise: SelectedExercise
    var onDelete: () -> Void

    private var formattedDuration: String {
        let minutes = exercise.duration / 60
        let seconds = exercise.duration % 60
        if minutes > 0 {
            return "\(minutes):\(String(format: "%02d", seconds))"
        } else {
            return "\(seconds) sec"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Drag Handle
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
                .font(.caption)

            // Exercise Info
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.exercise.wrappedName)
                    .font(.headline)
                Text(exercise.exercise.wrappedCategory)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Duration Stepper
            HStack(spacing: 8) {
                Button(action: {
                    if exercise.duration > 15 {
                        exercise.duration -= 15
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(exercise.duration <= 15 ? .gray : .accentColor)
                }
                .buttonStyle(.borderless)
                .disabled(exercise.duration <= 15)

                Text(formattedDuration)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .frame(minWidth: 50)

                Button(action: {
                    if exercise.duration < 300 {
                        exercise.duration += 15
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(exercise.duration >= 300 ? .gray : .accentColor)
                }
                .buttonStyle(.borderless)
                .disabled(exercise.duration >= 300)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

struct WorkoutBuilderView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutBuilderView()
            .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    }
}
