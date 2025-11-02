//
//  TasksModule.swift
//  Orbit
//
//  Created by Vladislav Pankratov on 22.10.2025.
//

import Foundation

final class TasksModule: ModulePlugin {
    let mode: AppMode = .tasks
    private var ctx: ModuleContext?
    
    func activate(context: ModuleContext) {
        ctx = context
        ctx?.tasksRepository.load()
    }
    
    func deactivate() {
        ctx = nil
    }
    
    func parse(query: ParsedQuery) -> Any? { query } // используем все токены
    
    func search(intent: Any, cancellation: @escaping () -> Bool, emit: @escaping ([ResultItem]) -> Void) {
        guard let pq = intent as? ParsedQuery, let ctx = ctx else { return }
        
        var items: [ResultItem] = []

        if pq.text.isEmpty {
            emit([])
            return
        }

        let matchingTasks = ctx.tasksRepository.search(pq.text)

        for task in matchingTasks {
            if cancellation() { return }
            items.append(createResultItem(for: task))
        }

        let isMatchingExisting = !matchingTasks.isEmpty

        // Если не найдено совпадений или текст содержит новые токены (теги, приоритет, дедлайн),
        // показываем опцию создания новой задачи
        if !isMatchingExisting || !pq.tags.isEmpty || pq.priority != nil || pq.due != nil {
            let newTask = Task.from(parsedQuery: pq)
            let title = "Create: \(newTask.title)"
            let desc = formatTaskMetadata(pq)
            
            items.insert(ResultItem(
                title: title,
                subtitle: desc.isEmpty ? "Press Enter to add" : desc,
                accessory: "↩︎",
                primaryAction: { },
                source: pq
            ), at: 0)
        }
        
        if cancellation() { return }
        emit(items)
    }
    
    private func createResultItem(for task: Task) -> ResultItem {
        let title = task.title
        let subtitle = formatTaskSubtitle(for: task)
        
        return ResultItem(
            title: title,
            subtitle: subtitle,
            accessory: "↩︎",
            primaryAction: { [weak self] in
                self?.toggleTaskCompletion(task)
            },
            source: task
        )
    }
    
    private func formatTaskSubtitle(for task: Task) -> String {
        var parts: [String] = []
        
        // Приоритет
        if let priority = task.priority {
            let priorityEmoji: String
            switch priority {
            case .high: priorityEmoji = "🔴"
            case .medium: priorityEmoji = "🟡"
            case .low: priorityEmoji = "🟢"
            }
            parts.append(priorityEmoji)
        }
        
        // Теги
        if !task.tags.isEmpty {
            parts.append("#" + task.tags.joined(separator: " #"))
        }
        
        // Дедлайн
        if let dueDate = task.dueDate {
            let dateStr = formatDueDate(dueDate)
            parts.append(dateStr)
        }
        
        // Дата создания
        if parts.isEmpty {
            parts.append(formatDate(task.createdAt))
        }
        
        return parts.joined(separator: " • ")
    }
    
    private func formatTaskMetadata(_ pq: ParsedQuery) -> String {
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
    
    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Due today"
        } else if calendar.isDateInTomorrow(date) {
            return "Due tomorrow"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            return "Due this week"
        } else if date < now {
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            return "Overdue: \(formatter.localizedString(for: date, relativeTo: now))"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "Due \(formatter.string(from: date))"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func addTask(_ task: Task) {
        guard let ctx = ctx else { return }
        ctx.tasksRepository.add(task)
    }
    
    private func toggleTaskCompletion(_ task: Task) {
        guard let ctx = ctx else { return }
        var updatedTask = task
        updatedTask.completed = !updatedTask.completed
        ctx.tasksRepository.update(updatedTask)
    }
    
    func execute(item: ResultItem, modifiers: EventModifiers) -> Outcome {
        if let task = item.source as? Task {
            toggleTaskCompletion(task)
            return .closeWindow
        }
        if let pq = item.source as? ParsedQuery, !pq.text.isEmpty {
            let task = Task.from(parsedQuery: pq)
            addTask(task)
            return .clearQuery
        }
        return .done
    }
    
    func backgroundTick() {}
}
