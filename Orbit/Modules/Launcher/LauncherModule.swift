//
//  LauncherModule.swift
//  Orbit
//
//  Created by Vladislav Pankratov on 22.10.2025.
//

import Foundation
import AppKit

final class LauncherModule: ModulePlugin {
    let mode: AppMode = .launcher
    private var ctx: ModuleContext?
    private var shellModel: ShellModel?
    
    func activate(context: ModuleContext) {
        ctx = context
    }
    
    func deactivate() { ctx = nil; shellModel = nil }
    
    func setShellModel(_ model: ShellModel) {
        shellModel = model
    }
    
    func parse(query: ParsedQuery) -> Any? { query.text }
    
    func search(intent: Any, cancellation: @escaping () -> Bool, emit: @escaping ([ResultItem]) -> Void) {
        guard let q = intent as? String else { return }
        // Простая фильтрация мок-элементов
        let base: [ResultItem] = [
            .init(title: "Open Safari", subtitle: "Launch app", accessory: "↩︎") { print("EXEC: Open Safari") },
            .init(title: "Open Notes", subtitle: "Launch app", accessory: "↩︎") { print("EXEC: Open Notes") },
            .init(title: "Clipboard: Paste last", subtitle: "Quick paste", accessory: "⇧↩︎") { print("EXEC: Paste last") },
            .init(
                title: "Task: Add",
                subtitle: "Create task",
                accessory: "↩︎"
            ) {
                NotificationCenter.default.post(name: .showCreateTaskView, object: nil)
            },
            .init(
                title: "Tasks: Delete all",
                subtitle: "Remove all tasks",
                accessory: "↩︎"
            ) {
                self.showDeleteAllTasksConfirmation()
            },
            .init(
                title: "Tasks: Delete all completed",
                subtitle: "Remove completed tasks",
                accessory: "↩︎"
            ) {
                self.deleteAllCompletedTasks()
            },
            .init(
                title: "Task: Stats",
                subtitle: "View focus statistics",
                accessory: "↩︎"
            ) {
                NotificationCenter.default.post(name: .showStatsView, object: nil)
            },
            
        ]
        if cancellation() { return }
        if q.isEmpty {
            emit(base)
        } else {
            emit(base.filter { $0.title.localizedCaseInsensitiveContains(q) || ($0.subtitle?.localizedCaseInsensitiveContains(q) ?? false) })
        }
    }
    
    private func showDeleteAllTasksConfirmation() {
        guard let context = ctx else { return }
        
        let taskCount = context.tasksRepository.getAll().count
        guard taskCount > 0 else { return }
        
        let alert = NSAlert()
        alert.messageText = "Delete All Tasks"
        alert.informativeText = "Are you sure you want to delete all \(taskCount) task\(taskCount == 1 ? "" : "s")? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete All")
        alert.addButton(withTitle: "Cancel")
        
        if let deleteButton = alert.buttons.first {
            deleteButton.hasDestructiveAction = true
        }
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            context.tasksRepository.deleteAll()
            NotificationCenter.default.post(name: .taskListChanged, object: nil)
        }
    }
    
    private func deleteAllCompletedTasks() {
        guard let context = ctx else { return }
        
        let completedCount = context.tasksRepository.getAll().filter { $0.completed }.count
        guard completedCount > 0 else { return }
        
        context.tasksRepository.deleteAllCompleted()
    }
    
    func execute(item: ResultItem, modifiers: EventModifiers) -> Outcome { .done }
    func backgroundTick() {}
}

extension Notification.Name {
    static let showCreateTaskView = Notification.Name("ShowCreateTaskView")
}
