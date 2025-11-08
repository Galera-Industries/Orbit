//
//  PomodoroStats.swift
//  Orbit
//
//  Created by Ulyana Eskova on 03.11.2025.
//


import Foundation

final class PomodoroStats {
    static let shared = PomodoroStats()
    private let storageKey = "PomodoroStatsData"
    
    struct Entry: Codable {
        let taskTitle: String
        let date: Date
        let durationMinutes: Int
    }
    
    private init() {}

    func addEntry(for task: Task, minutes: Int) {
        guard minutes > 0 else { return }
        var entries = load()
        entries.append(Entry(taskTitle: task.title, date: Date(), durationMinutes: minutes))
        save(entries)
    }
    
    func statsForToday() -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        return load()
            .filter { $0.date >= today }
            .reduce(0) { $0 + $1.durationMinutes }
    }
    
    func statsForThisWeek() -> Int {
        let cal = Calendar.current
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        return load()
            .filter { $0.date >= weekStart }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    // MARK: - Private helpers
    private func load() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data) else {
            return []
        }
        return decoded
    }
    
    private func save(_ entries: [Entry]) {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
