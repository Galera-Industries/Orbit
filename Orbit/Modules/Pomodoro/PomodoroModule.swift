//
//  PomodoroModule.swift
//  Orbit
//
//  Created by Vladislav Pankratov on 22.10.2025.
//

import Foundation

final class PomodoroModule: ModulePlugin {
    let mode: AppMode = .pomodoro
    func activate(context: ModuleContext) {}
    func deactivate() {}
    
    func parse(query: ParsedQuery) -> Any? { query.text }
    
    func search(intent: Any, cancellation: @escaping () -> Bool, emit: @escaping ([ResultItem]) -> Void) {
        guard let q = intent as? String else { return }
        let items = [
            ResultItem(title: "Start 25-min focus", subtitle: "pomo start 25", accessory: "↩︎", primaryAction: { print("EXEC: pomo 25") }),
            ResultItem(title: "Start 50-min deep", subtitle: "pomo start 50", accessory: "↩︎", primaryAction: { print("EXEC: pomo 50") })
        ].filter { q.isEmpty ? true : $0.title.localizedCaseInsensitiveContains(q) }
        if cancellation() { return }
        emit(items)
    }
    
    func execute(item: ResultItem, modifiers: EventModifiers) -> Outcome { .done }
    func backgroundTick() {}
}
