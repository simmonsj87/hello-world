//
//  TimerView.swift
//  WorkoutTimer
//
//  Placeholder view for the workout timer functionality.
//

import SwiftUI

struct TimerView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "timer")
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)

                Text("Timer")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Workout timer coming soon")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Timer")
        }
    }
}

struct TimerView_Previews: PreviewProvider {
    static var previews: some View {
        TimerView()
    }
}
