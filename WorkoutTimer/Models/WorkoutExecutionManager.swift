//
//  WorkoutExecutionManager.swift
//  WorkoutTimer
//
//  Manages workout execution state, timer, and voice announcements.
//

import Foundation
import Combine
import UserNotifications
import UIKit

class WorkoutExecutionManager: ObservableObject {
    // MARK: - Published Properties

    @Published var state: WorkoutExecutionState = .ready
    @Published var currentExerciseIndex: Int = 0
    @Published var timeRemaining: Int = 0
    @Published var elapsedTime: Int = 0

    // MARK: - Properties

    var voiceManager: VoiceAnnouncementManager?
    var restDuration: Int = 15

    private let workout: Workout
    private let exercises: [WorkoutExercise]
    private var timer: Timer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var backgroundDate: Date?
    private var countdownValue: Int = 3

    private let countdownDuration = 3

    // MARK: - Computed Properties

    var totalExercises: Int {
        exercises.count
    }

    var currentExercise: WorkoutExercise? {
        guard currentExerciseIndex < exercises.count else { return nil }
        return exercises[currentExerciseIndex]
    }

    var nextExercise: WorkoutExercise? {
        let nextIndex = currentExerciseIndex + 1
        guard nextIndex < exercises.count else { return nil }
        return exercises[nextIndex]
    }

    var workoutProgress: CGFloat {
        guard totalExercises > 0 else { return 0 }
        let exerciseProgress = CGFloat(currentExerciseIndex) / CGFloat(totalExercises)
        let currentProgress = exerciseProgress + (1.0 - exerciseProgress) * (1.0 - exerciseProgress)

        // More accurate: based on completed exercises
        return CGFloat(currentExerciseIndex) / CGFloat(totalExercises)
    }

    var exerciseProgress: CGFloat {
        let totalTime: Int
        switch state {
        case .countdown:
            totalTime = countdownDuration
            return CGFloat(countdownValue) / CGFloat(totalTime)
        case .running:
            guard let exercise = currentExercise else { return 0 }
            totalTime = Int(exercise.duration)
        case .resting:
            totalTime = restDuration
        default:
            return 1.0
        }

        guard totalTime > 0 else { return 0 }
        return CGFloat(timeRemaining) / CGFloat(totalTime)
    }

    var formattedTimeRemaining: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedElapsedTime: String {
        let minutes = elapsedTime / 60
        let seconds = elapsedTime % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var stateDisplayText: String {
        switch state {
        case .ready:
            return "Ready to start"
        case .countdown:
            return "Get ready..."
        case .running:
            return "Working"
        case .resting:
            return "Resting"
        case .paused:
            return "Paused"
        case .completed:
            return "Complete!"
        }
    }

    // MARK: - Initialization

    init(workout: Workout) {
        self.workout = workout
        self.exercises = workout.workoutExercisesArray
    }

    deinit {
        stop()
    }

    // MARK: - Public Methods

    func start() {
        guard !exercises.isEmpty else {
            state = .completed
            return
        }

        currentExerciseIndex = 0
        elapsedTime = 0

        startCountdown()
    }

    func stop() {
        stopTimer()
        voiceManager?.stop()
        endBackgroundTask()
        state = .ready
    }

    func togglePause() {
        if state == .paused {
            resume()
        } else if state == .running || state == .resting {
            pause()
        }
    }

    func skipExercise() {
        voiceManager?.stop()
        moveToNextExercise()
    }

    func enterBackground() {
        backgroundDate = Date()
        beginBackgroundTask()
        scheduleNotifications()
    }

    func enterForeground() {
        if let backgroundDate = backgroundDate {
            let elapsed = Int(Date().timeIntervalSince(backgroundDate))
            handleBackgroundElapsed(elapsed)
        }
        backgroundDate = nil
        cancelNotifications()
        endBackgroundTask()
    }

    // MARK: - Private Methods - Timer Control

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func pause() {
        guard state == .running || state == .resting else { return }
        stopTimer()
        state = .paused
        voiceManager?.speak("Paused")
    }

    private func resume() {
        guard state == .paused else { return }
        state = timeRemaining > 0 && currentExerciseIndex < exercises.count ? .running : .resting
        voiceManager?.speak("Resume")
        startTimer()
    }

    // MARK: - Private Methods - Countdown

    private func startCountdown() {
        state = .countdown
        countdownValue = countdownDuration
        timeRemaining = countdownDuration

        if let exercise = currentExercise {
            voiceManager?.announceExercise(name: exercise.exerciseName, countdown: true)
        }

        // Wait for voice countdown to finish, then start
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) { [weak self] in
            self?.startExercise()
        }
    }

    private func startExercise() {
        guard let exercise = currentExercise else {
            completeWorkout()
            return
        }

        state = .running
        timeRemaining = Int(exercise.duration)
        startTimer()
    }

    // MARK: - Private Methods - Tick

    private func tick() {
        // Update elapsed time (except during countdown)
        if state != .countdown {
            elapsedTime += 1
        }

        // Countdown
        if timeRemaining > 0 {
            timeRemaining -= 1

            // Time warnings
            handleTimeWarnings()
        } else {
            handleTimeExpired()
        }
    }

    private func handleTimeWarnings() {
        // Announce upcoming transition
        if timeRemaining == 5 {
            if state == .running, let next = nextExercise {
                voiceManager?.speak("Next up: \(next.exerciseName)")
            } else if state == .running && nextExercise == nil {
                voiceManager?.speak("Last exercise, almost there!")
            }
        }

        // Countdown warnings
        if timeRemaining <= 3 && timeRemaining > 0 {
            voiceManager?.announceTimeWarning(seconds: timeRemaining)
        }
    }

    private func handleTimeExpired() {
        switch state {
        case .running:
            // Exercise complete, start rest or move to next
            if restDuration > 0 && currentExerciseIndex < exercises.count - 1 {
                startRest()
            } else {
                moveToNextExercise()
            }

        case .resting:
            moveToNextExercise()

        default:
            break
        }
    }

    // MARK: - Private Methods - State Transitions

    private func startRest() {
        state = .resting
        timeRemaining = restDuration
        voiceManager?.announceRest(duration: restDuration)
    }

    private func moveToNextExercise() {
        stopTimer()

        currentExerciseIndex += 1

        if currentExerciseIndex >= exercises.count {
            completeWorkout()
        } else {
            startCountdown()
        }
    }

    private func completeWorkout() {
        stopTimer()
        state = .completed
        voiceManager?.announceWorkoutComplete()
        sendCompletionNotification()
    }

    // MARK: - Private Methods - Background Handling

    private func handleBackgroundElapsed(_ elapsed: Int) {
        guard state == .running || state == .resting else { return }

        var remainingElapsed = elapsed

        while remainingElapsed > 0 && state != .completed {
            if timeRemaining > remainingElapsed {
                timeRemaining -= remainingElapsed
                elapsedTime += remainingElapsed
                remainingElapsed = 0
            } else {
                remainingElapsed -= timeRemaining
                elapsedTime += timeRemaining

                if state == .running {
                    if restDuration > 0 && currentExerciseIndex < exercises.count - 1 {
                        state = .resting
                        timeRemaining = restDuration
                    } else {
                        currentExerciseIndex += 1
                        if currentExerciseIndex >= exercises.count {
                            state = .completed
                            timeRemaining = 0
                        } else {
                            timeRemaining = Int(exercises[currentExerciseIndex].duration)
                        }
                    }
                } else if state == .resting {
                    currentExerciseIndex += 1
                    if currentExerciseIndex >= exercises.count {
                        state = .completed
                        timeRemaining = 0
                    } else {
                        state = .running
                        timeRemaining = Int(exercises[currentExerciseIndex].duration)
                    }
                }
            }
        }

        if state != .completed && state != .paused {
            startTimer()
        }
    }

    private func beginBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    // MARK: - Private Methods - Notifications

    private func scheduleNotifications() {
        let center = UNUserNotificationCenter.current()

        // Calculate upcoming transitions
        var timeOffset = timeRemaining

        // Current exercise ending
        if state == .running {
            scheduleNotification(
                identifier: "exercise-end-\(currentExerciseIndex)",
                title: "Exercise Complete",
                body: "Rest period starting",
                timeInterval: TimeInterval(timeOffset)
            )

            if restDuration > 0 {
                timeOffset += restDuration
                scheduleNotification(
                    identifier: "rest-end-\(currentExerciseIndex)",
                    title: "Rest Complete",
                    body: nextExercise?.exerciseName ?? "Next exercise",
                    timeInterval: TimeInterval(timeOffset)
                )
            }
        }
    }

    private func scheduleNotification(identifier: String, title: String, body: String, timeInterval: TimeInterval) {
        guard timeInterval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    private func cancelNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private func sendCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Workout Complete! 🎉"
        content.body = "Great job finishing \(workout.wrappedName)!"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "workout-complete",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
