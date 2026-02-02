//
//  WorkoutBuilderView.swift
//  WorkoutTimer
//
//  View for creating and editing workouts with exercise selection and workout-level timing settings.
//

import SwiftUI
import CoreData

struct WorkoutBuilderView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // Workout being edited (nil for new workout)
    var existingWorkout: Workout?

    // Basic Info
    @State private var workoutName: String = ""
    @State private var selectedExercises: [SelectedExercise] = []

    // Workout-level settings
    @State private var rounds: Int = 1
    @State private var timePerExercise: Int = 30
    @State private var restBetweenExercises: Int = 15
    @State private var restBetweenRounds: Int = 60
    @State private var executionMode: ExecutionMode = .sequential

    // UI State
    @State private var showingExercisePicker = false
    @State private var showingDiscardAlert = false

    private var isEditing: Bool {
        existingWorkout != nil
    }

    private var hasChanges: Bool {
        !workoutName.isEmpty || !selectedExercises.isEmpty
    }

    private var totalDuration: Int {
        guard !selectedExercises.isEmpty else { return 0 }
        let exerciseTime = selectedExercises.count * timePerExercise
        let exerciseRestTime = max(0, selectedExercises.count - 1) * restBetweenExercises
        let roundTime = exerciseTime + exerciseRestTime
        let totalRoundTime = roundTime * rounds
        let roundRestTime = max(0, rounds - 1) * restBetweenRounds
        return totalRoundTime + roundRestTime
    }

    private var formattedTotalDuration: String {
        let minutes = totalDuration / 60
        let seconds = totalDuration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Workout Name Section
                    nameSection

                    // Timing Settings Section
                    timingSection

                    // Execution Mode Section
                    executionModeSection

                    // Exercises Section
                    exercisesSection

                    // Save Button
                    saveSection
                }
                .padding()
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

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WORKOUT NAME")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            TextField("Enter workout name", text: $workoutName)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Timing Section

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TIMING SETTINGS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            // Rounds
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Rounds", systemImage: "repeat")
                    Spacer()
                    Text("\(rounds)")
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                }

                HStack(spacing: 12) {
                    ForEach([1, 2, 3, 4, 5], id: \.self) { num in
                        Button(action: { rounds = num }) {
                            Text("\(num)")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(rounds == num ? Color.accentColor : Color(.tertiarySystemBackground))
                                .foregroundColor(rounds == num ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }

                Stepper("Custom: \(rounds)", value: $rounds, in: 1...20)
                    .font(.caption)
            }

            Divider()

            // Time Per Exercise
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Time Per Exercise", systemImage: "timer")
                    Spacer()
                    Text("\(timePerExercise) sec")
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }

                Slider(value: Binding(
                    get: { Double(timePerExercise) },
                    set: { timePerExercise = Int($0) }
                ), in: 10...300, step: 5)

                HStack {
                    Text("10s")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("5 min")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Rest Between Exercises
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Rest Between Exercises", systemImage: "pause.circle")
                    Spacer()
                    Text(restBetweenExercises == 0 ? "None" : "\(restBetweenExercises) sec")
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }

                Slider(value: Binding(
                    get: { Double(restBetweenExercises) },
                    set: { restBetweenExercises = Int($0) }
                ), in: 0...120, step: 5)
            }

            Divider()

            // Rest Between Rounds
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Rest Between Rounds", systemImage: "arrow.counterclockwise")
                    Spacer()
                    Text(restBetweenRounds == 0 ? "None" : "\(restBetweenRounds) sec")
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }

                Slider(value: Binding(
                    get: { Double(restBetweenRounds) },
                    set: { restBetweenRounds = Int($0) }
                ), in: 0...180, step: 15)
            }

            // Duration Summary
            if !selectedExercises.isEmpty {
                Divider()

                HStack {
                    Label("Estimated Duration", systemImage: "clock.fill")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(formattedTotalDuration)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Execution Mode Section

    private var executionModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EXECUTION MODE")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                ExecutionModeButton(
                    mode: .sequential,
                    isSelected: executionMode == .sequential,
                    action: { executionMode = .sequential }
                )

                ExecutionModeButton(
                    mode: .roundRobin,
                    isSelected: executionMode == .roundRobin,
                    action: { executionMode = .roundRobin }
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Exercises Section

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("EXERCISES")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()

                if !selectedExercises.isEmpty {
                    Text("\(selectedExercises.count) exercises • Drag to reorder")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if selectedExercises.isEmpty {
                Button(action: { showingExercisePicker = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                        Text("Add Exercises")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundColor(.accentColor)
                    .cornerRadius(12)
                }
            } else {
                List {
                    ForEach(Array(selectedExercises.enumerated()), id: \.element.id) { index, exercise in
                        SimpleExerciseRow(
                            index: index + 1,
                            exercise: exercise,
                            onDelete: { deleteExercise(at: index) }
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color(.tertiarySystemBackground))
                    }
                    .onMove(perform: moveExercise)
                }
                .listStyle(.plain)
                .frame(minHeight: CGFloat(selectedExercises.count * 60))
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(12)
                .environment(\.editMode, .constant(.active))

                Button(action: { showingExercisePicker = true }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add More")
                    }
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func moveExercise(from source: IndexSet, to destination: Int) {
        selectedExercises.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Save Section

    private var saveSection: some View {
        Button(action: saveWorkout) {
            HStack {
                Image(systemName: isEditing ? "checkmark.circle.fill" : "plus.circle.fill")
                Text(isEditing ? "Update Workout" : "Save Workout")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canSave ? Color.accentColor : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canSave)
    }

    private var canSave: Bool {
        !workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selectedExercises.isEmpty
    }

    // MARK: - Actions

    private func loadExistingWorkout() {
        guard let workout = existingWorkout else { return }

        workoutName = workout.wrappedName
        rounds = Int(workout.rounds)
        timePerExercise = Int(workout.timePerExercise)
        restBetweenExercises = Int(workout.restBetweenExercises)
        restBetweenRounds = Int(workout.restBetweenRounds)
        executionMode = workout.isRoundRobin ? .roundRobin : .sequential

        selectedExercises = workout.workoutExercisesArray.compactMap { workoutExercise in
            guard let exercise = workoutExercise.exercise else { return nil }
            return SelectedExercise(exercise: exercise)
        }
    }

    private func deleteExercise(at index: Int) {
        withAnimation {
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
            workout.rounds = Int16(rounds)
            workout.timePerExercise = Int32(timePerExercise)
            workout.restBetweenExercises = Int32(restBetweenExercises)
            workout.restBetweenRounds = Int32(restBetweenRounds)
            workout.executionMode = executionMode.rawValue

            // Create new workout exercises
            for (index, selectedExercise) in selectedExercises.enumerated() {
                let workoutExercise = WorkoutExercise(context: viewContext)
                workoutExercise.id = UUID()
                workoutExercise.duration = Int32(timePerExercise)
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

// MARK: - Execution Mode Enum

enum ExecutionMode: String, CaseIterable {
    case sequential = "sequential"
    case roundRobin = "roundRobin"

    var title: String {
        switch self {
        case .sequential:
            return "Sequential"
        case .roundRobin:
            return "Round Robin"
        }
    }

    var description: String {
        switch self {
        case .sequential:
            return "Complete all rounds of each exercise before moving to the next"
        case .roundRobin:
            return "Cycle through all exercises once per round"
        }
    }

    var icon: String {
        switch self {
        case .sequential:
            return "arrow.down.circle"
        case .roundRobin:
            return "arrow.triangle.2.circlepath"
        }
    }
}

// MARK: - Execution Mode Button

struct ExecutionModeButton: View {
    let mode: ExecutionMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: mode.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .accentColor)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.1))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(mode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.tertiarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Selected Exercise Model

struct SelectedExercise: Identifiable, Equatable {
    let id = UUID()
    let exercise: Exercise

    init(exercise: Exercise) {
        self.exercise = exercise
    }

    static func == (lhs: SelectedExercise, rhs: SelectedExercise) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Simple Exercise Row

struct SimpleExerciseRow: View {
    let index: Int
    let exercise: SelectedExercise
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Number badge
            Text("\(index)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor))

            // Exercise info
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.exercise.wrappedName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(exercise.exercise.wrappedCategory)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Preview

struct WorkoutBuilderView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutBuilderView()
            .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    }
}
