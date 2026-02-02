//
//  TimerView.swift
//  WorkoutTimer
//
//  Interval timer view with configuration, progress display, and controls.
//

import SwiftUI

struct TimerView: View {
    @StateObject private var timerManager = IntervalTimerManager()
    @StateObject private var voiceManager = VoiceAnnouncementManager()
    @ObservedObject private var presetsManager = TimerPresetsManager.shared
    @State private var configuration = TimerConfiguration.default
    @State private var showingSaveSheet = false
    @State private var showingLoadSheet = false
    @State private var presetName = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if timerManager.currentState == .idle {
                        // Show total time and START button prominently at top
                        idleHeaderSection

                        // Configuration below
                        configurationSection
                    } else {
                        timerDisplaySection

                        controlButtonsSection

                        progressInfoSection
                    }
                }
                .padding()
            }
            .navigationTitle("Interval Timer")
            .toolbar {
                if timerManager.currentState == .idle {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { showingLoadSheet = true }) {
                            Image(systemName: "folder")
                        }
                        .disabled(presetsManager.presets.isEmpty)
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingSaveSheet = true }) {
                            Image(systemName: "square.and.arrow.down")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSaveSheet) {
                SaveTimerPresetSheet(
                    presetName: $presetName,
                    configuration: configuration,
                    onSave: { name in
                        let preset = SavedTimerPreset(name: name, configuration: configuration)
                        presetsManager.save(preset)
                        presetName = ""
                        showingSaveSheet = false
                    }
                )
            }
            .sheet(isPresented: $showingLoadSheet) {
                LoadTimerPresetSheet(
                    presets: presetsManager.presets,
                    onSelect: { preset in
                        configuration = preset.configuration
                        showingLoadSheet = false
                    },
                    onDelete: { indexSet in
                        presetsManager.delete(at: indexSet)
                    }
                )
            }
            .onAppear {
                timerManager.voiceManager = voiceManager
            }
            .onChange(of: configuration) { _, newConfig in
                timerManager.configuration = newConfig
            }
        }
    }

    // MARK: - Idle Header Section (Start Button at Top)

    private var idleHeaderSection: some View {
        VStack(spacing: 16) {
            // Total Duration Display
            VStack(spacing: 4) {
                Text("Total Workout Time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(configuration.formattedTotalDuration)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)
            }

            // Prominent START Button
            Button(action: {
                timerManager.configuration = configuration
                timerManager.start()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "play.fill")
                        .font(.title2)
                    Text("START")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.green)
                .cornerRadius(16)
            }

            // Save and Load Buttons
            HStack(spacing: 12) {
                Button(action: { showingLoadSheet = true }) {
                    HStack {
                        Image(systemName: "folder")
                        Text("Load Saved")
                    }
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(10)
                }
                .disabled(presetsManager.presets.isEmpty)
                .opacity(presetsManager.presets.isEmpty ? 0.5 : 1)

                Button(action: { showingSaveSheet = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save Timer")
                    }
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Configuration Section

    private var configurationSection: some View {
        VStack(spacing: 12) {
            // Section Header
            HStack {
                Text("SETTINGS")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }

            // Configuration Steppers
            VStack(spacing: 0) {
                ConfigurationRow(
                    title: "Work Duration",
                    value: $configuration.workDuration,
                    range: 15...180,
                    step: 5,
                    unit: "sec",
                    valueColor: .green
                )
                Divider().padding(.vertical, 4)

                ConfigurationRow(
                    title: "Rest Duration",
                    value: $configuration.restDuration,
                    range: 5...60,
                    step: 5,
                    unit: "sec",
                    valueColor: .orange
                )
                Divider().padding(.vertical, 4)

                ConfigurationRow(
                    title: "Sets per Round",
                    value: $configuration.cycles,
                    range: 1...20,
                    step: 1,
                    unit: "",
                    valueColor: .primary
                )
                Divider().padding(.vertical, 4)

                ConfigurationRow(
                    title: "Rounds",
                    value: $configuration.rounds,
                    range: 1...10,
                    step: 1,
                    unit: "",
                    valueColor: .primary
                )
                Divider().padding(.vertical, 4)

                ConfigurationRow(
                    title: "Rest Between Rounds",
                    value: $configuration.restBetweenRounds,
                    range: 30...180,
                    step: 10,
                    unit: "sec",
                    valueColor: .blue
                )
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Timer Display Section

    private var timerDisplaySection: some View {
        VStack(spacing: 20) {
            // Progress Circle with Time
            ZStack {
                // Background Circle
                Circle()
                    .stroke(lineWidth: 20)
                    .opacity(0.2)
                    .foregroundColor(stateColor)

                // Progress Circle
                Circle()
                    .trim(from: 0.0, to: progressForCurrentInterval)
                    .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
                    .foregroundColor(stateColor)
                    .rotationEffect(Angle(degrees: -90))
                    .animation(.linear(duration: 0.5), value: progressForCurrentInterval)

                // Time Display
                VStack(spacing: 8) {
                    Text(timerManager.formattedTimeRemaining)
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundColor(stateColor)
                        .monospacedDigit()

                    Text(timerManager.currentState.displayName.uppercased())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(stateColor)

                    if timerManager.isPaused {
                        Text("PAUSED")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
            }
            .frame(width: 300, height: 300)
            .padding()

            // Round and Set Display
            if timerManager.currentState != .completed {
                VStack(spacing: 4) {
                    Text("Round \(timerManager.currentRound) of \(timerManager.configuration.rounds)")
                        .font(.headline)
                    Text("Set \(timerManager.currentCycle) of \(timerManager.configuration.cycles)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Control Buttons Section

    private var controlButtonsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                // Reset Button
                Button(action: {
                    timerManager.reset()
                }) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .cornerRadius(12)
                }

                // Start/Pause/Resume Button
                Button(action: {
                    handleMainButtonTap()
                }) {
                    Label(mainButtonTitle, systemImage: mainButtonIcon)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(mainButtonColor)
                        .cornerRadius(12)
                }
            }

            // Exit Button
            Button(action: {
                timerManager.stop()
            }) {
                Label("Exit Timer", systemImage: "xmark.circle")
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal)
    }

    // MARK: - Progress Info Section

    private var progressInfoSection: some View {
        VStack(spacing: 12) {
            // Overall Progress Bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Overall Progress")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(timerManager.progress * 100))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)

                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: geometry.size.width * timerManager.progress, height: 8)
                            .cornerRadius(4)
                            .animation(.easeInOut, value: timerManager.progress)
                    }
                }
                .frame(height: 8)
            }

            // Stats
            HStack {
                StatView(title: "Sets Done", value: "\(timerManager.totalCyclesCompleted)/\(timerManager.totalCycles)")
                Spacer()
                StatView(title: "Current State", value: timerManager.currentState.displayName)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Computed Properties

    private var stateColor: Color {
        switch timerManager.currentState {
        case .idle:
            return .gray
        case .working:
            return .green
        case .resting:
            return .orange
        case .roundRest:
            return .blue
        case .completed:
            return .purple
        }
    }

    private var progressForCurrentInterval: CGFloat {
        let totalTime: Int
        switch timerManager.currentState {
        case .idle:
            return 1.0
        case .working:
            totalTime = timerManager.configuration.workDuration
        case .resting:
            totalTime = timerManager.configuration.restDuration
        case .roundRest:
            totalTime = timerManager.configuration.restBetweenRounds
        case .completed:
            return 1.0
        }

        guard totalTime > 0 else { return 0 }
        return CGFloat(timerManager.timeRemaining) / CGFloat(totalTime)
    }

    private var mainButtonTitle: String {
        switch timerManager.currentState {
        case .idle:
            return "Start"
        case .completed:
            return "Start Again"
        default:
            return timerManager.isPaused ? "Resume" : "Pause"
        }
    }

    private var mainButtonIcon: String {
        switch timerManager.currentState {
        case .idle, .completed:
            return "play.fill"
        default:
            return timerManager.isPaused ? "play.fill" : "pause.fill"
        }
    }

    private var mainButtonColor: Color {
        switch timerManager.currentState {
        case .idle, .completed:
            return .green
        default:
            return timerManager.isPaused ? .green : .orange
        }
    }

    // MARK: - Actions

    private func handleMainButtonTap() {
        switch timerManager.currentState {
        case .idle, .completed:
            timerManager.configuration = configuration
            timerManager.start()
        default:
            timerManager.togglePause()
        }
    }
}

// MARK: - Supporting Views

struct ConfigurationRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unit: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)

            Spacer()

            HStack(spacing: 12) {
                Button(action: {
                    if value - step >= range.lowerBound {
                        value -= step
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(value <= range.lowerBound ? .gray : .accentColor)
                }
                .disabled(value <= range.lowerBound)

                Text("\(value)\(unit.isEmpty ? "" : " \(unit)")")
                    .font(.headline)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundColor(valueColor)
                    .frame(minWidth: 70)

                Button(action: {
                    if value + step <= range.upperBound {
                        value += step
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(value >= range.upperBound ? .gray : .accentColor)
                }
                .disabled(value >= range.upperBound)
            }
        }
        .padding(.vertical, 12)
    }
}

struct StatView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Save Timer Preset Sheet

struct SaveTimerPresetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var presetName: String
    let configuration: TimerConfiguration
    let onSave: (String) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Preset Name")) {
                    TextField("Enter a name", text: $presetName)
                        .textInputAutocapitalization(.words)
                }

                Section(header: Text("Configuration Summary")) {
                    LabeledContent("Work Duration", value: "\(configuration.workDuration) sec")
                    LabeledContent("Rest Duration", value: "\(configuration.restDuration) sec")
                    LabeledContent("Sets per Round", value: "\(configuration.cycles)")
                    LabeledContent("Rounds", value: "\(configuration.rounds)")
                    LabeledContent("Rest Between Rounds", value: "\(configuration.restBetweenRounds) sec")
                    LabeledContent("Total Duration", value: configuration.formattedTotalDuration)
                }

                Section {
                    Button(action: {
                        let trimmed = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onSave(trimmed)
                    }) {
                        HStack {
                            Spacer()
                            Text("Save Preset")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Save Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Load Timer Preset Sheet

struct LoadTimerPresetSheet: View {
    @Environment(\.dismiss) private var dismiss
    let presets: [SavedTimerPreset]
    let onSelect: (SavedTimerPreset) -> Void
    let onDelete: (IndexSet) -> Void

    var body: some View {
        NavigationView {
            List {
                ForEach(presets) { preset in
                    Button(action: { onSelect(preset) }) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(preset.name)
                                .font(.headline)
                                .foregroundColor(.primary)

                            HStack(spacing: 16) {
                                Label("\(preset.configuration.workDuration)s work", systemImage: "flame.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)

                                Label("\(preset.configuration.restDuration)s rest", systemImage: "pause.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }

                            HStack(spacing: 16) {
                                Label("\(preset.configuration.cycles) sets × \(preset.configuration.rounds) rounds", systemImage: "repeat")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Label(preset.configuration.formattedTotalDuration, systemImage: "clock")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: onDelete)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Saved Timers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }
}

// MARK: - Preview

struct TimerView_Previews: PreviewProvider {
    static var previews: some View {
        TimerView()
    }
}
