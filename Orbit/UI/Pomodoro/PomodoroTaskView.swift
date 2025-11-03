//
//  PomodoroTaskView.swift
//  Orbit
//
//  Created by Ulyana Eskova on 03.11.2025.
//


import SwiftUI
import UserNotifications

struct PomodoroTaskView: View {
    let task: Task
    var onBack: () -> Void
    
    @State private var workMinutes = 25
    @State private var restMinutes = 5
    @State private var remainingSeconds = 0
    @State private var isRunning = false
    @State private var isResting = false
    @State private var timer: Timer? = nil
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                // Навигация
                HStack {
                    Button(action: onBack) {
                        Label("Back", systemImage: "chevron.left")
                            .labelStyle(.titleAndIcon)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(isResting ? "Rest" : "Focus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isResting ? .green : .red)
                }
                
                // Информация о задаче
                VStack(spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 15, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity)
                    HStack(spacing: 4) {
                        if let p = task.priority {
                            Text(priorityString(p))
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        }
                        ForEach(task.tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 11))
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                //Divider().padding(.vertical, 4)
                
                // Таймер и настройки
                VStack(spacing: 6) {
                    Text("\(remainingSeconds / 60):\(String(format: "%02d", remainingSeconds % 60))")
                        .font(.system(size: 34, weight: .bold))
                        .monospacedDigit()
                    ProgressView(value: progress)
                        .frame(width: 140)
                }
                .padding(.bottom, 4)
                
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("Focus")
                            .font(.system(size: 11))
                        TextField("", value: $workMinutes, formatter: NumberFormatter())
                            .frame(width: 36)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(spacing: 4) {
                        Text("Rest")
                            .font(.system(size: 11))
                        TextField("", value: $restMinutes, formatter: NumberFormatter())
                            .frame(width: 36)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.bottom, 6)
                
                // Кнопки управления
                HStack(spacing: 16) {
                    if isRunning {
                        Button("Stop", action: stopTimer)
                            .font(.system(size: 12))
                            .buttonStyle(.bordered)
                            .tint(.red)
                    } else {
                        Button("Start", action: startFocus)
                            .font(.system(size: 12, weight: .semibold))
                            .buttonStyle(.borderedProminent)
                            .tint(.accentColor)
                    }
                }
                .padding(.top, 4)
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.03)))
        .onDisappear { stopTimer() }
    }
    
    // MARK: - Логика таймера
    private var totalSeconds: Int { (isResting ? restMinutes : workMinutes) * 60 }
    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - Double(remainingSeconds) / Double(totalSeconds)
    }
    
    private func startFocus() {
        isResting = false
        remainingSeconds = workMinutes * 60
        startTimer()
    }
    
    private func startTimer() {
        isRunning = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                t.invalidate()
                if isResting {
                    isRunning = false
                    sendNotification(title: "Pomodoro", body: "Rest over, time to focus 💪")
                } else {
                    startRest()
                }
            }
        }
    }
    
    private func startRest() {
        PomodoroStats.shared.addEntry(for: task, minutes: workMinutes)
        
        isResting = true
        remainingSeconds = restMinutes * 60
        startTimer()
        sendNotification(title: "Pomodoro", body: "Time to rest 🌿")
    }

    private func stopTimer() {
        if isRunning && !isResting {
            let elapsedSeconds = workMinutes * 60 - remainingSeconds
            let elapsedMinutes = max(1, elapsedSeconds / 60)
            PomodoroStats.shared.addEntry(for: task, minutes: elapsedMinutes)
        }
        timer?.invalidate()
        isRunning = false
        isResting = false
        remainingSeconds = 0
    }
    
    private func sendNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }
    
    private func priorityString(_ p: TaskPriority) -> String {
        switch p {
        case .high: return "🔴 High"
        case .medium: return "🟡 Med"
        case .low: return "🟢 Low"
        }
    }
}
