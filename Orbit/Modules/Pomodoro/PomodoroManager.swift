//
//  PomodoroManager.swift
//  Orbit
//
//  Created by Ulyana Eskova on 03.11.2025.
//


import Foundation
import Combine

enum PomodoroPhase {
    case idle
    case focus
    case rest
}

final class PomodoroManager: ObservableObject {
    static let shared = PomodoroManager()
    
    @Published var phase: PomodoroPhase = .idle
    @Published var remaining: TimeInterval = 0
    @Published var currentTaskID: UUID?
    @Published var currentTaskTitle: String?
    
    private var timer: Timer?
    private var total: TimeInterval = 0
    private var rest: TimeInterval = 300 // 5 min
    
    func start(for task: Task, focusMinutes: Int = 25, restMinutes: Int = 5) {
        stop()
        currentTaskID = task.id
        currentTaskTitle = task.title
        total = TimeInterval(focusMinutes * 60)
        remaining = total
        rest = TimeInterval(restMinutes * 60)
        phase = .focus
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        phase = .idle
        remaining = 0
        currentTaskID = nil
        currentTaskTitle = nil
    }
    
    private func tick() {
        remaining -= 1
        if remaining <= 0 {
            switch phase {
            case .focus:
                phase = .rest
                remaining = rest
            case .rest:
                stop()
            case .idle:
                break
            }
        }
    }
}
