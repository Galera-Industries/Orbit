//
//  LauncherModule.swift
//  Orbit
//
//  Created by Vladislav Pankratov on 22.10.2025.
//

import Foundation

final class LauncherModule: ModulePlugin {
    let mode: AppMode = .launcher
    private var ctx: ModuleContext?
    
    func activate(context: ModuleContext) { ctx = context }
    func deactivate() { ctx = nil }
    
    func parse(query: ParsedQuery) -> Any? { query.text }
    
    func search(intent: Any, cancellation: @escaping () -> Bool, emit: @escaping ([ResultItem]) -> Void) {
        guard let q = intent as? String else { return }
        // Простая фильтрация мок-элементов
        let base: [ResultItem] = [
            .init(title: "Open Safari", subtitle: "Launch app", accessory: "↩︎") { print("EXEC: Open Safari") },
            .init(title: "Open Notes", subtitle: "Launch app", accessory: "↩︎") { print("EXEC: Open Notes") },
            .init(title: "Clipboard: Paste last", subtitle: "Quick paste", accessory: "⇧↩︎") { print("EXEC: Paste last") },
            .init(title: "Task: Add “Buy milk”", subtitle: "Create task", accessory: "↩︎") { print("EXEC: Add task") },
            .init(title: "Pomodoro: Start 25", subtitle: "Focus timer", accessory: "↩︎") { print("EXEC: Start pomo") }
        ]
        if cancellation() { return }
        if q.isEmpty {
            emit(base)
        } else {
            emit(base.filter { $0.title.localizedCaseInsensitiveContains(q) || ($0.subtitle?.localizedCaseInsensitiveContains(q) ?? false) })
        }
    }
    
    func execute(item: ResultItem, modifiers: EventModifiers) -> Outcome { .done }
    func backgroundTick() {}
}
