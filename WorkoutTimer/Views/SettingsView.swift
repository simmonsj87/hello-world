//
//  SettingsView.swift
//  WorkoutTimer
//
//  Placeholder view for app settings.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "gear")
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)

                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("App settings coming soon")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Settings")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
