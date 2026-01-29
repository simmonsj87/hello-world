//
//  VoiceAnnouncementManager.swift
//  WorkoutTimer
//
//  Manages voice announcements for workout timer using AVFoundation.
//

import Foundation
import AVFoundation
import AudioToolbox
import Combine

class VoiceAnnouncementManager: NSObject, ObservableObject {
    // MARK: - Published Properties

    /// Whether speech is currently active
    @Published var isSpeaking: Bool = false

    /// Whether voice announcements are enabled
    @Published var isEnabled: Bool = true {
        didSet {
            saveSettings()
        }
    }

    /// Selected voice identifier
    @Published var selectedVoiceIdentifier: String = "" {
        didSet {
            updateVoice()
            saveSettings()
        }
    }

    /// Speech rate (0.3 - 0.7, default 0.48 for more natural sound)
    @Published var rate: Float = 0.48 {
        didSet {
            rate = min(max(rate, 0.3), 0.7)
            saveSettings()
        }
    }

    /// Speech volume (0.0 - 1.0, default 0.8)
    @Published var volume: Float = 0.8 {
        didSet {
            volume = min(max(volume, 0.0), 1.0)
            saveSettings()
        }
    }

    // MARK: - Private Properties

    private let speechSynthesizer = AVSpeechSynthesizer()
    private var currentVoice: AVSpeechSynthesisVoice?
    private var announcementQueue: [String] = []
    private var isProcessingQueue = false
    private var countdownTimer: Timer?
    private var countdownCompletion: (() -> Void)?
    private var countdownTickHandler: ((Int) -> Void)?

    private let settingsKey = "VoiceAnnouncementSettings"

    // System sound IDs for bell sounds
    private let bellSoundID: SystemSoundID = 1013  // Mail sent sound (ding)

    // MARK: - Computed Properties

    /// Available voices for the current locale and English
    var availableVoices: [VoiceOption] {
        let voices = AVSpeechSynthesisVoice.speechVoices()

        // Filter for English voices and sort by quality
        let englishVoices = voices.filter { voice in
            voice.language.hasPrefix("en")
        }.sorted { v1, v2 in
            // Prioritize enhanced/premium voices
            if v1.quality != v2.quality {
                return v1.quality.rawValue > v2.quality.rawValue
            }
            return v1.name < v2.name
        }

        return englishVoices.map { voice in
            VoiceOption(
                identifier: voice.identifier,
                name: voice.name,
                language: voice.language,
                quality: voice.quality == .enhanced ? "Enhanced" : "Default"
            )
        }
    }

    /// Current voice name for display
    var currentVoiceName: String {
        currentVoice?.name ?? "Default"
    }

    // MARK: - Initialization

    override init() {
        super.init()
        speechSynthesizer.delegate = self
        loadSettings()
        setupAudioSession()
    }

    // MARK: - Audio Session Setup

    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error.localizedDescription)")
        }
    }

    // MARK: - Public Methods

    /// Speaks the given text immediately
    func speak(_ text: String) {
        guard isEnabled else { return }

        let utterance = createUtterance(for: text)
        speechSynthesizer.speak(utterance)
    }

    /// Announces an exercise with optional countdown
    func announceExercise(name: String, countdown: Bool = true, onTick: ((Int) -> Void)? = nil, completion: (() -> Void)? = nil) {
        guard isEnabled else {
            completion?()
            return
        }

        stop()

        if countdown {
            countdownCompletion = completion
            countdownTickHandler = onTick
            announceWithCountdown(exerciseName: name)
        } else {
            speak("Starting \(name)")
            completion?()
        }
    }

    /// Announces a rest period
    func announceRest(duration: Int) {
        guard isEnabled else { return }

        let formattedDuration = formatDuration(duration)
        speak("Rest for \(formattedDuration)")
    }

    /// Announces round rest
    func announceRoundRest(duration: Int, nextRound: Int) {
        guard isEnabled else { return }

        let formattedDuration = formatDuration(duration)
        speak("Round complete. Rest for \(formattedDuration). Round \(nextRound) coming up.")
    }

    /// Announces workout completion
    func announceWorkoutComplete() {
        guard isEnabled else { return }

        speak("Congratulations! Workout complete. Great job!")
    }

    /// Announces interval timer work starting with countdown, calls completion when "Go!" is said
    func announceIntervalWorkStart(completion: (() -> Void)? = nil) {
        guard isEnabled else {
            completion?()
            return
        }

        stop()
        countdownCompletion = completion
        announcementQueue = ["3", "2", "1", "Go!"]
        processNextAnnouncement()
    }

    /// Announces interval timer work ending (going to rest) with countdown
    func announceIntervalWorkEnd(completion: (() -> Void)? = nil) {
        guard isEnabled else {
            completion?()
            return
        }

        stop()
        countdownCompletion = completion
        announcementQueue = ["3", "2", "1", "Stop"]
        processNextAnnouncement()
    }

    /// Announces interval timer rest ending (going to work) with countdown
    func announceIntervalRestEnd(completion: (() -> Void)? = nil) {
        guard isEnabled else {
            completion?()
            return
        }

        stop()
        countdownCompletion = completion
        announcementQueue = ["3", "2", "1", "Go!"]
        processNextAnnouncement()
    }

    /// Plays a bell/ding sound for transitions
    func playBell() {
        guard isEnabled else { return }
        // Play system bell sound
        AudioServicesPlaySystemSound(bellSoundID)
    }

    /// Plays a double bell sound for emphasis
    func playDoubleBell() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(bellSoundID)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            AudioServicesPlaySystemSound(self.bellSoundID)
        }
    }

    /// Announces round completion for interval timer
    func announceIntervalRoundComplete(nextRound: Int, totalRounds: Int) {
        guard isEnabled else { return }

        if nextRound <= totalRounds {
            speak("Round complete. Starting round \(nextRound) of \(totalRounds)")
        } else {
            announceWorkoutComplete()
        }
    }

    /// Announces interval timer completion
    func announceIntervalComplete() {
        guard isEnabled else { return }

        stop()
        playDoubleBell()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.speak("Workout complete! Great job!")
        }
    }

    /// Announces time remaining (for warnings)
    func announceTimeWarning(seconds: Int) {
        guard isEnabled else { return }

        if seconds == 10 {
            speak("10 seconds remaining")
        } else if seconds == 5 {
            speak("5 seconds")
        } else if seconds <= 3 && seconds > 0 {
            speak("\(seconds)")
        }
    }

    /// Announces current state change
    func announceStateChange(to state: TimerState, exerciseName: String? = nil) {
        guard isEnabled else { return }

        switch state {
        case .idle:
            break
        case .working:
            if let name = exerciseName {
                speak("Go! \(name)")
            } else {
                speak("Go!")
            }
        case .resting:
            speak("Rest")
        case .roundRest:
            speak("Round rest")
        case .completed:
            announceWorkoutComplete()
        }
    }

    /// Stops current speech
    func stop() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        announcementQueue.removeAll()
        isProcessingQueue = false
        countdownCompletion = nil
        countdownTickHandler = nil

        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
    }

    // MARK: - Countdown Logic

    private func announceWithCountdown(exerciseName: String) {
        announcementQueue = [
            "Starting \(exerciseName) in",
            "3",
            "2",
            "1",
            "Go!"
        ]

        processNextAnnouncement()
    }

    private func processNextAnnouncement() {
        guard !announcementQueue.isEmpty else {
            isProcessingQueue = false
            return
        }

        isProcessingQueue = true
        let text = announcementQueue.removeFirst()
        let utterance = createUtterance(for: text)

        // Shorter pause for countdown numbers
        if ["3", "2", "1"].contains(text) {
            utterance.postUtteranceDelay = 0.6
            // Notify tick handler with the countdown number
            if let number = Int(text) {
                countdownTickHandler?(number)
            }
        } else if text.contains("in") {
            utterance.postUtteranceDelay = 0.3
        }

        speechSynthesizer.speak(utterance)
    }

    // MARK: - Helper Methods

    private func createUtterance(for text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = currentVoice ?? findBestAvailableVoice() ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = rate
        utterance.volume = volume

        // Adjust pitch based on content for more dynamic sound
        if ["Go!", "Stop!"].contains(text) {
            utterance.pitchMultiplier = 1.1  // Slightly higher for emphasis
        } else if ["3", "2", "1"].contains(text) {
            utterance.pitchMultiplier = 1.05  // Slight emphasis for countdown
        } else {
            utterance.pitchMultiplier = 1.0
        }

        // Add slight pre-utterance delay for more natural pacing
        utterance.preUtteranceDelay = 0.1

        return utterance
    }

    private func formatDuration(_ seconds: Int) -> String {
        if seconds >= 60 {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds > 0 {
                return "\(minutes) minute\(minutes > 1 ? "s" : "") and \(remainingSeconds) seconds"
            } else {
                return "\(minutes) minute\(minutes > 1 ? "s" : "")"
            }
        } else {
            return "\(seconds) seconds"
        }
    }

    private func updateVoice() {
        if selectedVoiceIdentifier.isEmpty {
            // Try to find the best available enhanced voice
            currentVoice = findBestAvailableVoice()
        } else {
            currentVoice = AVSpeechSynthesisVoice(identifier: selectedVoiceIdentifier)
        }
    }

    /// Finds the best available voice, preferring enhanced/premium voices
    private func findBestAvailableVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()

        // Filter for English voices
        let englishVoices = voices.filter { $0.language.hasPrefix("en") }

        // Prefer enhanced quality voices
        let enhancedVoices = englishVoices.filter { $0.quality == .enhanced }

        // Preferred voice names (premium/natural sounding voices on iOS)
        let preferredNames = ["Samantha", "Alex", "Ava", "Tom", "Siri"]

        // First try to find an enhanced voice with a preferred name
        for name in preferredNames {
            if let voice = enhancedVoices.first(where: { $0.name.contains(name) }) {
                return voice
            }
        }

        // Then try any enhanced English voice
        if let enhancedVoice = enhancedVoices.first {
            return enhancedVoice
        }

        // Fall back to any voice with a preferred name
        for name in preferredNames {
            if let voice = englishVoices.first(where: { $0.name.contains(name) }) {
                return voice
            }
        }

        // Final fallback to default US English
        return AVSpeechSynthesisVoice(language: "en-US")
    }

    // MARK: - Settings Persistence

    private func saveSettings() {
        let settings = VoiceSettings(
            isEnabled: isEnabled,
            voiceIdentifier: selectedVoiceIdentifier,
            rate: rate,
            volume: volume
        )

        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }

    private func loadSettings() {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(VoiceSettings.self, from: data) else {
            // Use defaults
            updateVoice()
            return
        }

        isEnabled = settings.isEnabled
        selectedVoiceIdentifier = settings.voiceIdentifier
        rate = settings.rate
        volume = settings.volume
        updateVoice()
    }

    /// Previews the current voice settings
    func previewVoice() {
        speak("This is how the voice announcements will sound during your workout.")
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceAnnouncementManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            if self.isProcessingQueue && !self.announcementQueue.isEmpty {
                // Small delay between countdown numbers
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.processNextAnnouncement()
                }
            } else {
                self.isSpeaking = false
                self.isProcessingQueue = false

                // Call completion handler when countdown queue finishes
                if let completion = self.countdownCompletion {
                    self.countdownCompletion = nil
                    completion()
                }
            }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}

// MARK: - Voice Option Model

struct VoiceOption: Identifiable, Equatable {
    let id: String
    let identifier: String
    let name: String
    let language: String
    let quality: String

    init(identifier: String, name: String, language: String, quality: String) {
        self.id = identifier
        self.identifier = identifier
        self.name = name
        self.language = language
        self.quality = quality
    }

    var displayName: String {
        let langDisplay = language.replacingOccurrences(of: "en-", with: "")
        return "\(name) (\(langDisplay)) - \(quality)"
    }
}

// MARK: - Voice Settings Model

struct VoiceSettings: Codable {
    let isEnabled: Bool
    let voiceIdentifier: String
    let rate: Float
    let volume: Float
}
