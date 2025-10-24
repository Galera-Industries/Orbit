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
        if let item = coreData.fetch(byOrder: byOrder) {
            return mapFromCoreData(item)
        } else {
            return nil
        }
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
        
        isLoaded = true
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
            content: content
        )
    }
}

protocol ClipboardRepositoryProtocol {
    func add(_ item: ClipboardItem)
    func getAll() -> [ClipboardItem]
    func getByOrder(_ byOrder: Int) -> ClipboardItem?
    func search(_ query: String) -> [ClipboardItem]
    func clear()
    func load()
}
