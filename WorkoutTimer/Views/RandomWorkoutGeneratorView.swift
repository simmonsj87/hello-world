//
//  RandomWorkoutGeneratorView.swift
//  WorkoutTimer
//
//  View for generating random workouts based on user criteria.
//

import SwiftUI
import CoreData

struct RandomWorkoutGeneratorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Exercise.name, ascending: true)],
        animation: .default
    )
    private var allExercises: FetchedResults<Exercise>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Workout.createdDate, ascending: false)],
        predicate: nil,
        animation: .default
    )
    private var recentWorkouts: FetchedResults<Workout>

    // MARK: - State

    @State private var useDuration = false
    @State private var targetDuration: Int = 20 // minutes
    @State private var targetExerciseCount: Int = 8

    // Category distribution
    @State private var upperBodyCount: Int = 2
    @State private var lowerBodyCount: Int = 2
    @State private var coreCount: Int = 2
    @State private var cardioCount: Int = 1
    @State private var fullBodyCount: Int = 1

    // Exercise settings
    @State private var exerciseDuration: Int = 30
    @State private var restBetweenExercises: Int = 15
    @State private var restBetweenRounds: Int = 60
    @State private var avoidRecentExercises = true

    // Rounds and execution mode
    @State private var rounds: Int = 1
    @State private var executionMode: ExecutionMode = .roundRobin

    // Generated workout
    @State private var generatedExercises: [GeneratedExercise] = []
    @State private var showingPreview = false
    @State private var workoutName = ""
    @State private var showingSaveSheet = false
    @State private var showingError = false
    @State private var errorMessage = ""

    // Navigation
    @State private var workoutToRun: Workout?

    // MARK: - Computed Properties

    private var totalExercisesFromCategories: Int {
        upperBodyCount + lowerBodyCount + coreCount + cardioCount + fullBodyCount
    }

    private var totalWorkoutTime: Int {
        guard !generatedExercises.isEmpty else { return 0 }
        let exerciseTime = generatedExercises.count * exerciseDuration
        let exerciseRestTime = max(0, generatedExercises.count - 1) * restBetweenExercises
        let roundTime = exerciseTime + exerciseRestTime
        let totalRoundTime = roundTime * rounds
        let roundRestTime = max(0, rounds - 1) * restBetweenRounds
        return totalRoundTime + roundRestTime
    }

    private var formattedTotalTime: String {
        let minutes = totalWorkoutTime / 60
        let seconds = totalWorkoutTime % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var categoryDistribution: [(String, Int)] {
        [
            ("Upper Body", upperBodyCount),
            ("Lower Body", lowerBodyCount),
            ("Core", coreCount),
            ("Cardio", cardioCount),
            ("Full Body", fullBodyCount)
        ].filter { $0.1 > 0 }
    }

    var body: some View {
        NavigationView {
            Form {
                if !showingPreview {
                    configurationSections
                } else {
                    previewSection
                }
            }
            .navigationTitle(showingPreview ? "Generated Workout" : "Random Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if showingPreview {
                        Button("Back") {
                            withAnimation {
                                showingPreview = false
                            }
                        }
                    } else {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if !showingPreview {
                        Button("Generate") {
                            generateWorkout()
                        }
                        .disabled(totalExercisesFromCategories == 0 && !useDuration)
                    }
                }
            }
            .sheet(isPresented: $showingSaveSheet) {
                SaveWorkoutSheet(
                    workoutName: $workoutName,
                    onSave: saveWorkout,
                    onCancel: { showingSaveSheet = false }
                )
            }
            .fullScreenCover(item: $workoutToRun) { workout in
                WorkoutExecutionView(workout: workout)
                    .environment(\.managedObjectContext, viewContext)
            }
            .alert("Generation Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Configuration Sections

    private var configurationSections: some View {
        Group {
            // Category Distribution (Number of Exercises) - First
            Section {
                CategoryStepperRow(title: "Upper Body", count: $upperBodyCount, available: exerciseCount(for: "Upper Body"))
                CategoryStepperRow(title: "Lower Body", count: $lowerBodyCount, available: exerciseCount(for: "Lower Body"))
                CategoryStepperRow(title: "Core", count: $coreCount, available: exerciseCount(for: "Core"))
                CategoryStepperRow(title: "Cardio", count: $cardioCount, available: exerciseCount(for: "Cardio"))
                CategoryStepperRow(title: "Full Body", count: $fullBodyCount, available: exerciseCount(for: "Full Body"))

                HStack {
                    Text("Total Exercises")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(totalExercisesFromCategories)")
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                }
            } header: {
                Text("Number of Exercises")
            } footer: {
                Text("Select how many exercises from each category.")
            }

            // Duration vs Count Toggle - Second
            Section {
                Toggle("Use Target Duration", isOn: $useDuration)

                if useDuration {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Target Duration")
                            Spacer()
                            Text("\(targetDuration) min")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(targetDuration) },
                            set: { targetDuration = Int($0) }
                        ), in: 5...60, step: 5)
                    }
                }
            } header: {
                Text("Workout Length")
            } footer: {
                if useDuration {
                    Text("Rounds and timing will be adjusted to fit the target duration.")
                }
            }

            // Execution Mode and Rounds/Sets
            Section {
                // Execution Mode - First so user picks mode before sets/rounds
                Picker("Execution Mode", selection: $executionMode) {
                    Text("Round Robin").tag(ExecutionMode.roundRobin)
                    Text("Sequential").tag(ExecutionMode.sequential)
                }
                .pickerStyle(.segmented)

                // Rounds/Sets - Label changes based on mode
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(executionMode == .sequential ? "Sets" : "Rounds")
                        Spacer()
                        Text("\(rounds)")
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                    }

                    HStack(spacing: 8) {
                        ForEach([1, 2, 3, 4, 5], id: \.self) { num in
                            Button(action: { rounds = num }) {
                                Text("\(num)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(rounds == num ? Color.accentColor : Color(.tertiarySystemBackground))
                                    .foregroundColor(rounds == num ? .white : .primary)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

            } header: {
                Text("Execution Mode")
            } footer: {
                if executionMode == .roundRobin {
                    Text("Round Robin: Cycle through all exercises, then repeat for each round.")
                } else {
                    Text("Sequential: Complete all sets of each exercise before moving to the next. Rest between exercises, then rest before repeating the circuit.")
                }
            }

            // Timing Settings
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Time Per Exercise")
                        Spacer()
                        Text("\(exerciseDuration) sec")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(exerciseDuration) },
                        set: { exerciseDuration = Int($0) }
                    ), in: 15...300, step: 15)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Rest Between Exercises")
                        Spacer()
                        Text(restBetweenExercises == 0 ? "None" : "\(restBetweenExercises) sec")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(restBetweenExercises) },
                        set: { restBetweenExercises = Int($0) }
                    ), in: 0...120, step: 5)
                }

                if rounds > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(executionMode == .sequential ? "Rest Between Sets" : "Rest Between Rounds")
                            Spacer()
                            Text(restBetweenRounds == 0 ? "None" : "\(restBetweenRounds) sec")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(restBetweenRounds) },
                            set: { restBetweenRounds = Int($0) }
                        ), in: 0...180, step: 15)
                    }
                }
            } header: {
                Text("Timing")
            }

            // Additional Options
            Section {
                Toggle("Avoid Recent Exercises", isOn: $avoidRecentExercises)
            } header: {
                Text("Options")
            } footer: {
                Text("When enabled, exercises from your last 3 workouts won't be included.")
            }

            // Exercise Database Info
            Section {
                HStack {
                    Text("Total Exercises in Database")
                    Spacer()
                    Text("\(allExercises.filter { $0.isEnabled }.count)")
                        .foregroundColor(.secondary)
                }

                if allExercises.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Add exercises first in the Exercises tab")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Database")
            }
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        Group {
            // Summary
            Section {
                HStack {
                    Label("Exercises", systemImage: "figure.mixed.cardio")
                    Spacer()
                    Text("\(generatedExercises.count)")
                        .fontWeight(.semibold)
                }

                HStack {
                    Label(executionMode == .sequential ? "Sets" : "Rounds", systemImage: "repeat")
                    Spacer()
                    Text("\(rounds)")
                        .fontWeight(.semibold)
                }

                HStack {
                    Label("Mode", systemImage: executionMode == .roundRobin ? "arrow.triangle.2.circlepath" : "arrow.down.circle")
                    Spacer()
                    Text(executionMode == .roundRobin ? "Round Robin" : "Sequential")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Label("Total Time", systemImage: "clock")
                    Spacer()
                    Text(formattedTotalTime)
                        .fontWeight(.semibold)
                }

                HStack {
                    Label("Per Exercise", systemImage: "timer")
                    Spacer()
                    Text("\(exerciseDuration)s")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Label("Rest (Exercises)", systemImage: "pause.circle")
                    Spacer()
                    Text(restBetweenExercises == 0 ? "None" : "\(restBetweenExercises)s")
                        .foregroundColor(.secondary)
                }

                if rounds > 1 {
                    HStack {
                        Label(executionMode == .sequential ? "Rest (Sets)" : "Rest (Rounds)", systemImage: "arrow.counterclockwise")
                        Spacer()
                        Text(restBetweenRounds == 0 ? "None" : "\(restBetweenRounds)s")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Workout Summary")
            }

            // Exercise List
            Section {
                ForEach(Array(generatedExercises.enumerated()), id: \.element.id) { index, exercise in
                    GeneratedExerciseRow(
                        index: index + 1,
                        exercise: exercise,
                        duration: exerciseDuration
                    )
                }
                .onMove(perform: moveExercises)
                .onDelete(perform: deleteExercises)
            } header: {
                HStack {
                    Text("Exercises")
                    Spacer()
                    EditButton()
                        .font(.caption)
                }
            }

            // Action Buttons
            Section {
                Button(action: generateWorkout) {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                }

                Button(action: { showingSaveSheet = true }) {
                    Label("Save Workout", systemImage: "square.and.arrow.down")
                }
                .disabled(generatedExercises.isEmpty)

                Button(action: saveAndStartWorkout) {
                    Label("Start Now", systemImage: "play.circle.fill")
                        .foregroundColor(.green)
                }
                .disabled(generatedExercises.isEmpty)
            }
        }
    }

    // MARK: - Helper Methods

    private func exerciseCount(for category: String) -> Int {
        allExercises.filter { $0.category == category && $0.isEnabled }.count
    }

    private func getRecentExerciseIds() -> Set<UUID> {
        guard avoidRecentExercises else { return [] }

        var recentIds = Set<UUID>()
        let workoutsToCheck = Array(recentWorkouts.prefix(3))

        for workout in workoutsToCheck {
            for workoutExercise in workout.workoutExercisesArray {
                if let exerciseId = workoutExercise.exercise?.id {
                    recentIds.insert(exerciseId)
                }
            }
        }

        return recentIds
    }

    // MARK: - Generation Algorithm

    private func generateWorkout() {
        let recentIds = getRecentExerciseIds()

        // Build available exercises per category (only enabled exercises)
        var availableByCategory: [String: [Exercise]] = [:]
        for exercise in allExercises {
            guard exercise.isEnabled else { continue }
            guard let id = exercise.id, !recentIds.contains(id) else { continue }
            let category = exercise.wrappedCategory
            availableByCategory[category, default: []].append(exercise)
        }

        // Determine target counts
        var targetCounts: [(String, Int)]
        if useDuration {
            targetCounts = calculateCountsForDuration(availableByCategory: availableByCategory)
        } else {
            targetCounts = categoryDistribution
        }

        // Select random exercises
        var selected: [GeneratedExercise] = []
        var usedIds = Set<UUID>()

        for (category, count) in targetCounts {
            guard let available = availableByCategory[category] else { continue }

            // Filter out already used exercises
            let eligible = available.filter { exercise in
                guard let id = exercise.id else { return false }
                return !usedIds.contains(id)
            }

            // Randomly select up to count exercises
            let shuffled = eligible.shuffled()
            let toSelect = min(count, shuffled.count)

            for i in 0..<toSelect {
                let exercise = shuffled[i]
                if let id = exercise.id {
                    usedIds.insert(id)
                    selected.append(GeneratedExercise(exercise: exercise))
                }
            }
        }

        // Check if we got enough exercises
        if selected.isEmpty {
            if recentIds.isEmpty {
                errorMessage = "No exercises found in the database. Please add exercises in the Exercises tab first."
            } else {
                errorMessage = "Not enough exercises available. Try disabling 'Avoid Recent Exercises' or adding more exercises to the database."
            }
            showingError = true
            return
        }

        // Shuffle the final list for variety
        generatedExercises = selected.shuffled()

        // If using target duration, adjust rounds, exercise time, and rest to fit
        if useDuration {
            adjustTimingsForTargetDuration()
        }

        withAnimation {
            showingPreview = true
        }
    }

    private func adjustTimingsForTargetDuration() {
        guard !generatedExercises.isEmpty else { return }

        let targetTimeSeconds = targetDuration * 60
        let exerciseCount = generatedExercises.count

        // Calculate time for a single round using user-configured exercise duration and rest
        let singleRoundExerciseTime = exerciseCount * exerciseDuration
        let singleRoundRestTime = max(0, exerciseCount - 1) * restBetweenExercises
        let singleRoundTime = singleRoundExerciseTime + singleRoundRestTime

        // Find the best number of rounds to match the target duration
        var bestRounds = 1
        var closestDiff = Int.max

        for testRounds in 1...20 {
            let totalTime = singleRoundTime * testRounds + max(0, testRounds - 1) * restBetweenRounds
            let diff = abs(totalTime - targetTimeSeconds)

            if diff < closestDiff {
                closestDiff = diff
                bestRounds = testRounds
            }
        }

        // Only adjust rounds - keep user-configured exercise duration and rest times
        rounds = bestRounds
    }

    private func calculateCountsForDuration(availableByCategory: [String: [Exercise]]) -> [(String, Int)] {
        // When using target duration, use the FULL category distribution
        // We will adjust timings (rounds, exercise duration, rest) to fit the target duration
        // instead of reducing the number of exercises

        let totalRequested = totalExercisesFromCategories
        guard totalRequested > 0 else {
            // If no distribution set, distribute evenly across available categories
            let availableCategories = availableByCategory.keys.filter { !availableByCategory[$0]!.isEmpty }
            guard !availableCategories.isEmpty else { return [] }
            // Default to 2 exercises per category if no distribution is set
            return availableCategories.map { ($0, 2) }
        }

        // Return the full category distribution - don't scale down
        return categoryDistribution
    }

    // MARK: - Actions

    private func moveExercises(from source: IndexSet, to destination: Int) {
        generatedExercises.move(fromOffsets: source, toOffset: destination)
    }

    private func deleteExercises(at offsets: IndexSet) {
        generatedExercises.remove(atOffsets: offsets)
    }

    private func saveWorkout() {
        let trimmedName = workoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        _ = createWorkout(name: trimmedName)

        do {
            try viewContext.save()
            showingSaveSheet = false
            dismiss()
        } catch {
            print("Error saving workout: \(error)")
        }
    }

    private func saveAndStartWorkout() {
        let defaultName = "Random Workout \(Date().formatted(date: .abbreviated, time: .shortened))"
        let workout = createWorkout(name: defaultName)

        do {
            try viewContext.save()
            workoutToRun = workout
        } catch {
            print("Error saving workout: \(error)")
        }
    }

    private func createWorkout(name: String) -> Workout {
        let workout = Workout(context: viewContext)
        workout.id = UUID()
        workout.name = name
        workout.createdDate = Date()

        // Set workout-level settings
        workout.rounds = Int16(rounds)
        workout.timePerExercise = Int32(exerciseDuration)
        workout.restBetweenExercises = Int32(restBetweenExercises)
        workout.restBetweenRounds = Int32(restBetweenRounds)
        workout.executionMode = executionMode.rawValue

        for (index, generated) in generatedExercises.enumerated() {
            let workoutExercise = WorkoutExercise(context: viewContext)
            workoutExercise.id = UUID()
            workoutExercise.duration = Int32(exerciseDuration)
            workoutExercise.orderIndex = Int16(index)
            workoutExercise.exercise = generated.exercise
            workoutExercise.workout = workout
        }

        return workout
    }
}

// MARK: - Generated Exercise Model

struct GeneratedExercise: Identifiable, Equatable {
    let id = UUID()
    let exercise: Exercise

    static func == (lhs: GeneratedExercise, rhs: GeneratedExercise) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Category Stepper Row

struct CategoryStepperRow: View {
    let title: String
    @Binding var count: Int
    let available: Int
    var maxLimit: Int = 50

    private var canIncrease: Bool {
        count < min(maxLimit, available)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text("\(available) available")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button(action: { if count > 0 { count -= 1 } }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(count > 0 ? .accentColor : .gray)
                }
                .buttonStyle(.plain)
                .disabled(count <= 0)

                Text("\(count)")
                    .font(.headline)
                    .monospacedDigit()
                    .frame(minWidth: 30)

                Button(action: { if canIncrease { count += 1 } }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(canIncrease ? .accentColor : .gray)
                }
                .buttonStyle(.plain)
                .disabled(!canIncrease)
            }
        }
    }
}

// MARK: - Generated Exercise Row

struct GeneratedExerciseRow: View {
    let index: Int
    let exercise: GeneratedExercise
    let duration: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor))

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.exercise.wrappedName)
                    .font(.headline)
                Text(exercise.exercise.wrappedCategory)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(duration)s")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Save Workout Sheet

struct SaveWorkoutSheet: View {
    @Binding var workoutName: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Workout Name", text: $workoutName)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Name Your Workout")
                }

                Section {
                    Button(action: onSave) {
                        HStack {
                            Spacer()
                            Text("Save Workout")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Save Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
            }
            .onAppear {
                if workoutName.isEmpty {
                    workoutName = "Random Workout"
                }
            }
        }
    }
}

// MARK: - Preview

struct RandomWorkoutGeneratorView_Previews: PreviewProvider {
    static var previews: some View {
        RandomWorkoutGeneratorView()
            .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    }
}
