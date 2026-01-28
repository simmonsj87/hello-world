//
//  WorkoutExecutionManager.swift
//  WorkoutTimer
//
//  Manages workout execution state, timer, and voice announcements.
//  Supports multiple rounds and sequential/round-robin execution modes.
//

import Foundation
import Combine
import UserNotifications
import UIKit

class WorkoutExecutionManager: ObservableObject {
    // MARK: - Published Properties

    @Published var state: WorkoutExecutionState = .ready
    @Published var currentExerciseIndex: Int = 0
    @Published var currentRound: Int = 1
    @Published var timeRemaining: Int = 0
    @Published var elapsedTime: Int = 0

    // MARK: - Properties

    var voiceManager: VoiceAnnouncementManager?

    private let workout: Workout
    private let exercises: [WorkoutExercise]
    private var timer: Timer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var backgroundDate: Date?
    private var countdownValue: Int = 3
    private var previousState: WorkoutExecutionState = .ready

    private let countdownDuration = 3

    // Workout settings (from Workout entity)
    private var totalRounds: Int
    private var timePerExercise: Int
    private var restBetweenExercises: Int
    private var restBetweenRounds: Int
    private var isRoundRobin: Bool

    // MARK: - Computed Properties

    var totalExercises: Int {
        exercises.count
    }

    var currentExercise: WorkoutExercise? {
        guard currentExerciseIndex < exercises.count else { return nil }
        return exercises[currentExerciseIndex]
    }

    var nextExercise: WorkoutExercise? {
        if isRoundRobin {
            // In round-robin, next is the next exercise in sequence, or first exercise of next round
            let nextIndex = currentExerciseIndex + 1
            if nextIndex < exercises.count {
                return exercises[nextIndex]
            } else if currentRound < totalRounds {
                return exercises.first
            }
            return nil
        } else {
            // In sequential, if we have more rounds of this exercise, same exercise
            // Otherwise, next exercise
            if currentRound < totalRounds {
                return currentExercise
            }
            let nextIndex = currentExerciseIndex + 1
            guard nextIndex < exercises.count else { return nil }
            return exercises[nextIndex]
        }
    }

    var workoutProgress: CGFloat {
        guard totalExercises > 0, totalRounds > 0 else { return 0 }

        let totalWorkUnits = totalExercises * totalRounds
        var completedUnits: Int

        if isRoundRobin {
            // Round-robin: progress = (completedRounds * exercises) + currentExerciseIndex
            completedUnits = (currentRound - 1) * totalExercises + currentExerciseIndex
        } else {
            // Sequential: progress = (completedExercises * rounds) + currentRound - 1
            completedUnits = currentExerciseIndex * totalRounds + (currentRound - 1)
        }

        return CGFloat(completedUnits) / CGFloat(totalWorkUnits)
    }

    var exerciseProgress: CGFloat {
        let totalTime: Int
        switch state {
        case .countdown:
            totalTime = countdownDuration
            return CGFloat(countdownValue) / CGFloat(totalTime)
        case .running:
            totalTime = timePerExercise
        case .resting:
            totalTime = restBetweenExercises
        case .roundRest:
            totalTime = restBetweenRounds
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
            if totalRounds > 1 {
                return "Round \(currentRound) of \(totalRounds)"
            }
            return "Working"
        case .resting:
            return "Rest"
        case .roundRest:
            return "Round break"
        case .paused:
            return "Paused"
        case .completed:
            return "Complete!"
        }
    }

    var roundDisplayText: String {
        "Round \(currentRound)/\(totalRounds)"
    }

    // MARK: - Initialization

    init(workout: Workout) {
        self.workout = workout
        self.exercises = workout.workoutExercisesArray

        // Load workout settings
        self.totalRounds = max(1, Int(workout.rounds))
        self.timePerExercise = max(5, Int(workout.timePerExercise))
        self.restBetweenExercises = Int(workout.restBetweenExercises)
        self.restBetweenRounds = Int(workout.restBetweenRounds)
        self.isRoundRobin = workout.isRoundRobin
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
        currentRound = 1
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
        } else if state == .running || state == .resting || state == .roundRest {
            pause()
        }
    }

    func skipExercise() {
        voiceManager?.stop()
        moveToNext()
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
        guard state == .running || state == .resting || state == .roundRest else { return }
        previousState = state
        stopTimer()
        state = .paused
        voiceManager?.speak("Paused")
    }

    private func resume() {
        guard state == .paused else { return }
        state = previousState
        voiceManager?.speak("Resume")
        startTimer()
    }

    // MARK: - Private Methods - Countdown

    private func startCountdown() {
        state = .countdown
        countdownValue = countdownDuration
        timeRemaining = countdownDuration

        if let exercise = currentExercise {
            var announcement = exercise.exerciseName
            if totalRounds > 1 {
                announcement += ", round \(currentRound)"
            }
            voiceManager?.announceExercise(name: announcement, countdown: true)
        }

        // Wait for voice countdown to finish, then start
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) { [weak self] in
            self?.startExercise()
        }
    }

    private func startExercise() {
        guard currentExercise != nil else {
            completeWorkout()
            return
        }

        state = .running
        timeRemaining = timePerExercise
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
            switch state {
            case .running:
                if let next = nextExercise {
                    if next.exercise?.id == currentExercise?.exercise?.id && totalRounds > 1 {
                        voiceManager?.speak("Round \(currentRound + 1) coming up")
                    } else {
                        voiceManager?.speak("Next up: \(next.exerciseName)")
                    }
                } else {
                    voiceManager?.speak("Last exercise, almost there!")
                }
            case .resting, .roundRest:
                if let next = currentExercise {
                    voiceManager?.speak("Get ready for \(next.exerciseName)")
                }
            default:
                break
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
            handleExerciseComplete()

        case .resting:
            moveToNextExercise()

        case .roundRest:
            startNextRound()

        default:
            break
        }
    }

    // MARK: - Private Methods - State Transitions

    private func handleExerciseComplete() {
        if isRoundRobin {
            handleRoundRobinExerciseComplete()
        } else {
            handleSequentialExerciseComplete()
        }
    }

    private func handleSequentialExerciseComplete() {
        // In sequential mode: do all rounds of one exercise, then move to next exercise
        if currentRound < totalRounds {
            // More rounds of this exercise
            if restBetweenRounds > 0 {
                startRoundRest()
            } else {
                currentRound += 1
                startCountdown()
            }
        } else {
            // All rounds of this exercise done, check if more exercises
            let isLastExercise = currentExerciseIndex >= exercises.count - 1
            if isLastExercise {
                completeWorkout()
            } else if restBetweenExercises > 0 {
                // Rest before moving to next exercise
                startRestBeforeNextExercise()
            } else {
                // No rest, move directly to next exercise
                advanceToNextExercise()
            }
        }
    }

    private func handleRoundRobinExerciseComplete() {
        // In round-robin mode: go through all exercises, then repeat for next round
        let isLastExercise = currentExerciseIndex >= exercises.count - 1

        if isLastExercise {
            // End of round
            if currentRound < totalRounds {
                // More rounds to go
                if restBetweenRounds > 0 {
                    startRoundRest()
                } else {
                    startNextRound()
                }
            } else {
                // All rounds complete
                completeWorkout()
            }
        } else {
            // More exercises in this round
            if restBetweenExercises > 0 {
                startRest()
            } else {
                currentExerciseIndex += 1
                startCountdown()
            }
        }
    }

    private func startRest() {
        state = .resting
        timeRemaining = restBetweenExercises
        voiceManager?.announceRest(duration: restBetweenExercises)
    }

    private func startRestBeforeNextExercise() {
        // Used in sequential mode when moving from one exercise to the next
        state = .resting
        timeRemaining = restBetweenExercises
        let nextIndex = currentExerciseIndex + 1
        if nextIndex < exercises.count {
            let nextExercise = exercises[nextIndex]
            voiceManager?.speak("Rest \(restBetweenExercises) seconds. Next: \(nextExercise.exerciseName)")
        } else {
            voiceManager?.announceRest(duration: restBetweenExercises)
        }
    }

    private func advanceToNextExercise() {
        // Move to next exercise and reset round counter (for sequential mode)
        stopTimer()
        currentExerciseIndex += 1
        currentRound = 1

        if currentExerciseIndex >= exercises.count {
            completeWorkout()
        } else {
            startCountdown()
        }
    }

    private func startRoundRest() {
        state = .roundRest
        timeRemaining = restBetweenRounds
        voiceManager?.speak("Round \(currentRound) complete. Rest for \(restBetweenRounds) seconds.")
    }

    private func startNextRound() {
        currentRound += 1
        if isRoundRobin {
            currentExerciseIndex = 0
        }
        startCountdown()
    }

    private func moveToNext() {
        stopTimer()

        if isRoundRobin {
            moveToNextInRoundRobin()
        } else {
            moveToNextInSequential()
        }
    }

    private func moveToNextExercise() {
        stopTimer()

        if isRoundRobin {
            currentExerciseIndex += 1
            if currentExerciseIndex >= exercises.count {
                if currentRound < totalRounds {
                    startNextRound()
                } else {
                    completeWorkout()
                }
            } else {
                startCountdown()
            }
        } else {
            // Sequential: move to next exercise, reset round
            currentExerciseIndex += 1
            currentRound = 1

            if currentExerciseIndex >= exercises.count {
                completeWorkout()
            } else {
                startCountdown()
            }
        }
    }

    private func moveToNextInSequential() {
        if currentRound < totalRounds {
            currentRound += 1
            startCountdown()
        } else {
            currentExerciseIndex += 1
            currentRound = 1

            if currentExerciseIndex >= exercises.count {
                completeWorkout()
            } else {
                startCountdown()
            }
        }
    }

    private func moveToNextInRoundRobin() {
        currentExerciseIndex += 1

        if currentExerciseIndex >= exercises.count {
            if currentRound < totalRounds {
                currentExerciseIndex = 0
                currentRound += 1
                startCountdown()
            } else {
                completeWorkout()
            }
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
        guard state == .running || state == .resting || state == .roundRest else { return }

        var remainingElapsed = elapsed

        while remainingElapsed > 0 && state != .completed {
            if timeRemaining > remainingElapsed {
                timeRemaining -= remainingElapsed
                elapsedTime += remainingElapsed
                remainingElapsed = 0
            } else {
                remainingElapsed -= timeRemaining
                elapsedTime += timeRemaining
                timeRemaining = 0

                // Simulate state transition
                switch state {
                case .running:
                    if isRoundRobin {
                        simulateRoundRobinTransition()
                    } else {
                        simulateSequentialTransition()
                    }
                case .resting:
                    currentExerciseIndex += 1
                    if currentExerciseIndex >= exercises.count {
                        if isRoundRobin && currentRound < totalRounds {
                            currentExerciseIndex = 0
                            currentRound += 1
                        } else {
                            state = .completed
                        }
                    }
                    if state != .completed {
                        state = .running
                        timeRemaining = timePerExercise
                    }
                case .roundRest:
                    currentRound += 1
                    if isRoundRobin {
                        currentExerciseIndex = 0
                    }
                    state = .running
                    timeRemaining = timePerExercise
                default:
                    break
                }
            }
        }

        if state != .completed && state != .paused {
            startTimer()
        }
    }

    private func simulateRoundRobinTransition() {
        let isLastExercise = currentExerciseIndex >= exercises.count - 1

        if isLastExercise {
            if currentRound < totalRounds {
                if restBetweenRounds > 0 {
                    state = .roundRest
                    timeRemaining = restBetweenRounds
                } else {
                    currentRound += 1
                    currentExerciseIndex = 0
                    timeRemaining = timePerExercise
                }
            } else {
                state = .completed
            }
        } else {
            if restBetweenExercises > 0 {
                state = .resting
                timeRemaining = restBetweenExercises
            } else {
                currentExerciseIndex += 1
                timeRemaining = timePerExercise
            }
        }
    }

    private func simulateSequentialTransition() {
        if currentRound < totalRounds {
            if restBetweenRounds > 0 {
                state = .roundRest
                timeRemaining = restBetweenRounds
            } else {
                currentRound += 1
                timeRemaining = timePerExercise
            }
        } else {
            currentExerciseIndex += 1
            currentRound = 1

            if currentExerciseIndex >= exercises.count {
                state = .completed
            } else {
                if restBetweenExercises > 0 {
                    state = .resting
                    timeRemaining = restBetweenExercises
                } else {
                    timeRemaining = timePerExercise
                }
            }
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
        // Calculate upcoming transitions
        var timeOffset = timeRemaining

        // Current exercise ending
        if state == .running {
            scheduleNotification(
                identifier: "exercise-end-\(currentExerciseIndex)-\(currentRound)",
                title: "Exercise Complete",
                body: "Rest period starting",
                timeInterval: TimeInterval(timeOffset)
            )

            if restBetweenExercises > 0 {
                timeOffset += restBetweenExercises
                scheduleNotification(
                    identifier: "rest-end-\(currentExerciseIndex)-\(currentRound)",
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
