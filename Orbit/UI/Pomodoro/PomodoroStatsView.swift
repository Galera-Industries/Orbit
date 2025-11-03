//
//  PomodoroStatsView.swift
//  Orbit
//
//  Created by Ulyana Eskova on 03.11.2025.
//

import SwiftUI

struct PomodoroStatsView: View {
    var onClose: () -> Void
    
    @State private var today = PomodoroStats.shared.statsForToday()
    @State private var week = PomodoroStats.shared.statsForThisWeek()
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button("← Back", action: onClose)
                    .buttonStyle(.plain)
                Spacer()
                Text("Pomodoro Statistics")
                    .font(.headline)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                statRow(title: "Today", value: today)
                statRow(title: "This week", value: week)
            }
            
            Spacer()
        }
        .padding(24)
        .onAppear {
            today = PomodoroStats.shared.statsForToday()
            week = PomodoroStats.shared.statsForThisWeek()
        }
    }
    
    private func statRow(title: String, value: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(value) min")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.accentColor)
        }
    }
}
