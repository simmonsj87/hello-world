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
    @State private var configuration = TimerConfiguration.default

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
                    unit: "sec"
                )
                Divider()

                ConfigurationRow(
                    title: "Rest Duration",
                    value: $configuration.restDuration,
                    range: 5...60,
                    step: 5,
                    unit: "sec"
                )
                Divider()

                ConfigurationRow(
                    title: "Cycles per Round",
                    value: $configuration.cycles,
                    range: 1...20,
                    step: 1,
                    unit: ""
                )
                Divider()

                ConfigurationRow(
                    title: "Rounds",
                    value: $configuration.rounds,
                    range: 1...10,
                    step: 1,
                    unit: ""
                )
                Divider()

                ConfigurationRow(
                    title: "Rest Between Rounds",
                    value: $configuration.restBetweenRounds,
                    range: 30...180,
                    step: 10,
                    unit: "sec"
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

            // Round and Cycle Display
            if timerManager.currentState != .completed {
                VStack(spacing: 4) {
                    Text("Round \(timerManager.currentRound) of \(timerManager.configuration.rounds)")
                        .font(.headline)
                    Text("Cycle \(timerManager.currentCycle) of \(timerManager.configuration.cycles)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Control Buttons Section

    private var controlButtonsSection: some View {
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
                StatView(title: "Cycles Done", value: "\(timerManager.totalCyclesCompleted)/\(timerManager.totalCycles)")
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
            return .yellow
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
                    .monospacedDigit()
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
        .padding(.vertical, 8)
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

// MARK: - Preview

struct TimerView_Previews: PreviewProvider {
    static var previews: some View {
        TimerView()
    }
}
