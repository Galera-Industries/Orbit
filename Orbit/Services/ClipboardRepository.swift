//
//  ClipboardStorage.swift
//  Orbit
//
//  Created by Кирилл Исаев on 22.10.2025.
//

import Foundation

/// userdefaults для копирований
final class ClipboardRepository: ClipboardRepositoryProtocol {
    private var items: [ClipboardItem] = []
    private let maxItems = 100
    private let storageKey = "clipboard"
    
    /// добавление копирования в  userdefaults
    func add(_ item: ClipboardItem) {
        if let lastItem = items.first, lastItem.content == item.content { // не добавляет дубликаты
            return
        }
        
        items.insert(item, at: 0)
        if items.count > maxItems {
            items = Array(items.prefix(maxItems)) // если больше 100, то берем только префикс размера maxItems
        }
        save()
    }
    
    /// получение всех копирований
    func getAll() -> [ClipboardItem] {
        return items
    }
    
    /// поиск копирования по названию
    func search(_ query: String) -> [ClipboardItem] {
        guard !query.isEmpty else { return items }
        
        return items.filter { item in
            item.displayText.localizedCaseInsensitiveContains(query)
        }
    }
    
    /// удаляем все копирования
    func clear() {
        items.removeAll()
        save()
    }
    
    func load() {
        // выгружаем из UserDefaults
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            items = decoded
        }
    }
    
    private func save() {
        // сохраняем в UserDefaults
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
}

protocol ClipboardRepositoryProtocol {
    func add(_ item: ClipboardItem)
    func getAll() -> [ClipboardItem]
    func search(_ query: String) -> [ClipboardItem]
    func clear()
    func load()
}
