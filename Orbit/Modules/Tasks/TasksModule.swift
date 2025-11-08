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
    
    func parse(query: ParsedQuery) -> Any? { query }
    
    func search(intent: Any, cancellation: @escaping () -> Bool, emit: @escaping ([ResultItem]) -> Void) {
        guard let pq = intent as? ParsedQuery, let ctx = ctx else { return }
        
        var items: [ResultItem] = []

        if pq.text.isEmpty {
            let daily = PomodoroStats.shared.statsForToday()
            let weekly = PomodoroStats.shared.statsForThisWeek()
            
            let statsItems = [
                ResultItem(
                    title: "Today's Focus Time",
                    subtitle: "\(daily) minutes focused",
                    accessory: "☀️",
                    primaryAction: { }
                ),
                ResultItem(
                    title: "This Week",
                    subtitle: "\(weekly) minutes total",
                    accessory: "📆",
                    primaryAction: { }
                )
            ]
            emit(statsItems)
            return
        }

        let matchingTasks = ctx.tasksRepository.search(pq.text)

        for task in matchingTasks {
            // основной item задачи
            items.append(createResultItem(for: task))

            // дополнительный пункт: запустить Pomodoro
            let focusItem = ResultItem(
                title: "Focus: \(task.title)",
                subtitle: "Start Pomodoro for this task",
                accessory: "⏱",
                primaryAction: {
                    if let entity = ctx.tasksRepository.findEntity(byTitle: task.title) {
                        PomodoroManager.shared.start(for: task)
                        NotificationCenter.default.post(name: .showPomodoroForTask, object: task)
                    } else {
                        print("⚠️ CDTask not found for title \(task.title)")
                    }
                },
                source: task
            )
            items.append(focusItem)
        }

        // Если нет совпадений, показываем опцию создания новой задачи
        let isMatchingExisting = !matchingTasks.isEmpty
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
    
    // ниже только вспомогательные функции форматирования
    private func formatTaskSubtitle(for task: Task) -> String {
        var parts: [String] = []
        if let priority = task.priority {
            let symbol = (priority == .high ? "🔴" :
                          priority == .medium ? "🟡" : "🟢")
            parts.append(symbol)
        }
        if !task.tags.isEmpty { parts.append("#" + task.tags.joined(separator: " #")) }
        if let due = task.dueDate { parts.append(formatDueDate(due)) }
        if parts.isEmpty { parts.append(formatDate(task.createdAt)) }
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
        let cal = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Due today"
        } else if calendar.isDateInTomorrow(date) {
            return "Due tomorrow"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            return "Due this week"
        } else if date < now {
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = Locale(identifier: "en")
            return "Overdue: \(formatter.localizedString(for: date, relativeTo: now))"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "Due \(formatter.string(from: date))"
        }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "Due \(f.string(from: date))"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "en")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func addTask(_ task: Task) {
        guard let ctx = ctx else { return }
        ctx.tasksRepository.add(task)
    }

    private func toggleTaskCompletion(_ task: Task) {
        guard let ctx = ctx else { return }
        var updated = task
        updated.completed.toggle()
        ctx.tasksRepository.update(updated)
    }

    func execute(item: ResultItem, modifiers: EventModifiers) -> Outcome {
        return .done
    }

    func backgroundTick() {}
}
