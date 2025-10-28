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
    }
    
    func createItem(_ item: ClipboardItem) {
        let context = CoreDataStack.shared.viewContext(for: Models.clipboard.rawValue)
        let CDitem = CDClipboardItem(context: context)
        CDitem.id = item.id
        CDitem.timestamp = item.timestamp
        CDitem.type = item.type.rawValue
        CDitem.content = item.content
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

    private func fetch(itemId: UUID) -> CDClipboardItem? {
        let context = CoreDataStack.shared.viewContext(for: Models.clipboard.rawValue)
        let request: NSFetchRequest<CDClipboardItem> = CDClipboardItem.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", itemId as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
