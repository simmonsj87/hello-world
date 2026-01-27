//
//  SettingsView.swift
//  WorkoutTimer
//
//  App settings including voice announcements, timer defaults, and app info.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var voiceManager = VoiceAnnouncementManager()

    var body: some View {
        NavigationView {
            List {
                // Voice Announcements Section
                Section {
                    NavigationLink(destination: VoiceSettingsView(voiceManager: voiceManager)) {
                        SettingsRow(
                            icon: "speaker.wave.2.fill",
                            iconColor: .blue,
                            title: "Voice Announcements",
                            subtitle: voiceManager.isEnabled ? "On" : "Off"
                        )
                    }
                } header: {
                    Text("Audio")
                }

                // Timer Defaults Section
                Section {
                    SettingsRow(
                        icon: "timer",
                        iconColor: .orange,
                        title: "Default Timer Settings",
                        subtitle: "Coming soon"
                    )
                    .foregroundColor(.secondary)

                    SettingsRow(
                        icon: "bell.fill",
                        iconColor: .red,
                        title: "Notifications",
                        subtitle: "Coming soon"
                    )
                    .foregroundColor(.secondary)
                } header: {
                    Text("Timer")
                }

                // Data Section
                Section {
                    SettingsRow(
                        icon: "square.and.arrow.up",
                        iconColor: .green,
                        title: "Export Workouts",
                        subtitle: "Coming soon"
                    )
                    .foregroundColor(.secondary)

                    SettingsRow(
                        icon: "square.and.arrow.down",
                        iconColor: .purple,
                        title: "Import Workouts",
                        subtitle: "Coming soon"
                    )
                    .foregroundColor(.secondary)
                } header: {
                    Text("Data")
                }

                // About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(iconColor)
                .cornerRadius(6)

            Text(title)

            Spacer()

            Text(subtitle)
                .foregroundColor(.secondary)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
