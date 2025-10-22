//
//  TasksModule.swift
//  Orbit
//
//  Created by Vladislav Pankratov on 22.10.2025.
//

import Foundation

final class TasksModule: ModulePlugin {
    let mode: AppMode = .tasks
    func activate(context: ModuleContext) {}
    func deactivate() {}
    
    func parse(query: ParsedQuery) -> Any? { query } // используем все токены
    
    func search(intent: Any, cancellation: @escaping () -> Bool, emit: @escaping ([ResultItem]) -> Void) {
        guard let pq = intent as? ParsedQuery else { return }
        let title = pq.text.isEmpty ? "Add a new task" : "Task: \(pq.text)"
        let desc = tokenDesc(pq)
        let items = [
            ResultItem(title: title, subtitle: desc, accessory: "↩︎", primaryAction: { print("EXEC: add task \(pq.text)") })
        ]
        if cancellation() { return }
        emit(items)
    }
    
    private func tokenDesc(_ pq: ParsedQuery) -> String {
        var parts: [String] = []
        if !pq.tags.isEmpty { parts.append("#" + pq.tags.joined(separator: " #")) }
        if let p = pq.priority {
            parts.append("!\(p == .low ? "low" : p == .medium ? "med" : "high")")
        }
        if let d = pq.due {
            switch d {
            case .today: parts.append("@today")
            case .tomorrow: parts.append("@tomorrow")
            case .nextWeek: parts.append("@nextweek")
            case .date(let dt):
                let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
                parts.append("@\(f.string(from: dt))")
            }
        }
        return parts.joined(separator: " ")
    }
    
    func execute(item: ResultItem, modifiers: EventModifiers) -> Outcome { .done }
    func backgroundTick() {}
}
