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
    @Published var isEnabled: Bool = true

    /// Selected voice identifier
    @Published var selectedVoiceIdentifier: String = "" {
        didSet {
            updateVoice()
        }
    }

    /// Speech rate (0.3 - 0.7, default 0.48 for more natural sound)
    @Published var rate: Float = 0.48

    /// Speech volume (0.0 - 1.0, default 0.8)
    @Published var volume: Float = 0.8

    // MARK: - Private Properties

    private let speechSynthesizer = AVSpeechSynthesizer()
    private var currentVoice: AVSpeechSynthesisVoice?
    private var announcementQueue: [String] = []
    private var isProcessingQueue = false
    private var countdownTimer: Timer?
    private var countdownCompletion: (() -> Void)?
    private var countdownTickHandler: ((Int) -> Void)?
    private var triggerOnStart: Bool = false  // Whether to trigger completion on speech start
    private var currentUtteranceText: String = ""  // Track current utterance for start detection

    // System sound IDs for bell sounds
    private let bellSoundID: SystemSoundID = 1013  // Mail sent sound (ding)

    // Background keepalive: a silent audio player that loops continuously while a workout
    // is active. This ensures the audio session stays in the "playing" state so iOS never
    // suspends the app between voice announcements. Without this, iOS can suspend the app
    // during silent gaps and the next announcement will never fire.
    private var keepAlivePlayer: AVAudioPlayer?

    /// Whether a workout is currently active (keepalive is running)
    private var isWorkoutActive: Bool = false

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
        registerAudioSessionObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Audio Session Setup

    private func setupAudioSession() {
        do {
            // .default mode (not .spokenAudio): .spokenAudio is designed for audiobooks —
            // iOS automatically mutes the session when ANY other audio starts and keeps it
            // muted indefinitely. That breaks coexistence with Spotify. .default lets us
            // control ducking ourselves via .duckOthers/.mixWithOthers.
            // .mixWithOthers: initial/idle mode so the keepalive player does not duck music;
            //   we switch to .duckOthers only while an announcement is actually speaking.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    // MARK: - Audio Session Notification Observers

    private func registerAudioSessionObservers() {
        // Re-arm the keepalive when an interruption ends (e.g., Spotify paused between
        // songs, phone call finished, Siri dismissed). Without this the keepalive stays
        // dead after iOS mutes our session for the interruption.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )

        // The media server occasionally crashes and restarts; rebuild everything after.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServicesReset(_:)),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: nil
        )
    }

    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            // Another app (Spotify, phone call, Siri) has taken the audio session.
            // The keepalive player is now paused by the system — nothing to do here;
            // we wait for .ended to re-arm.
            break

        case .ended:
            // The interrupting source has relinquished the session.
            // Re-arm if a workout is still running so background execution resumes.
            guard isWorkoutActive else { return }
            DispatchQueue.main.async { [weak self] in
                self?.startBackgroundKeepAlive()
            }

        @unknown default:
            break
        }
    }

    @objc private func handleMediaServicesReset(_ notification: Notification) {
        // The media server crashed and restarted. All audio objects are invalid.
        // Rebuild the session and keepalive from scratch.
        setupAudioSession()
        if isWorkoutActive {
            DispatchQueue.main.async { [weak self] in
                self?.startBackgroundKeepAlive()
            }
        }
    }

    // MARK: - Background Keepalive

    /// Called when a workout or interval timer starts, and again when returning from background
    /// after an interruption (phone call, Siri) that may have stopped the silent player.
    /// Ensures the audio session stays in the "playing" state so iOS never suspends the app
    /// between voice announcements.
    func startBackgroundKeepAlive() {
        isWorkoutActive = true

        // Always (re-)activate the session — it may have been deactivated by an interruption.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Failed to activate audio session for keepalive: \(error)")
        }

        // Skip rebuilding the player if it is already playing — no need to restart it.
        if keepAlivePlayer?.isPlaying == true { return }

        // Build a minimal valid WAV (1 s of silence at 8 kHz mono 16-bit) entirely in
        // memory — no bundle resource needed. AVAudioPlayer loops it indefinitely with
        // virtually zero CPU or battery impact while keeping the session "playing".
        keepAlivePlayer?.stop()
        keepAlivePlayer = nil

        if let data = VoiceAnnouncementManager.makeSilentWAVData(),
           let player = try? AVAudioPlayer(data: data) {
            player.numberOfLoops = -1   // loop forever
            player.volume = 0.01        // near-silent but non-zero so iOS treats it as playing
            player.prepareToPlay()
            player.play()
            keepAlivePlayer = player
        }
    }

    /// Generates a minimal valid 16-bit mono PCM WAV file containing 1 second of silence.
    private static func makeSilentWAVData() -> Data? {
        let sampleRate: UInt32 = 8000           // 8 kHz — tiny file, more than sufficient
        let numSamples: UInt32 = sampleRate     // 1 second
        let dataSize = numSamples * 2           // 16-bit = 2 bytes per sample

        var d = Data(capacity: 44 + Int(dataSize))

        // Little-endian helpers
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }

        d.append(contentsOf: [0x52, 0x49, 0x46, 0x46])  // "RIFF"
        u32(36 + dataSize)                               // RIFF chunk size
        d.append(contentsOf: [0x57, 0x41, 0x56, 0x45])  // "WAVE"

        d.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])  // "fmt "
        u32(16)                                          // fmt chunk size
        u16(1)                                           // PCM
        u16(1)                                           // 1 channel
        u32(sampleRate)
        u32(sampleRate * 2)                              // byte rate
        u16(2)                                           // block align
        u16(16)                                          // bits per sample

        d.append(contentsOf: [0x64, 0x61, 0x74, 0x61])  // "data"
        u32(dataSize)
        d.append(contentsOf: [UInt8](repeating: 0, count: Int(dataSize)))

        return d
    }

    /// Switches the session to .duckOthers so background music lowers while TTS plays.
    private func activateDucking() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// Restores the session to .mixWithOthers after an announcement finishes, so music
    /// returns to full volume. Keeps the session active (does NOT call setActive(false))
    /// so background execution is not interrupted between announcements.
    private func restoreToMixMode() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
    }

    // MARK: - Public Methods

    /// Speaks the given text immediately
    func speak(_ text: String) {
        guard isEnabled, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        // Switch to .duckOthers so music lowers while we speak, and ensure the session
        // is active (re-activates automatically if it was deactivated by an interruption)
        activateDucking()

        let utterance = createUtterance(for: text)

        // Stop any current speech before starting new
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        speechSynthesizer.speak(utterance)
    }

    /// Announces an exercise with optional countdown
    func announceExercise(name: String, countdown: Bool = true, onTick: ((Int) -> Void)? = nil, completion: (() -> Void)? = nil) {
        guard isEnabled else {
            completion?()
            return
        }

        cancelSpeech()  // cancel in-progress speech; keepalive stays running

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

        cancelSpeech()  // cancel in-progress speech; keepalive stays running
        startPreciseCountdown(endWord: "Go!", completion: completion)
    }

    /// Announces interval timer work ending (going to rest) with countdown
    func announceIntervalWorkEnd(completion: (() -> Void)? = nil) {
        guard isEnabled else {
            completion?()
            return
        }

        cancelSpeech()  // cancel in-progress speech; keepalive stays running
        startPreciseCountdown(endWord: "Stop", completion: completion)
    }

    /// Announces interval timer rest ending (going to work) with countdown
    func announceIntervalRestEnd(completion: (() -> Void)? = nil) {
        guard isEnabled else {
            completion?()
            return
        }

        cancelSpeech()  // cancel in-progress speech; keepalive stays running
        startPreciseCountdown(endWord: "Go!", completion: completion)
    }

    /// Starts a countdown: 3, 2, 1, [endWord]
    /// Uses 1-second intervals between numbers, then a shorter gap before the final word
    /// so "Go!" or "Stop" follows "1" quickly and naturally.
    private func startPreciseCountdown(endWord: String, completion: (() -> Void)?) {
        countdownTimer?.invalidate()
        countdownCompletion = completion

        let countdownSequence = ["3", "2", "1", endWord]
        var currentIndex = 0

        // Speak "3" immediately
        speakCountdownWord(countdownSequence[currentIndex])
        currentIndex += 1

        // Schedule "2" and "1" at 1-second intervals, then schedule the final word
        // with a shorter delay so it follows "1" naturally without a full 1-second pause.
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            guard currentIndex < countdownSequence.count else {
                timer.invalidate()
                self.countdownTimer = nil
                return
            }

            let word = countdownSequence[currentIndex]
            let isPenultimate = (currentIndex == countdownSequence.count - 2) // about to speak "1"

            self.speakCountdownWord(word)
            currentIndex += 1

            if isPenultimate {
                // Just spoke "1" — stop the repeating timer and schedule the final
                // word after a shorter delay (0.65s) for a natural "one… GO!" rhythm.
                timer.invalidate()
                self.countdownTimer = nil
                let finalWord = countdownSequence[currentIndex]
                currentIndex += 1
                let finalTimer = Timer.scheduledTimer(withTimeInterval: 0.65, repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    self.speakCountdownWord(finalWord)
                    self.countdownTimer = nil
                    if let comp = self.countdownCompletion {
                        self.countdownCompletion = nil
                        comp()
                    }
                }
                // .common mode ensures this fires even when the app is in the background
                RunLoop.main.add(finalTimer, forMode: .common)
                self.countdownTimer = finalTimer
            } else if currentIndex >= countdownSequence.count {
                timer.invalidate()
                self.countdownTimer = nil
                if let comp = self.countdownCompletion {
                    self.countdownCompletion = nil
                    comp()
                }
            }
        }
        // .common mode ensures this fires even when the app is in the background
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }

    /// Speaks a single countdown word without delays
    private func speakCountdownWord(_ word: String) {
        guard !word.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        activateDucking()
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = currentVoice ?? findBestAvailableVoice() ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.52  // Slightly faster for crisp countdown
        utterance.volume = min(max(volume, 0.0), 1.0)
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0

        // Emphasize Go! and Stop
        if ["Go!", "Stop"].contains(word) {
            utterance.pitchMultiplier = 1.15
        } else {
            utterance.pitchMultiplier = 1.05
        }

        speechSynthesizer.speak(utterance)
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

        // Use cancelSpeech() (not stop()) so the keepalive player stays running through the
        // final announcement. Calling stop() here would deactivate the session before
        // "Workout complete!" fires, causing it to silently fail in the background.
        // The caller (IntervalTimerManager) will invoke voiceManager?.stop() on the next
        // explicit stop/dismiss action, which is the correct time to tear down the session.
        cancelSpeech()
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

    /// Cancels any in-progress speech and clears the queue WITHOUT touching the keepalive
    /// player or audio session. Use this before starting a new announcement mid-workout
    /// so background execution continues uninterrupted.
    func cancelCurrentSpeech() {
        cancelSpeech()
    }

    /// Stops all speech, stops the keepalive, and deactivates the audio session.
    /// Call this ONLY when the workout/timer is fully done — never between announcements.
    func stop() {
        cancelSpeech()

        // Tear down the keepalive and release the session so any ducked music is restored.
        isWorkoutActive = false
        keepAlivePlayer?.stop()
        keepAlivePlayer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Private Speech Cancellation

    private func cancelSpeech() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        announcementQueue.removeAll()
        isProcessingQueue = false
        countdownCompletion = nil
        countdownTickHandler = nil
        triggerOnStart = false
        currentUtteranceText = ""

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
        currentUtteranceText = text  // Track for start detection

        // Set flag to trigger completion when "Go!" or "Stop" STARTS (not finishes)
        if ["Go!", "Stop"].contains(text) && announcementQueue.isEmpty {
            triggerOnStart = true
        }

        let utterance = createUtterance(for: text)

        // Shorter pause for countdown numbers
        if ["3", "2", "1"].contains(text) {
            utterance.postUtteranceDelay = 0.5  // Slightly shorter for snappier countdown
            // Notify tick handler with the countdown number
            if let number = Int(text) {
                countdownTickHandler?(number)
            }
        } else if text.contains("in") {
            utterance.postUtteranceDelay = 0.3
        } else if ["Go!", "Stop"].contains(text) {
            // No pre-delay for Go/Stop - should be immediate
            utterance.preUtteranceDelay = 0
        }

        // Ensure session is active and music ducks before speaking. The queue processor
        // calls speechSynthesizer.speak() directly (bypassing speak()), so it must call
        // activateDucking() itself; otherwise queue announcements play without ducking.
        activateDucking()
        speechSynthesizer.speak(utterance)
    }

    // MARK: - Helper Methods

    private func createUtterance(for text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)

        // Get voice with fallback chain
        var voice = currentVoice
        if voice == nil {
            voice = findBestAvailableVoice()
        }
        if voice == nil {
            voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        if voice == nil {
            // Final fallback - get any available voice
            voice = AVSpeechSynthesisVoice.speechVoices().first
        }
        utterance.voice = voice

        // Ensure rate and volume are within valid ranges
        let safeRate = min(max(rate, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
        let safeVolume = min(max(volume, 0.0), 1.0)

        utterance.rate = safeRate
        utterance.volume = safeVolume

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

    // MARK: - Settings Loading

    /// Loads voice settings from SettingsManager (single source of truth).
    private func loadSettings() {
        let settings = SettingsManager.shared
        isEnabled = settings.voiceEnabled
        selectedVoiceIdentifier = settings.selectedVoiceIdentifier
        rate = settings.speechRate
        volume = settings.speechVolume
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

            // Trigger completion immediately when "Go!" or "Stop" STARTS speaking
            // This ensures the timer starts/stops exactly when the word begins
            if self.triggerOnStart {
                self.triggerOnStart = false
                if let completion = self.countdownCompletion {
                    self.countdownCompletion = nil
                    completion()
                }
            }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            if self.isProcessingQueue && !self.announcementQueue.isEmpty {
                // More items in the queue — keep ducking and speak the next one
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.processNextAnnouncement()
                }
            } else {
                self.isSpeaking = false
                self.isProcessingQueue = false

                // Only restore when the countdown timer is also done (i.e., all speech
                // for this announcement sequence is truly finished).
                if self.countdownTimer == nil {
                    // Switch back to .mixWithOthers so background music returns to full
                    // volume. Do NOT call setActive(false) — that would let iOS suspend
                    // the app and silence all subsequent announcements.
                    self.restoreToMixMode()
                }
                // Note: countdownCompletion is always fired earlier — either from
                // the finalTimer closure in startPreciseCountdown (for interval
                // countdowns) or from didStart when triggerOnStart is true (for queue
                // countdowns). There is no path where it is still non-nil here.
            }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.triggerOnStart = false
            // Only restore mix mode if no new speech has already started. If a new
            // utterance began between the stopSpeaking(at: .immediate) call and this
            // async dispatch, changing the session category here would corrupt the
            // new utterance's audio buffer (AVAudioBuffer.mm crash).
            if !self.speechSynthesizer.isSpeaking {
                self.restoreToMixMode()
            }
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

