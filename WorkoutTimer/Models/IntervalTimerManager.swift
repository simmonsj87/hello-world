//
//  IntervalTimerManager.swift
//  WorkoutTimer
//
//  Observable class that manages interval timer state and countdown logic.
//

import Foundation
import Combine

class IntervalTimerManager: ObservableObject {
    // MARK: - Published Properties

    /// Time remaining in the current interval (seconds)
    @Published var timeRemaining: Int = 0

    /// Current state of the timer
    @Published var currentState: TimerState = .idle

    /// Current cycle within the current round (1-indexed)
    @Published var currentCycle: Int = 1

    /// Current round (1-indexed)
    @Published var currentRound: Int = 1

    /// Whether the timer is currently paused
    @Published var isPaused: Bool = false

    // MARK: - Configuration

    /// Timer configuration settings
    var configuration: TimerConfiguration

    /// Voice announcement manager for audio feedback
    var voiceManager: VoiceAnnouncementManager?

    // MARK: - Private Properties

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var hasAnnouncedCountdown = false

    // MARK: - Computed Properties

    /// Total cycles completed across all rounds
    var totalCyclesCompleted: Int {
        let completedRounds = currentRound - 1
        let cyclesInCompletedRounds = completedRounds * configuration.cycles
        let cyclesInCurrentRound = currentCycle - 1
        return cyclesInCompletedRounds + cyclesInCurrentRound
    }

    /// Total cycles in the entire workout
    var totalCycles: Int {
        configuration.cycles * configuration.rounds
    }

    /// Progress as a percentage (0.0 to 1.0)
    var progress: Double {
        // Return 100% when completed
        if currentState == .completed {
            return 1.0
        }

        guard totalCycles > 0 else { return 0 }
        return Double(totalCyclesCompleted) / Double(totalCycles)
    }

    /// Formatted time remaining string (e.g., "0:30")
    var formattedTimeRemaining: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Initialization

    init(configuration: TimerConfiguration = .default) {
        self.configuration = configuration
    }

    // MARK: - Public Methods

    /// Start the timer from the beginning
    func start() {
        stopTimer()
        voiceManager?.stop()
        currentState = .working
        currentCycle = 1
        currentRound = 1
        timeRemaining = configuration.workDuration
        isPaused = false
        hasAnnouncedCountdown = false

        // Announce start with countdown - timer starts when "Go!" is said
        if let voice = voiceManager, voice.isEnabled {
            voice.announceIntervalWorkStart { [weak self] in
                guard let self = self, self.currentState == .working && !self.isPaused else { return }
                self.startTimer()
            }
        } else {
            // If voice is disabled, start immediately
            startTimer()
        }
    }

    /// Pause the timer
    func pause() {
        guard currentState != .idle && currentState != .completed else { return }
        isPaused = true
        stopTimer()
    }

    /// Resume the timer from paused state
    func resume() {
        guard isPaused else { return }
        isPaused = false
        startTimer()
    }

    /// Reset the timer to beginning and restart
    func reset() {
        stopTimer()
        voiceManager?.stop()
        currentCycle = 1
        currentRound = 1
        timeRemaining = configuration.workDuration
        isPaused = false
        hasAnnouncedCountdown = false
        currentState = .working

        // Announce restart with countdown - timer starts when "Go!" is said
        if let voice = voiceManager, voice.isEnabled {
            voice.announceIntervalWorkStart { [weak self] in
                guard let self = self, self.currentState == .working && !self.isPaused else { return }
                self.startTimer()
            }
        } else {
            // If voice is disabled, start immediately
            startTimer()
        }
    }

    /// Stop the timer and return to idle/configuration state
    func stop() {
        stopTimer()
        voiceManager?.stop()
        currentState = .idle
        currentCycle = 1
        currentRound = 1
        timeRemaining = configuration.workDuration
        isPaused = false
        hasAnnouncedCountdown = false
    }

    /// Toggle between pause and resume
    func togglePause() {
        if isPaused {
            resume()
        } else {
            pause()
        }
    }

    // MARK: - Private Methods

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard !isPaused else { return }

        if timeRemaining > 0 {
            timeRemaining -= 1

            // Announce countdown for transitions
            if timeRemaining == 3 && !hasAnnouncedCountdown {
                hasAnnouncedCountdown = true
                announceUpcomingTransition()
            }
        } else {
            hasAnnouncedCountdown = false
            advanceToNextState()
        }
    }

    private func announceUpcomingTransition() {
        switch currentState {
        case .working:
            // About to finish work, announce "3, 2, 1, stop"
            voiceManager?.announceIntervalWorkEnd()
        case .resting, .roundRest:
            // About to finish rest, announce "3, 2, 1, go"
            voiceManager?.announceIntervalRestEnd()
        default:
            break
        }
    }

    private func advanceToNextState() {
        switch currentState {
        case .idle:
            // Should not happen, but handle gracefully
            break

        case .working:
            handleWorkComplete()

        case .resting:
            handleRestComplete()

        case .roundRest:
            handleRoundRestComplete()

        case .completed:
            // Timer is done, nothing to do
            stopTimer()
        }
    }

    private func handleWorkComplete() {
        // Play bell for transition
        voiceManager?.playBell()

        // Check if this was the last cycle of the last round
        if currentCycle >= configuration.cycles && currentRound >= configuration.rounds {
            completeWorkout()
            return
        }

        // Check if this was the last cycle of the current round
        if currentCycle >= configuration.cycles {
            // Move to round rest if there are more rounds
            if currentRound < configuration.rounds {
                currentState = .roundRest
                timeRemaining = configuration.restBetweenRounds
                voiceManager?.announceIntervalRoundComplete(nextRound: currentRound + 1, totalRounds: configuration.rounds)
            }
        } else {
            // Move to rest between cycles
            currentState = .resting
            timeRemaining = configuration.restDuration
        }
    }

    private func handleRestComplete() {
        // Play bell for transition back to work
        voiceManager?.playBell()

        // Move to next cycle's work period
        currentCycle += 1
        currentState = .working
        timeRemaining = configuration.workDuration
    }

    private func handleRoundRestComplete() {
        // Play bell for new round
        voiceManager?.playBell()

        // Move to next round
        currentRound += 1
        currentCycle = 1
        currentState = .working
        timeRemaining = configuration.workDuration
    }

    private func completeWorkout() {
        currentState = .completed
        timeRemaining = 0
        stopTimer()
        voiceManager?.announceIntervalComplete()
    }

    deinit {
        stopTimer()
    }
}
