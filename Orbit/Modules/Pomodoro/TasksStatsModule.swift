//
//  TasksStatsModule.swift
//  Orbit
//
//  Created by Ulyana Eskova on 03.11.2025.
//

import Foundation
import SwiftUI

final class TasksStatsModule: ModulePlugin {
    let mode: AppMode = .tasks
    private var ctx: ModuleContext?
    
    func activate(context: ModuleContext) { ctx = context }
    func deactivate() { ctx = nil }
    func backgroundTick() {}
    func parse(query: ParsedQuery) -> Any? { query }
    
    func search(intent: Any, cancellation: @escaping () -> Bool, emit: @escaping ([ResultItem]) -> Void) {
        guard let pq = intent as? ParsedQuery else { return }
        var items: [ResultItem] = []
        
        if pq.text.isEmpty || pq.text.lowercased().contains("stats") {
            let item = ResultItem(
                title: "Task: Stats",
                subtitle: "View your focus statistics",
                accessory: "↩︎",
                primaryAction: {
                    NotificationCenter.default.post(name: .showStatsView, object: nil)
                }
            )
            items.append(item)
        }
        
        if !items.isEmpty { emit(items) }
    }
    
    func execute(item: ResultItem, modifiers: EventModifiers) -> Outcome { .done }
}
