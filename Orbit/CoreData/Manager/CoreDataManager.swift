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
    
    func pin(_ item: ClipboardItem, maxPin: Int32) {
        guard let cditem = fetch(itemId: item.id) else { return }
        cditem.pinned = maxPin + 1
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
}

extension NSExpressionDescription {
    func apply(_ block: (NSExpressionDescription) -> Void) -> NSExpressionDescription {
        block(self)
        return self
    }
}
