//
//  VoiceSettingsView.swift
//  WorkoutTimer
//
//  View for configuring voice announcement settings.
//

import SwiftUI

struct VoiceSettingsView: View {
    @ObservedObject var voiceManager: VoiceAnnouncementManager

    @State private var showingVoicePicker = false

    var body: some View {
        Form {
            // Enable/Disable Section
            Section {
                Toggle("Voice Announcements", isOn: $voiceManager.isEnabled)
            } footer: {
                Text("Voice announcements will guide you through your workout with exercise names, countdowns, and rest period notifications.")
            }

            if voiceManager.isEnabled {
                // Voice Selection Section
                Section(header: Text("Voice")) {
                    Button(action: { showingVoicePicker = true }) {
                        HStack {
                            Text("Selected Voice")
                            Spacer()
                            Text(voiceManager.currentVoiceName)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                }

                // Speed Section
                Section(header: Text("Speed")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Speech Rate")
                            Spacer()
                            Text(speedLabel)
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $voiceManager.rate, in: 0.3...0.7, step: 0.05)

                        HStack {
                            Text("Slower")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Faster")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Volume Section
                Section(header: Text("Volume")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Announcement Volume")
                            Spacer()
                            Text("\(Int(voiceManager.volume * 100))%")
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Image(systemName: "speaker.fill")
                                .foregroundColor(.secondary)
                            Slider(value: $voiceManager.volume, in: 0.0...1.0, step: 0.1)
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Preview Section
                Section {
                    Button(action: {
                        voiceManager.previewVoice()
                    }) {
                        HStack {
                            Image(systemName: voiceManager.isSpeaking ? "stop.circle.fill" : "play.circle.fill")
                                .foregroundColor(.accentColor)
                            Text(voiceManager.isSpeaking ? "Speaking..." : "Preview Voice")
                        }
                    }
                    .disabled(voiceManager.isSpeaking)
                } footer: {
                    Text("Tap to hear a sample announcement with your current settings.")
                }

                // Announcement Types Section
                Section(header: Text("What Gets Announced")) {
                    AnnouncementInfoRow(icon: "figure.run", title: "Exercise Start", description: "Name and 3-2-1 countdown")
                    AnnouncementInfoRow(icon: "pause.circle", title: "Rest Periods", description: "Rest duration announcements")
                    AnnouncementInfoRow(icon: "clock", title: "Time Warnings", description: "10, 5, 3, 2, 1 second alerts")
                    AnnouncementInfoRow(icon: "checkmark.circle", title: "Completion", description: "Workout complete message")
                }
            }
        }
        .navigationTitle("Voice Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingVoicePicker) {
            VoicePickerView(voiceManager: voiceManager)
        }
    }

    private var speedLabel: String {
        switch voiceManager.rate {
        case 0.3..<0.4:
            return "Very Slow"
        case 0.4..<0.5:
            return "Slow"
        case 0.5..<0.55:
            return "Normal"
        case 0.55..<0.6:
            return "Fast"
        default:
            return "Very Fast"
        }
    }
}

// MARK: - Announcement Info Row

struct AnnouncementInfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Voice Picker View

struct VoicePickerView: View {
    @ObservedObject var voiceManager: VoiceAnnouncementManager
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    private var filteredVoices: [VoiceOption] {
        if searchText.isEmpty {
            return voiceManager.availableVoices
        }
        return voiceManager.availableVoices.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.language.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedVoices: [(String, [VoiceOption])] {
        let grouped = Dictionary(grouping: filteredVoices) { voice -> String in
            // Group by language variant
            let parts = voice.language.components(separatedBy: "-")
            if parts.count >= 2 {
                return languageName(for: parts[1])
            }
            return "English"
        }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(groupedVoices, id: \.0) { region, voices in
                    Section(header: Text(region)) {
                        ForEach(voices) { voice in
                            VoiceRow(
                                voice: voice,
                                isSelected: voice.identifier == voiceManager.selectedVoiceIdentifier,
                                onSelect: {
                                    voiceManager.selectedVoiceIdentifier = voice.identifier
                                    // Preview the selected voice
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        voiceManager.speak("Hello, I'm \(voice.name)")
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search voices")
            .navigationTitle("Select Voice")
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

    private func languageName(for code: String) -> String {
        let names: [String: String] = [
            "US": "United States",
            "GB": "United Kingdom",
            "AU": "Australia",
            "IE": "Ireland",
            "ZA": "South Africa",
            "IN": "India",
            "SG": "Singapore",
            "NZ": "New Zealand",
            "CA": "Canada"
        ]
        return names[code] ?? code
    }
}

// MARK: - Voice Row

struct VoiceRow: View {
    let voice: VoiceOption
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(voice.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(voice.quality)
                        .font(.caption)
                        .foregroundColor(voice.quality == "Enhanced" ? .green : .secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
}

// MARK: - Preview

struct VoiceSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            VoiceSettingsView(voiceManager: VoiceAnnouncementManager())
        }
    }
}
