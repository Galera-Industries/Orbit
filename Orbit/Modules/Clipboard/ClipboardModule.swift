//
//  ClipboardModule.swift
//  Orbit
//
//  Created by Vladislav Pankratov on 22.10.2025.
//

import Foundation

final class ClipboardModule: ModulePlugin {
    private var c: ModuleContext? // храним все зависимости
    let mode: AppMode = .clipboard
    func activate(context: ModuleContext) {
        c = context
    }
    func deactivate() {
        c = nil
    }
    
    func parse(query: ParsedQuery) -> Any? { query.text }
    
    func search(intent: Any, cancellation: @escaping () -> Bool, emit: @escaping ([ResultItem]) -> Void) {
        guard let q = intent as? String else { return }
        let items = (1...8).map { i in
            ResultItem(
                title: "Clipboard item \(i)",
                subtitle: "…example text snippet…",
                accessory: "↩︎",
                primaryAction: { print("Pasted item \(i)") }
            )
        }
        if cancellation() { return }
        if q.isEmpty { emit(items) }
        else { emit(items.filter { $0.title.localizedCaseInsensitiveContains(q) }) }
    }
    
    func execute(item: ResultItem, modifiers: EventModifiers) -> Outcome { .done }
    func backgroundTick() {}
}
