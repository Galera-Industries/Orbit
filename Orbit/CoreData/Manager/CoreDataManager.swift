//
//  CoreDataManager.swift
//  Orbit
//
//  Created by Кирилл Исаев on 22.10.2025.
//

import Foundation
import CoreData

final class CoreDataManager: CoreDataProtocol {
    
    enum Models: String {
        case clipboard = "ClipboardModel"
        case tasks = "TaskModel"
    }
    
    func createItem(_ item: ClipboardItem) {
        let context = CoreDataStack.shared.viewContext(for: Models.clipboard.rawValue)
        let CDitem = CDClipboardItem(context: context)
        CDitem.id = item.id
        CDitem.timestamp = item.timestamp
        CDitem.type = item.type.rawValue
        CDitem.content = item.content
        CDitem.bundleID = item.bundleID
        CDitem.appName = item.appName
        CDitem.appIcon = item.appIcon
        CoreDataStack.shared.saveContext(for: Models.clipboard.rawValue)
    }
    
    func deleteItem(_ item: ClipboardItem) {
        let context = CoreDataStack.shared.viewContext(for: Models.clipboard.rawValue)
        if let CDitem = fetch(itemId: item.id) {
            context.delete(CDitem)
        }
        CoreDataStack.shared.saveContext(for: Models.clipboard.rawValue)
    }
    
    func deleteAll() {
        let context = CoreDataStack.shared.viewContext(for: Models.clipboard.rawValue)
        let items = fetchAll()
        for item in items {
            context.delete(item)
        }
        CoreDataStack.shared.saveContext(for: Models.clipboard.rawValue)
    }
    
    func fetchAll() -> [CDClipboardItem] {
        let context = CoreDataStack.shared.viewContext(for: Models.clipboard.rawValue)
        let request: NSFetchRequest<CDClipboardItem> = CDClipboardItem.fetchRequest()
        do {
            return try context.fetch(request)
        } catch {
            debugPrint("Empty CoreData")
            return []
        }
    }
    
    func fetch(byOrder: Int) -> CDClipboardItem? {
        let items = fetchAll()
        if byOrder <= items.count {
            return items[items.count - byOrder - 1]
        }
        return nil
    }
    
    func pin(_ item: ClipboardItem, maxPin: Int32) {
        guard let cditem = fetch(itemId: item.id) else { return }
        cditem.pinned = maxPin + 1
        CoreDataStack.shared.saveContext(for: Models.clipboard.rawValue)
    }
    
    func unpin(_ item: ClipboardItem) {
        guard let cditem = fetch(itemId: item.id) else { return }
        cditem.pinned = 0
        CoreDataStack.shared.saveContext(for: Models.clipboard.rawValue)
    }
    
    func fetchMaxPinned() -> Int32 {
        let context = CoreDataStack.shared.viewContext(for: Models.clipboard.rawValue)
        let request: NSFetchRequest<NSDictionary> = NSFetchRequest(entityName: "CDClipboardItem")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = [
            NSExpressionDescription().apply {
                $0.name = "maxPinned"
                $0.expression = NSExpression(forFunction: "max:", arguments: [NSExpression(forKeyPath: "pinned")])
                $0.expressionResultType = .integer32AttributeType
            }
        ]
        if
            let results = try? context.fetch(request),
            let dict = results.first as? [String: Any],
            let maxPinned = dict["maxPinned"] as? Int32
        {
            return maxPinned
        }
        return 0
    }
    
    private func fetch(itemId: UUID) -> CDClipboardItem? {
        let context = CoreDataStack.shared.viewContext(for: Models.clipboard.rawValue)
        let request: NSFetchRequest<CDClipboardItem> = CDClipboardItem.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", itemId as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
    
    // MARK: - Tasks
    func createTask(_ task: Task) {
        let context = CoreDataStack.shared.viewContext(for: Models.tasks.rawValue)
        let cdTask = CDTask(context: context)
        cdTask.id = task.id
        cdTask.title = task.title
        cdTask.createdAt = task.createdAt
        cdTask.tags = task.tags.isEmpty ? nil : task.tags.joined(separator: ",")
        cdTask.priority = Int32(task.priority?.rawValue ?? 0)
        cdTask.dueDate = task.dueDate
        cdTask.completed = task.completed
        cdTask.eventIdentifier = task.eventIdentifier
        CoreDataStack.shared.saveContext(for: Models.tasks.rawValue)
    }
    
    func deleteTask(_ task: Task) {
        let context = CoreDataStack.shared.viewContext(for: Models.tasks.rawValue)
        if let cdTask = fetchTask(taskId: task.id) {
            context.delete(cdTask)
        }
        CoreDataStack.shared.saveContext(for: Models.tasks.rawValue)
    }
    
    func fetchAllTasks() -> [CDTask] {
        let context = CoreDataStack.shared.viewContext(for: Models.tasks.rawValue)
        let request: NSFetchRequest<CDTask> = CDTask.fetchRequest()
        do {
            return try context.fetch(request)
        } catch {
            debugPrint("Failed to fetch tasks: \(error)")
            return []
        }
    }
    
    func deleteAllTasks() {
        let context = CoreDataStack.shared.viewContext(for: Models.tasks.rawValue)
        let tasks = fetchAllTasks()
        for task in tasks {
            context.delete(task)
        }
        CoreDataStack.shared.saveContext(for: Models.tasks.rawValue)
    }
    
    func updateTask(_ task: Task) {
        guard let cdTask = fetchTask(taskId: task.id) else { return }
        cdTask.title = task.title
        cdTask.tags = task.tags.isEmpty ? nil : task.tags.joined(separator: ",")
        cdTask.priority = Int32(task.priority?.rawValue ?? 0)
        cdTask.dueDate = task.dueDate
        cdTask.completed = task.completed
        cdTask.eventIdentifier = task.eventIdentifier
        CoreDataStack.shared.saveContext(for: Models.tasks.rawValue)
    }
    
    private func fetchTask(taskId: UUID) -> CDTask? {
        let context = CoreDataStack.shared.viewContext(for: Models.tasks.rawValue)
        let request: NSFetchRequest<CDTask> = CDTask.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", taskId as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}

extension NSExpressionDescription {
    func apply(_ block: (NSExpressionDescription) -> Void) -> NSExpressionDescription {
        block(self)
        return self
    }
}
