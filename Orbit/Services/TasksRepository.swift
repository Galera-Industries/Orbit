import Foundation
import Combine

extension Notification.Name {
    static let taskListChanged = Notification.Name("TaskListChanged")
}

final class TasksRepository: TasksRepositoryProtocol {
    private let coreData: CoreDataProtocol
    private var cachedTasks: [Task] = []
    private var isLoaded: Bool = false
    
    init(coreData: CoreDataProtocol) {
        self.coreData = coreData
    }

    func add(_ task: Task) {
        firstLoad()
        
        cachedTasks.append(task)
        coreData.createTask(task)
        NotificationCenter.default.post(name: .taskListChanged, object: nil)
    }

    func getAll() -> [Task] {
        firstLoad()
        return cachedTasks
    }

    func search(_ query: String) -> [Task] {
        firstLoad()
        guard !query.isEmpty else { return cachedTasks }
        return cachedTasks.filter { task in
            task.title.localizedCaseInsensitiveContains(query) ||
            task.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    func getUpcoming() -> [Task] {
        firstLoad()
        return cachedTasks.filter { !$0.completed }
    }

    func getUpcomingSorted() -> [Task] {
        let upcoming = getUpcoming()
        return upcoming.sorted { task1, task2 in
            if let due1 = task1.dueDate, let due2 = task2.dueDate {
                if due1 != due2 {
                    return due1 < due2
                }
            } else if task1.dueDate != nil {
                return true
            } else if task2.dueDate != nil {
                return false
            }
            let p1 = task1.priority?.rawValue ?? 0
            let p2 = task2.priority?.rawValue ?? 0
            if p1 != p2 {
                return p1 > p2
            }

            return task1.createdAt > task2.createdAt
        }
    }

    func update(_ task: Task) {
        firstLoad()
        if let index = cachedTasks.firstIndex(where: { $0.id == task.id }) {
            cachedTasks[index] = task
            cachedTasks.sort { task1, task2 in
                if task1.completed != task2.completed {
                    return !task1.completed && task2.completed
                }
                return task1.createdAt > task2.createdAt
            }
        }
        coreData.updateTask(task)
        NotificationCenter.default.post(name: .taskListChanged, object: nil)
    }

    func delete(_ task: Task) {
        firstLoad()
        coreData.deleteTask(task)
        if let index = cachedTasks.firstIndex(where: { $0.id == task.id }) {
            cachedTasks.remove(at: index)
        }
        NotificationCenter.default.post(name: .taskListChanged, object: nil)
    }

    func deleteAll() {
        firstLoad()
        coreData.deleteAllTasks()
        cachedTasks.removeAll()
        NotificationCenter.default.post(name: .taskListChanged, object: nil)
    }

    func deleteAllCompleted() {
        firstLoad()
        let completedTasks = cachedTasks.filter { $0.completed }

        let timer = TaskDeletionTimer.shared
        for task in completedTasks {
            if timer.isTimerActive(for: task.id) {
                timer.cancelTimer(for: task.id)
            }
        }
        
        for task in completedTasks {
            coreData.deleteTask(task)
            if let index = cachedTasks.firstIndex(where: { $0.id == task.id }) {
                cachedTasks.remove(at: index)
            }
        }
        NotificationCenter.default.post(name: .taskListChanged, object: nil)
    }

    func load() {
        let cdTasks = coreData.fetchAllTasks()
        cachedTasks = cdTasks
            .compactMap { mapFromCoreData($0) }
            .sorted { $0.createdAt > $1.createdAt }
        isLoaded = true
    }
    
    private func firstLoad() {
        guard !isLoaded else { return }
        load()
    }
    
    private func mapFromCoreData(_ cdTask: CDTask) -> Task? {
        guard let id = cdTask.id,
              let title = cdTask.title,
              let createdAt = cdTask.createdAt else {
            return nil
        }
        
        let priority: TaskPriority? = cdTask.priority == 0 ? nil : TaskPriority(rawValue: Int(cdTask.priority))
        
        let tags: [String] = cdTask.tags?.split(separator: ",").map(String.init) ?? []
        
        return Task(
            id: id,
            title: title,
            createdAt: createdAt,
            tags: tags,
            priority: priority,
            dueDate: cdTask.dueDate,
            completed: cdTask.completed
        )
    }
}

protocol TasksRepositoryProtocol {
    func add(_ task: Task)
    func getAll() -> [Task]
    func search(_ query: String) -> [Task]
    func getUpcoming() -> [Task]
    func getUpcomingSorted() -> [Task]
    func update(_ task: Task)
    func delete(_ task: Task)
    func deleteAll()
    func deleteAllCompleted()
    func load()
}

