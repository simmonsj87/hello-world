//
//  SettingsView.swift
//  WorkoutTimer
//
//  Comprehensive app settings with voice, workout, timer, and data management.
//

import SwiftUI
import AVFoundation
import CoreData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var settings = SettingsManager.shared
    @StateObject private var voiceManager = VoiceAnnouncementManager()

    @FetchRequest(sortDescriptors: [])
    private var exercises: FetchedResults<Exercise>

    @FetchRequest(sortDescriptors: [])
    private var workouts: FetchedResults<Workout>

    @FetchRequest(sortDescriptors: [])
    private var categories: FetchedResults<Category>

    @State private var showingResetAlert = false
    @State private var showingExportSheet = false
    @State private var showingImportPicker = false
    @State private var showingQuickStartSaved = false
    @State private var showingExportOptions = false
    @State private var showingImportSuccess = false
    @State private var showingImportError = false
    @State private var importErrorMessage = ""
    @State private var exportURL: URL?
    @State private var exportedJSONString: String = ""
    @State private var showingDeleteAllExercisesAlert = false
    @State private var showingDeleteAllWorkoutsAlert = false

    var body: some View {
        NavigationView {
            List {
                voiceSettingsSection
                workoutDefaultsSection
                timerDefaultsSection
                appPreferencesSection
                dataManagementSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
        }
        .alert("Reset All Settings?", isPresented: $showingResetAlert) {
            Button("Reset", role: .destructive) {
                settings.resetToDefaults()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will reset all settings to their default values. Your exercises and workouts will not be affected.")
        }
        .alert("Quick Start Saved", isPresented: $showingQuickStartSaved) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your current timer settings have been saved as the Quick Start preset.")
        }
        .sheet(isPresented: $showingExportSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsSheet(
                jsonString: exportedJSONString,
                fileURL: exportURL,
                onShare: {
                    showingExportOptions = false
                    showingExportSheet = true
                }
            )
        }
        .sheet(isPresented: $showingImportPicker) {
            DocumentPicker(onDocumentPicked: importFromFile)
        }
        .alert("Import Successful", isPresented: $showingImportSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your data has been imported successfully.")
        }
        .alert("Import Failed", isPresented: $showingImportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importErrorMessage)
        }
        .alert("Delete All Exercises?", isPresented: $showingDeleteAllExercisesAlert) {
            Button("Delete All", role: .destructive) {
                deleteAllExercises()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete all \(exercises.count) exercises. This action cannot be undone.")
        }
        .alert("Delete All Workouts?", isPresented: $showingDeleteAllWorkoutsAlert) {
            Button("Delete All", role: .destructive) {
                deleteAllWorkouts()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete all \(workouts.count) workouts. This action cannot be undone.")
        }
    }

    // MARK: - Voice Settings Section

    private var voiceSettingsSection: some View {
        Section {
            // Enable/Disable
            Toggle(isOn: $settings.voiceEnabled) {
                SettingsRowLabel(
                    icon: "speaker.wave.2.fill",
                    iconColor: .blue,
                    title: "Voice Announcements"
                )
            }

            if settings.voiceEnabled {
                // Voice Selection
                NavigationLink {
                    VoiceSelectionView(selectedVoice: $settings.selectedVoiceIdentifier)
                } label: {
                    HStack {
                        Text("Voice")
                        Spacer()
                        Text(currentVoiceName)
                            .foregroundColor(.secondary)
                    }
                }

                // Speech Rate
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Speech Rate")
                        Spacer()
                        Text(speechRateLabel)
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.speechRate, in: 0.3...0.7, step: 0.05)
                }

                // Volume
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Volume")
                        Spacer()
                        Text("\(Int(settings.speechVolume * 100))%")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Image(systemName: "speaker.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Slider(value: $settings.speechVolume, in: 0.0...1.0, step: 0.1)
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }

                // Test Voice
                Button(action: testVoice) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(.accentColor)
                        Text("Test Voice")
                    }
                }
            }
        } header: {
            SectionHeader(icon: "waveform", title: "VOICE")
        }
    }

    // MARK: - Workout Defaults Section

    private var workoutDefaultsSection: some View {
        Section {
            // Default Exercise Duration
            SettingsStepperRow(
                title: "Exercise Duration",
                value: $settings.defaultExerciseDuration,
                range: 15...300,
                step: 15,
                unit: "sec"
            )

            // Rest Between Exercises
            SettingsStepperRow(
                title: "Rest Between Exercises",
                value: $settings.defaultRestBetweenExercises,
                range: 0...60,
                step: 5,
                unit: "sec"
            )

            // Rest Between Rounds
            SettingsStepperRow(
                title: "Rest Between Rounds",
                value: $settings.defaultRestBetweenRounds,
                range: 30...180,
                step: 15,
                unit: "sec"
            )

            // Auto-start
            Toggle(isOn: $settings.autoStartNextExercise) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-Start Next Exercise")
                    Text("Automatically begin next exercise after rest")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            SectionHeader(icon: "figure.run", title: "WORKOUT DEFAULTS")
        }
    }

    // MARK: - Timer Defaults Section

    private var timerDefaultsSection: some View {
        Section {
            // Work Duration
            SettingsStepperRow(
                title: "Work Duration",
                value: $settings.defaultWorkDuration,
                range: 15...180,
                step: 5,
                unit: "sec"
            )

            // Rest Duration
            SettingsStepperRow(
                title: "Rest Duration",
                value: $settings.defaultRestDuration,
                range: 5...60,
                step: 5,
                unit: "sec"
            )

            // Sets
            SettingsStepperRow(
                title: "Sets per Round",
                value: $settings.defaultCycles,
                range: 1...20,
                step: 1,
                unit: ""
            )

            // Rounds
            SettingsStepperRow(
                title: "Rounds",
                value: $settings.defaultRounds,
                range: 1...10,
                step: 1,
                unit: ""
            )

            // Quick Start Preset
            Button(action: saveQuickStartPreset) {
                HStack {
                    Image(systemName: "bolt.circle.fill")
                        .foregroundColor(.orange)
                    Text("Save as Quick Start Preset")
                    Spacer()
                    if settings.hasQuickStartPreset {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
        } header: {
            SectionHeader(icon: "timer", title: "INTERVAL TIMER DEFAULTS")
        } footer: {
            Text("These values will be used as defaults when starting the interval timer.")
        }
    }

    // MARK: - App Preferences Section

    private var appPreferencesSection: some View {
        Section {
            // Keep Screen Awake
            Toggle(isOn: $settings.keepScreenAwake) {
                SettingsRowLabel(
                    icon: "sun.max.fill",
                    iconColor: .yellow,
                    title: "Keep Screen Awake"
                )
            }

            // Notifications
            Toggle(isOn: $settings.showNotifications) {
                SettingsRowLabel(
                    icon: "bell.fill",
                    iconColor: .red,
                    title: "Workout Notifications"
                )
            }

            // Haptic Feedback
            Toggle(isOn: $settings.hapticFeedbackEnabled) {
                SettingsRowLabel(
                    icon: "iphone.radiowaves.left.and.right",
                    iconColor: .purple,
                    title: "Haptic Feedback"
                )
            }

            // Sound Effects
            Toggle(isOn: $settings.soundEffectsEnabled) {
                SettingsRowLabel(
                    icon: "speaker.wave.2.fill",
                    iconColor: .green,
                    title: "Sound Effects"
                )
            }
        } header: {
            SectionHeader(icon: "gearshape.fill", title: "APP PREFERENCES")
        }
    }

    // MARK: - Data Management Section

    private var dataManagementSection: some View {
        Section {
            // Stats
            HStack {
                SettingsRowLabel(
                    icon: "chart.bar.fill",
                    iconColor: .cyan,
                    title: "Database Stats"
                )
                Spacer()
            }

            HStack {
                Text("Exercises")
                    .padding(.leading, 40)
                Spacer()
                Text("\(exercises.count)")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Workouts")
                    .padding(.leading, 40)
                Spacer()
                Text("\(workouts.count)")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Categories")
                    .padding(.leading, 40)
                Spacer()
                Text("\(categories.count)")
                    .foregroundColor(.secondary)
            }

            // Export
            Button(action: exportData) {
                SettingsRowLabel(
                    icon: "square.and.arrow.up.fill",
                    iconColor: .green,
                    title: "Export All Data"
                )
            }

            // Import
            Button(action: { showingImportPicker = true }) {
                SettingsRowLabel(
                    icon: "square.and.arrow.down.fill",
                    iconColor: .blue,
                    title: "Import Data"
                )
            }

            // Reset Settings
            Button(action: { showingResetAlert = true }) {
                SettingsRowLabel(
                    icon: "arrow.counterclockwise",
                    iconColor: .orange,
                    title: "Reset All Settings"
                )
            }

            // Delete All Exercises
            Button(role: .destructive, action: { showingDeleteAllExercisesAlert = true }) {
                SettingsRowLabel(
                    icon: "trash.fill",
                    iconColor: .red,
                    title: "Delete All Exercises"
                )
            }
            .disabled(exercises.isEmpty)

            // Delete All Workouts
            Button(role: .destructive, action: { showingDeleteAllWorkoutsAlert = true }) {
                SettingsRowLabel(
                    icon: "trash.fill",
                    iconColor: .red,
                    title: "Delete All Workouts"
                )
            }
            .disabled(workouts.isEmpty)
        } header: {
            SectionHeader(icon: "externaldrive.fill", title: "DATA MANAGEMENT")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            // Version
            HStack {
                SettingsRowLabel(
                    icon: "info.circle.fill",
                    iconColor: .gray,
                    title: "Version"
                )
                Spacer()
                Text("1.0.0 (1)")
                    .foregroundColor(.secondary)
            }

            // Tips
            NavigationLink {
                TipsView()
            } label: {
                SettingsRowLabel(
                    icon: "lightbulb.fill",
                    iconColor: .yellow,
                    title: "Quick Tips"
                )
            }

            // Feedback
            Button(action: openFeedback) {
                SettingsRowLabel(
                    icon: "envelope.fill",
                    iconColor: .blue,
                    title: "Send Feedback"
                )
            }
        } header: {
            SectionHeader(icon: "questionmark.circle.fill", title: "ABOUT")
        } footer: {
            Text("WorkoutTimer - Built with SwiftUI")
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
        }
    }

    // MARK: - Helper Properties

    private var currentVoiceName: String {
        if settings.selectedVoiceIdentifier.isEmpty {
            return "Default"
        }
        return AVSpeechSynthesisVoice(identifier: settings.selectedVoiceIdentifier)?.name ?? "Default"
    }

    private var speechRateLabel: String {
        switch settings.speechRate {
        case 0.3..<0.4: return "Very Slow"
        case 0.4..<0.5: return "Slow"
        case 0.5..<0.55: return "Normal"
        case 0.55..<0.65: return "Fast"
        default: return "Very Fast"
        }
    }

    // MARK: - Actions

    private func testVoice() {
        // Temporarily enable voice for testing
        voiceManager.isEnabled = true
        voiceManager.selectedVoiceIdentifier = settings.selectedVoiceIdentifier
        voiceManager.rate = settings.speechRate
        voiceManager.volume = max(0.1, settings.speechVolume)  // Ensure minimum volume for test

        // Stop any existing speech first
        voiceManager.stop()

        // Use a shorter test message
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.voiceManager.speak("Testing voice. 3, 2, 1, go!")
        }
    }

    private func saveQuickStartPreset() {
        settings.saveAsQuickStartPreset()
        showingQuickStartSaved = true
        settings.triggerNotificationHaptic(.success)
    }

    private func exportData() {
        let exportData = AppDataExport(
            exportDate: Date(),
            appVersion: "1.0.0",
            exercises: exercises.compactMap { exercise in
                guard let id = exercise.id else { return nil }
                return ExerciseExport(
                    id: id,
                    name: exercise.wrappedName,
                    category: exercise.wrappedCategory,
                    createdDate: exercise.wrappedCreatedDate
                )
            },
            workouts: workouts.compactMap { workout in
                guard let id = workout.id else { return nil }
                return WorkoutExport(
                    id: id,
                    name: workout.wrappedName,
                    createdDate: workout.wrappedCreatedDate,
                    rounds: Int(workout.rounds),
                    timePerExercise: Int(workout.timePerExercise),
                    restBetweenExercises: Int(workout.restBetweenExercises),
                    restBetweenRounds: Int(workout.restBetweenRounds),
                    executionMode: workout.wrappedExecutionMode,
                    exercises: workout.workoutExercisesArray.compactMap { we in
                        guard let exerciseId = we.exercise?.id else { return nil }
                        return WorkoutExerciseExport(
                            exerciseId: exerciseId,
                            duration: Int(we.duration),
                            orderIndex: Int(we.orderIndex)
                        )
                    }
                )
            },
            categories: categories.compactMap { category in
                guard let id = category.id else { return nil }
                return CategoryExport(
                    id: id,
                    name: category.wrappedName,
                    isDefault: category.isDefault,
                    orderIndex: Int(category.orderIndex)
                )
            }
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(exportData)

            // Store JSON string for copy option
            exportedJSONString = String(data: data, encoding: .utf8) ?? ""

            let tempDir = FileManager.default.temporaryDirectory
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let fileName = "WorkoutTimer_Export_\(dateFormatter.string(from: Date())).json"
            let fileURL = tempDir.appendingPathComponent(fileName)

            try data.write(to: fileURL)
            exportURL = fileURL
            showingExportOptions = true
        } catch {
            print("Export error: \(error)")
        }
    }

    private func importFromFile(_ url: URL) {
        do {
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                importErrorMessage = "Could not access the selected file."
                showingImportError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: url)
            try importData(from: data)
            showingImportSuccess = true
        } catch {
            importErrorMessage = "Failed to import data: \(error.localizedDescription)"
            showingImportError = true
        }
    }

    private func importData(from data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let importedData = try decoder.decode(AppDataExport.self, from: data)

        // Create a mapping of old exercise IDs to new exercises
        var exerciseMapping: [UUID: Exercise] = [:]

        // Import categories first
        for categoryExport in importedData.categories {
            // Check if category already exists
            let existingCategory = categories.first { $0.wrappedName == categoryExport.name }
            if existingCategory == nil && !categoryExport.isDefault {
                let category = Category(context: viewContext)
                category.id = UUID()
                category.name = categoryExport.name
                category.isDefault = false
                category.orderIndex = Int16(categoryExport.orderIndex)
            }
        }

        // Import exercises
        for exerciseExport in importedData.exercises {
            // Check if exercise already exists by name
            let existingExercise = exercises.first { $0.wrappedName == exerciseExport.name }
            if let existing = existingExercise {
                exerciseMapping[exerciseExport.id] = existing
            } else {
                let exercise = Exercise(context: viewContext)
                exercise.id = UUID()
                exercise.name = exerciseExport.name
                exercise.category = exerciseExport.category
                exercise.createdDate = exerciseExport.createdDate
                exercise.isEnabled = true
                exerciseMapping[exerciseExport.id] = exercise
            }
        }

        // Import workouts
        for workoutExport in importedData.workouts {
            // Check if workout already exists by name
            let existingWorkout = workouts.first { $0.wrappedName == workoutExport.name }
            if existingWorkout == nil {
                let workout = Workout(context: viewContext)
                workout.id = UUID()
                workout.name = workoutExport.name
                workout.createdDate = workoutExport.createdDate
                workout.rounds = Int16(workoutExport.rounds)
                workout.timePerExercise = Int32(workoutExport.timePerExercise)
                workout.restBetweenExercises = Int32(workoutExport.restBetweenExercises)
                workout.restBetweenRounds = Int32(workoutExport.restBetweenRounds)
                workout.executionMode = workoutExport.executionMode

                // Add workout exercises
                for workoutExerciseExport in workoutExport.exercises {
                    if let exercise = exerciseMapping[workoutExerciseExport.exerciseId] {
                        let workoutExercise = WorkoutExercise(context: viewContext)
                        workoutExercise.id = UUID()
                        workoutExercise.exercise = exercise
                        workoutExercise.workout = workout
                        workoutExercise.duration = Int32(workoutExerciseExport.duration)
                        workoutExercise.orderIndex = Int16(workoutExerciseExport.orderIndex)
                    }
                }
            }
        }

        try viewContext.save()
    }

    private func openFeedback() {
        if let url = URL(string: "mailto:feedback@workouttimer.app") {
            UIApplication.shared.open(url)
        }
    }

    private func deleteAllExercises() {
        for exercise in exercises {
            viewContext.delete(exercise)
        }

        do {
            try viewContext.save()
            settings.triggerNotificationHaptic(.success)
        } catch {
            print("Error deleting all exercises: \(error)")
        }
    }

    private func deleteAllWorkouts() {
        for workout in workouts {
            viewContext.delete(workout)
        }

        do {
            try viewContext.save()
            settings.triggerNotificationHaptic(.success)
        } catch {
            print("Error deleting all workouts: \(error)")
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
            Text(title)
        }
    }
}

// MARK: - Settings Row Label

struct SettingsRowLabel: View {
    let icon: String
    let iconColor: Color
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(iconColor)
                .cornerRadius(6)

            Text(title)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Settings Stepper Row

struct SettingsStepperRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unit: String

    private var displayValue: String {
        if unit.isEmpty {
            return "\(value)"
        }
        return "\(value) \(unit)"
    }

    var body: some View {
        HStack {
            Text(title)

            Spacer()

            HStack(spacing: 12) {
                Button(action: { if value - step >= range.lowerBound { value -= step } }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(value <= range.lowerBound ? .gray : .accentColor)
                }
                .buttonStyle(.plain)
                .disabled(value <= range.lowerBound)

                Text(displayValue)
                    .font(.subheadline)
                    .monospacedDigit()
                    .frame(minWidth: 60)

                Button(action: { if value + step <= range.upperBound { value += step } }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(value >= range.upperBound ? .gray : .accentColor)
                }
                .buttonStyle(.plain)
                .disabled(value >= range.upperBound)
            }
        }
    }
}

// MARK: - Voice Selection View

struct VoiceSelectionView: View {
    @Binding var selectedVoice: String
    @Environment(\.dismiss) private var dismiss

    private var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { $0.name < $1.name }
    }

    private var groupedVoices: [(String, [AVSpeechSynthesisVoice])] {
        let grouped = Dictionary(grouping: availableVoices) { voice -> String in
            let parts = voice.language.components(separatedBy: "-")
            return parts.count > 1 ? parts[1] : "Other"
        }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        List {
            Section {
                Button(action: {
                    selectedVoice = ""
                    dismiss()
                }) {
                    HStack {
                        Text("System Default")
                        Spacer()
                        if selectedVoice.isEmpty {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }

            ForEach(groupedVoices, id: \.0) { region, voices in
                Section(header: Text(regionName(for: region))) {
                    ForEach(voices, id: \.identifier) { voice in
                        Button(action: {
                            selectedVoice = voice.identifier
                            dismiss()
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(voice.name)
                                    Text(voice.quality == .enhanced ? "Enhanced" : "Standard")
                                        .font(.caption)
                                        .foregroundColor(voice.quality == .enhanced ? .green : .secondary)
                                }
                                Spacer()
                                if selectedVoice == voice.identifier {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
        }
        .navigationTitle("Select Voice")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func regionName(for code: String) -> String {
        let names: [String: String] = [
            "US": "United States",
            "GB": "United Kingdom",
            "AU": "Australia",
            "IE": "Ireland",
            "ZA": "South Africa",
            "IN": "India"
        ]
        return names[code] ?? code
    }
}

// MARK: - Tips View

struct TipsView: View {
    var body: some View {
        List {
            Section(header: Text("Getting Started")) {
                TipRow(icon: "plus.circle", title: "Add Exercises", description: "Start by adding exercises in the Exercises tab. Include name and category for each.")
                TipRow(icon: "figure.run", title: "Create Workouts", description: "Build workouts by selecting exercises and setting durations for each.")
                TipRow(icon: "shuffle", title: "Random Workouts", description: "Use the shuffle button to generate random workouts based on your criteria.")
            }

            Section(header: Text("Timer Features")) {
                TipRow(icon: "timer", title: "Interval Timer", description: "The Timer tab offers customizable work/rest intervals with multiple rounds.")
                TipRow(icon: "speaker.wave.2", title: "Voice Guidance", description: "Enable voice announcements to hear exercise names and countdowns.")
                TipRow(icon: "bell", title: "Notifications", description: "Get notified when exercises change, even when the app is in the background.")
            }

            Section(header: Text("Pro Tips")) {
                TipRow(icon: "bolt", title: "Quick Start", description: "Save your favorite timer settings as a Quick Start preset in Settings.")
                TipRow(icon: "arrow.triangle.2.circlepath", title: "Avoid Repeats", description: "The random generator can skip exercises from your last 3 workouts.")
                TipRow(icon: "sun.max", title: "Screen Awake", description: "Enable 'Keep Screen Awake' to prevent your screen from dimming during workouts.")
            }
        }
        .navigationTitle("Quick Tips")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TipRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Export Options Sheet

struct ExportOptionsSheet: View {
    let jsonString: String
    let fileURL: URL?
    let onShare: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showingCopied = false

    var body: some View {
        NavigationView {
            List {
                Section {
                    // Share/Save to Files
                    Button(action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onShare()
                        }
                    }) {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Share or Save to Files")
                                    .foregroundColor(.primary)
                                Text("Send via AirDrop, Messages, Mail, or save to Files")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                        }
                    }

                    // Copy to Clipboard
                    Button(action: copyToClipboard) {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Copy to Clipboard")
                                        .foregroundColor(.primary)
                                    if showingCopied {
                                        Text("Copied!")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                                Text("Copy JSON data to paste elsewhere")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.green)
                        }
                    }
                } header: {
                    Text("Export Options")
                } footer: {
                    Text("Data is exported in JSON format, which can be imported on another device or shared with others.")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ScrollView {
                            Text(jsonString.prefix(2000) + (jsonString.count > 2000 ? "\n..." : ""))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxHeight: 200)
                    }
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = jsonString
        withAnimation {
            showingCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showingCopied = false
            }
        }
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    let onDocumentPicked: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentPicked: onDocumentPicked)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDocumentPicked: (URL) -> Void

        init(onDocumentPicked: @escaping (URL) -> Void) {
            self.onDocumentPicked = onDocumentPicked
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onDocumentPicked(url)
        }
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    }
}
