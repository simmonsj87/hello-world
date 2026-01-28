//
//  WorkoutExecutionView.swift
//  WorkoutTimer
//
//  View for executing a saved workout with timer and voice announcements.
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
    @State private var restDuration: Int = 15

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
                // Header
                headerSection

                Spacer()

                // Main Content
                if executionManager.state == .completed {
                    completedView
                } else {
                    mainContentView
                }

                Spacer()

                // Controls
                controlsSection
            }
            .padding()
        }
        .navigationBarHidden(true)
        .onAppear {
            setupNotifications()
            executionManager.voiceManager = voiceManager
            executionManager.restDuration = restDuration
        }
        .onDisappear {
            executionManager.stop()
        }
        .onChange(of: scenePhase) { phase in
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
        case .countdown:
            return Color.orange.opacity(0.2)
        case .running:
            return Color.green.opacity(0.15)
        case .resting:
            return Color.blue.opacity(0.15)
        case .paused:
            return Color.yellow.opacity(0.15)
        case .completed:
            return Color.purple.opacity(0.15)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            Button(action: { showingEndConfirmation = true }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(workout.wrappedName)
                    .font(.headline)
                Text(executionManager.stateDisplayText)
                    .font(.caption)
                    .foregroundColor(stateColor)
            }

            Spacer()

            // Elapsed time
            VStack(alignment: .trailing, spacing: 2) {
                Text("Elapsed")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(executionManager.formattedElapsedTime)
                    .font(.caption)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
        }
        .padding(.bottom)
    }

    // MARK: - Main Content View

    private var mainContentView: some View {
        VStack(spacing: 24) {
            // Progress indicator
            progressSection

            // Current exercise
            currentExerciseSection

            // Timer countdown
            timerSection

            // Next up preview
            nextUpSection
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 8) {
            // Progress text
            HStack {
                Text("Exercise \(executionManager.currentExerciseIndex + 1) of \(executionManager.totalExercises)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(executionManager.workoutProgress * 100))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(stateColor)
                        .frame(width: geometry.size.width * executionManager.workoutProgress, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: executionManager.workoutProgress)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Current Exercise Section

    private var currentExerciseSection: some View {
        VStack(spacing: 8) {
            if executionManager.state == .resting {
                Text("REST")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.blue)

                Text("Get ready for next exercise")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if let exercise = executionManager.currentExercise {
                Text(exercise.exerciseName)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)

                Text(exercise.exerciseCategory)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .frame(minHeight: 100)
    }

    // MARK: - Timer Section

    private var timerSection: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(lineWidth: 16)
                .opacity(0.2)
                .foregroundColor(stateColor)

            // Progress circle
            Circle()
                .trim(from: 0.0, to: executionManager.exerciseProgress)
                .stroke(style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))
                .foregroundColor(stateColor)
                .rotationEffect(Angle(degrees: -90))
                .animation(.linear(duration: 0.5), value: executionManager.exerciseProgress)

            // Time display
            VStack(spacing: 4) {
                Text(executionManager.formattedTimeRemaining)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(stateColor)

                if executionManager.state == .countdown {
                    Text("GET READY")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
            }
        }
        .frame(width: 280, height: 280)
    }

    // MARK: - Next Up Section

    private var nextUpSection: some View {
        Group {
            if let nextExercise = executionManager.nextExercise {
                HStack {
                    Image(systemName: "arrow.right.circle")
                        .foregroundColor(.secondary)
                    Text("Next up:")
                        .foregroundColor(.secondary)
                    Text(nextExercise.exerciseName)
                        .fontWeight(.medium)
                }
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            } else if executionManager.state != .completed && executionManager.state != .ready {
                HStack {
                    Image(systemName: "flag.checkered")
                        .foregroundColor(.secondary)
                    Text("Last exercise!")
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        VStack(spacing: 16) {
            // Rest duration picker (only when ready)
            if executionManager.state == .ready {
                restDurationPicker
            }

            // Main controls
            HStack(spacing: 20) {
                // Skip button
                if executionManager.state == .running || executionManager.state == .resting {
                    Button(action: { executionManager.skipExercise() }) {
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
                }

                // Main action button
                mainActionButton

                // Pause/Resume button
                if executionManager.state == .running || executionManager.state == .paused || executionManager.state == .resting {
                    Button(action: { executionManager.togglePause() }) {
                        VStack(spacing: 4) {
                            Image(systemName: executionManager.state == .paused ? "play.fill" : "pause.fill")
                                .font(.title2)
                            Text(executionManager.state == .paused ? "Resume" : "Pause")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(width: 70, height: 70)
                        .background(executionManager.state == .paused ? Color.green : Color.orange)
                        .cornerRadius(35)
                    }
                }
            }
        }
    }

    // MARK: - Rest Duration Picker

    private var restDurationPicker: some View {
        VStack(spacing: 8) {
            Text("Rest between exercises")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ForEach([0, 15, 30, 45, 60], id: \.self) { duration in
                    Button(action: {
                        restDuration = duration
                        executionManager.restDuration = duration
                    }) {
                        Text(duration == 0 ? "None" : "\(duration)s")
                            .font(.subheadline)
                            .fontWeight(restDuration == duration ? .bold : .regular)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(restDuration == duration ? Color.accentColor : Color(.secondarySystemBackground))
                            .foregroundColor(restDuration == duration ? .white : .primary)
                            .cornerRadius(8)
                    }
                }
            }
        }
    }

    // MARK: - Main Action Button

    private var mainActionButton: some View {
        Button(action: { handleMainAction() }) {
            VStack(spacing: 6) {
                Image(systemName: mainButtonIcon)
                    .font(.system(size: 32))
                Text(mainButtonText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(width: 100, height: 100)
            .background(mainButtonColor)
            .cornerRadius(50)
        }
    }

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
        VStack(spacing: 24) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 80))
                .foregroundColor(.yellow)

            Text("Workout Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)

            VStack(spacing: 8) {
                StatRow(title: "Total Time", value: executionManager.formattedElapsedTime)
                StatRow(title: "Exercises", value: "\(executionManager.totalExercises)")
                StatRow(title: "Workout", value: workout.wrappedName)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
        }
    }

    // MARK: - Helper Properties

    private var stateColor: Color {
        switch executionManager.state {
        case .ready:
            return .gray
        case .countdown:
            return .orange
        case .running:
            return .green
        case .resting:
            return .blue
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

// MARK: - Preview

struct WorkoutExecutionView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.viewContext
        let workout = Workout(context: context)
        workout.id = UUID()
        workout.name = "Preview Workout"
        workout.createdDate = Date()

        return WorkoutExecutionView(workout: workout)
            .environment(\.managedObjectContext, context)
    }
}
