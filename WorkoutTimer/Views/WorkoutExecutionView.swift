//
//  WorkoutExecutionView.swift
//  WorkoutTimer
//
//  View for executing a saved workout with timer and voice announcements.
//  Supports multiple rounds and sequential/round-robin execution modes.
//

import SwiftUI
import CoreData
import UserNotifications

// MARK: - Workout Execution View

struct WorkoutExecutionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    let workout: Workout

    @StateObject private var voiceManager = VoiceAnnouncementManager()
    @StateObject private var executionManager: WorkoutExecutionManager

    @State private var showingEndConfirmation = false

    init(workout: Workout) {
        self.workout = workout
        self._executionManager = StateObject(wrappedValue: WorkoutExecutionManager(workout: workout))
    }

    var body: some View {
        ZStack {
            // Background color based on state
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header (compact)
                headerSection
                    .padding(.horizontal)
                    .padding(.top, 8)

                if executionManager.state == .completed {
                    completedView
                        .padding()
                } else if executionManager.state == .ready {
                    readyStateView
                } else if executionManager.state == .warmup {
                    warmupStateView
                } else {
                    runningStateView
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            setupNotifications()
            executionManager.voiceManager = voiceManager
        }
        .onDisappear {
            executionManager.stop()
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhaseChange(phase)
        }
        .alert("End Workout?", isPresented: $showingEndConfirmation) {
            Button("End", role: .destructive) {
                executionManager.stop()
                dismiss()
            }
            Button("Continue", role: .cancel) { }
        } message: {
            Text("Are you sure you want to end this workout? Your progress will not be saved.")
        }
    }

    // MARK: - Background Color

    private var backgroundColor: Color {
        switch executionManager.state {
        case .ready:
            return Color(.systemBackground)
        case .warmup:
            return Color.orange.opacity(0.2)
        case .countdown:
            return Color.orange.opacity(0.2)
        case .running:
            return Color.green.opacity(0.15)
        case .resting:
            return Color.blue.opacity(0.15)
        case .roundRest:
            return Color.purple.opacity(0.15)
        case .paused:
            return Color.yellow.opacity(0.15)
        case .completed:
            return Color.purple.opacity(0.15)
        }
    }

    // MARK: - Header Section (Compact)

    private var headerSection: some View {
        HStack {
            Button(action: { showingEndConfirmation = true }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(spacing: 0) {
                Text(workout.wrappedName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(executionManager.stateDisplayText)
                    .font(.caption2)
                    .foregroundColor(stateColor)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text(executionManager.formattedElapsedTime)
                    .font(.caption)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Ready State View

    private var readyStateView: some View {
        VStack(spacing: 16) {
            // Timer circle at top
            ZStack {
                Circle()
                    .stroke(lineWidth: 12)
                    .opacity(0.2)
                    .foregroundColor(.gray)

                Text(executionManager.formattedTimeRemaining)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.primary)
            }
            .frame(width: 160, height: 160)
            .padding(.top, 8)

            // START Button
            Button(action: { executionManager.start() }) {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.title2)
                    Text("START")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.green)
                .cornerRadius(16)
            }
            .padding(.horizontal, 24)

            // Workout Summary Section
            workoutSummarySection
                .padding(.horizontal)

            // Exercise List Header
            HStack {
                Text("Exercises")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(workout.exerciseCount)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            // Scrollable Exercise List
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(workout.workoutExercisesArray.enumerated()), id: \.element.id) { index, workoutExercise in
                        exerciseListRow(index: index, workoutExercise: workoutExercise)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Warmup State View

    private var warmupStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            // Warmup title
            VStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)

                Text("WARMUP")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)

                Text("Get your body ready")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Timer circle
            ZStack {
                Circle()
                    .stroke(lineWidth: 16)
                    .opacity(0.2)
                    .foregroundColor(.orange)

                Circle()
                    .trim(from: 0.0, to: executionManager.exerciseProgress)
                    .stroke(style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))
                    .foregroundColor(.orange)
                    .rotationEffect(Angle(degrees: -90))
                    .animation(.linear(duration: 0.5), value: executionManager.exerciseProgress)

                VStack(spacing: 4) {
                    Text(executionManager.formattedTimeRemaining)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.orange)

                    Text("remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 220, height: 220)

            Spacer()

            // Controls
            HStack(spacing: 20) {
                // Skip warmup button
                Button(action: { executionManager.skipWarmup() }) {
                    VStack(spacing: 4) {
                        Image(systemName: "forward.end.fill")
                            .font(.title2)
                        Text("Skip")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 70, height: 70)
                    .background(Color.gray)
                    .cornerRadius(35)
                }

                // Pause button
                Button(action: { executionManager.togglePause() }) {
                    VStack(spacing: 4) {
                        Image(systemName: "pause.fill")
                            .font(.title2)
                        Text("Pause")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 70, height: 70)
                    .background(Color.orange)
                    .cornerRadius(35)
                }

                // End button
                Button(action: { showingEndConfirmation = true }) {
                    VStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                        Text("End")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 70, height: 70)
                    .background(Color.red)
                    .cornerRadius(35)
                }
            }
            .padding(.bottom, 30)
        }
    }

    // MARK: - Workout Summary Section

    private var workoutSummarySection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Exercises count
                SummaryItem(value: "\(workout.exerciseCount)", label: "Exercises")

                // Rounds
                SummaryItem(value: "\(workout.rounds)", label: "Rounds")

                // Time per exercise
                SummaryItem(value: "\(workout.timePerExercise)s", label: "Per Exercise")

                // Total duration
                SummaryItem(value: workout.formattedCalculatedDuration, label: "Total")
            }

            HStack(spacing: 12) {
                // Warmup
                if workout.warmupDuration > 0 {
                    Label("\(workout.warmupDuration) min warmup", systemImage: "flame")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                // Rest between exercises
                if workout.restBetweenExercises > 0 {
                    Label("\(workout.restBetweenExercises)s rest", systemImage: "pause.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Rest between rounds
                if workout.rounds > 1 && workout.restBetweenRounds > 0 {
                    Label("\(workout.restBetweenRounds)s round break", systemImage: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Mode badge
                HStack(spacing: 4) {
                    Image(systemName: workout.isRoundRobin ? "arrow.triangle.2.circlepath" : "arrow.down.circle")
                        .font(.caption2)
                    Text(workout.isRoundRobin ? "Round Robin" : "Sequential")
                        .font(.caption2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Exercise List Row

    private func exerciseListRow(index: Int, workoutExercise: WorkoutExercise) -> some View {
        HStack(spacing: 12) {
            // Order number
            Text("\(index + 1)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.accentColor)
                .cornerRadius(14)

            // Exercise details
            VStack(alignment: .leading, spacing: 2) {
                Text(workoutExercise.exerciseName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(workoutExercise.exerciseCategory)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(10)
    }

    // MARK: - Running State View

    private var runningStateView: some View {
        VStack(spacing: 0) {
            // Current exercise - fixed height container
            currentExerciseSectionCompact
                .frame(height: 100)

            // Timer circle - fixed position
            timerSectionCompact
                .padding(.vertical, 8)

            // Next up - fixed height container
            nextUpSectionCompact
                .frame(height: 80)

            Spacer()

            // Progress bar at bottom
            progressSectionBottom
                .padding(.horizontal)

            // Controls
            controlsSection
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
    }

    // MARK: - Current Exercise Section

    private var currentExerciseSectionCompact: some View {
        VStack(spacing: 6) {
            if executionManager.state == .resting {
                Spacer()
                Text("REST")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
                Spacer()
            } else if executionManager.state == .roundRest {
                Spacer()
                Text("ROUND BREAK")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.purple)
                Spacer()
            } else if let exercise = executionManager.currentExercise {
                Spacer()
                Text(exercise.exerciseName)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal)

                HStack(spacing: 10) {
                    Text(exercise.exerciseCategory)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(6)

                    if workout.rounds > 1 {
                        Text("Round \(executionManager.currentRound) of \(workout.rounds)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - Timer Section (Compact)

    private var timerSectionCompact: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 14)
                .opacity(0.2)
                .foregroundColor(stateColor)

            Circle()
                .trim(from: 0.0, to: executionManager.exerciseProgress)
                .stroke(style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))
                .foregroundColor(stateColor)
                .rotationEffect(Angle(degrees: -90))
                .animation(.linear(duration: 0.5), value: executionManager.exerciseProgress)

            VStack(spacing: 2) {
                Text(executionManager.formattedTimeRemaining)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(stateColor)

                if executionManager.state == .countdown {
                    Text("GET READY")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
            }
        }
        .frame(width: 200, height: 200)
    }

    // MARK: - Next Up Section

    private var nextUpSectionCompact: some View {
        VStack {
            Spacer()
            if let nextExercise = executionManager.nextExercise {
                VStack(spacing: 2) {
                    Text("NEXT UP")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Text(nextExercise.exerciseName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(nextExercise.exerciseCategory)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
            } else if executionManager.state != .completed && executionManager.state != .ready {
                HStack(spacing: 6) {
                    Image(systemName: "flag.checkered")
                        .font(.subheadline)
                    Text("Final Exercise!")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
            }
            Spacer()
        }
    }

    // MARK: - Progress Section (Bottom)

    private var progressSectionBottom: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Exercise \(executionManager.currentExerciseIndex + 1)/\(executionManager.totalExercises)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(executionManager.workoutProgress * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(stateColor)
                        .frame(width: geometry.size.width * executionManager.workoutProgress, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: executionManager.workoutProgress)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        HStack(spacing: 16) {
            // Skip button
            if executionManager.state == .running || executionManager.state == .resting || executionManager.state == .roundRest {
                Button(action: { executionManager.skipExercise() }) {
                    VStack(spacing: 2) {
                        Image(systemName: "forward.end.fill")
                            .font(.title3)
                        Text("Skip")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.gray)
                    .cornerRadius(30)
                }
            }

            // Main action button
            Button(action: { handleMainAction() }) {
                VStack(spacing: 2) {
                    Image(systemName: mainButtonIcon)
                        .font(.title2)
                    Text(mainButtonText)
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(width: 80, height: 80)
                .background(mainButtonColor)
                .cornerRadius(40)
            }

            // Pause/Resume button
            if executionManager.state == .running || executionManager.state == .paused || executionManager.state == .resting || executionManager.state == .roundRest || executionManager.state == .warmup {
                Button(action: { executionManager.togglePause() }) {
                    VStack(spacing: 2) {
                        Image(systemName: executionManager.state == .paused ? "play.fill" : "pause.fill")
                            .font(.title3)
                        Text(executionManager.state == .paused ? "Resume" : "Pause")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(executionManager.state == .paused ? Color.green : Color.orange)
                    .cornerRadius(30)
                }
            }
        }
    }

    // MARK: - Main Action Button Properties

    private var mainButtonIcon: String {
        switch executionManager.state {
        case .ready:
            return "play.fill"
        case .completed:
            return "checkmark"
        default:
            return "stop.fill"
        }
    }

    private var mainButtonText: String {
        switch executionManager.state {
        case .ready:
            return "Start"
        case .completed:
            return "Done"
        default:
            return "End"
        }
    }

    private var mainButtonColor: Color {
        switch executionManager.state {
        case .ready:
            return .green
        case .completed:
            return .purple
        default:
            return .red
        }
    }

    // MARK: - Completed View

    private var completedView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "trophy.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)

            Text("Workout Complete!")
                .font(.title)
                .fontWeight(.bold)

            VStack(spacing: 6) {
                StatRow(title: "Total Time", value: executionManager.formattedElapsedTime)
                StatRow(title: "Exercises", value: "\(executionManager.totalExercises)")
                if workout.rounds > 1 {
                    StatRow(title: "Rounds", value: "\(workout.rounds)")
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            Spacer()

            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Helper Properties

    private var stateColor: Color {
        switch executionManager.state {
        case .ready:
            return .gray
        case .warmup:
            return .orange
        case .countdown:
            return .orange
        case .running:
            return .green
        case .resting:
            return .blue
        case .roundRest:
            return .purple
        case .paused:
            return .yellow
        case .completed:
            return .purple
        }
    }

    // MARK: - Actions

    private func handleMainAction() {
        switch executionManager.state {
        case .ready:
            executionManager.start()
        case .completed:
            dismiss()
        default:
            showingEndConfirmation = true
        }
    }

    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background:
            executionManager.enterBackground()
        case .active:
            executionManager.enterForeground()
        default:
            break
        }
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Summary Item

struct SummaryItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

struct WorkoutExecutionView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.viewContext
        let workout = Workout(context: context)
        workout.id = UUID()
        workout.name = "Preview Workout"
        workout.createdDate = Date()
        workout.rounds = 3
        workout.timePerExercise = 30
        workout.restBetweenExercises = 15
        workout.restBetweenRounds = 60
        workout.executionMode = "roundRobin"

        return WorkoutExecutionView(workout: workout)
            .environment(\.managedObjectContext, context)
    }
}
