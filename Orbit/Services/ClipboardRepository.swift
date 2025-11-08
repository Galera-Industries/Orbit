//
//  ClipboardStorage.swift
//  Orbit
//
//  Created by Кирилл Исаев on 22.10.2025.
//

import Foundation

/// репозиторий для копирований
final class ClipboardRepository: ClipboardRepositoryProtocol {
    private let coreData: CoreDataProtocol
    private var cachedItems: [ClipboardItem] = []
    private var isLoaded: Bool = false // для проверки что мы уже загрузили кэш
    private let maxItems = 100
    
    init(coreData: CoreDataProtocol) {
        self.coreData = coreData
    }
    
    /// добавляем новое копирование
    func add(_ item: ClipboardItem) {
        firstLoad()
        
        if let lastItem = cachedItems.first, lastItem.content == item.content {
            return
        }
        cachedItems.insert(item, at: 0)
        
        if cachedItems.count > maxItems {
            let itemToRemove = cachedItems.removeLast()
            coreData.deleteItem(itemToRemove)
        }
        
        coreData.createItem(item)
    }
    
    /// получение всех копирований
    func getAll() -> [ClipboardItem] {
        firstLoad()
        return cachedItems
    }
    
    /// поиск копирования по названию
    func search(_ query: String) -> [ClipboardItem] {
        firstLoad()
        guard !query.isEmpty else { return cachedItems }
        return cachedItems.filter { item in
            item.displayText.localizedCaseInsensitiveContains(query)
        }
    }
    
    func getByOrder(_ byOrder: Int) -> ClipboardItem? {
        firstLoad()
        guard byOrder >= 0 && byOrder < cachedItems.count else { return nil }
        return cachedItems[byOrder]
    }
    
    /// удаляем все копирования
    func clear() {
        firstLoad()
        // Очищаем кеш
        let itemsToDelete = cachedItems
        cachedItems.removeAll()
        // Удаляем из Core Data
        itemsToDelete.forEach { coreData.deleteItem($0) }
    }
    
    func load() {
        let cdItems = coreData.fetchAll()
        cachedItems = cdItems
            .compactMap { mapFromCoreData($0) }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(maxItems)
            .map { $0 }
        cachedItems.sort(by: sortRule)
        isLoaded = true
    }
    
    func delete(item: ClipboardItem) {
        coreData.deleteItem(item)
        if let index = cachedItems.firstIndex(where: {$0.content == item.content}) {
            cachedItems.remove(at: index)
        }
    }
    
    func deleteAll() {
        coreData.deleteAll()
        cachedItems = []
    }
    
    func pin(item: ClipboardItem, maxPin: Int32) {
        guard item.pinned == nil else { return }
        coreData.pin(item, maxPin: maxPin)
        if let index = cachedItems.firstIndex(where: { $0.id == item.id }) {
            cachedItems[index].pinned = Int(maxPin) + 1
        }
        cachedItems.sort(by: sortRule)
    }
    
    func unpin(item: ClipboardItem) {
        guard item.pinned != nil else { return }
        coreData.unpin(item)
        if let index = cachedItems.firstIndex(where: { $0.id == item.id }) {
            cachedItems[index].pinned = nil
        }
        cachedItems.sort(by: sortRule)
    }
    
    func getMaxPin() -> Int32 {
        return coreData.fetchMaxPinned()
    }
    
    private func firstLoad() {
        guard !isLoaded else { return }
        load()
    }
    
    private func mapFromCoreData(_ cdItem: CDClipboardItem) -> ClipboardItem? {
        guard let id = cdItem.id,
              let timestamp = cdItem.timestamp,
              let typeString = cdItem.type,
              let type = ClipboardType(rawValue: typeString),
              let content = cdItem.content else {
            return nil
        }
        
        return ClipboardItem(
            id: id,
            timestamp: timestamp,
            type: type,
            content: content,
            pinned: cdItem.pinned == 0 ? nil : Int(cdItem.pinned),
            bundleID: cdItem.bundleID,
            appName: cdItem.appName,
            appIcon: cdItem.appIcon
        )
    }
    
    private func sortRule(_ lhs: ClipboardItem, _ rhs: ClipboardItem) -> Bool {
        switch (lhs.pinned, rhs.pinned) {
        case let (l?, r?):
            return l < r
        case (nil, nil):
            return lhs.timestamp > rhs.timestamp
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        }
    }
}

protocol ClipboardRepositoryProtocol {
    func add(_ item: ClipboardItem)
    func getAll() -> [ClipboardItem]
    func getByOrder(_ byOrder: Int) -> ClipboardItem?
    func search(_ query: String) -> [ClipboardItem]
    func clear()
    func load()
    func delete(item: ClipboardItem)
    func deleteAll()
    func pin(item: ClipboardItem, maxPin: Int32)
    func unpin(item: ClipboardItem)
    func getMaxPin() -> Int32
    
}
