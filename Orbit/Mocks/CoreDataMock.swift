//
//  CoreDataMock.swift
//  Orbit
//
//  Created by Кирилл Исаев on 27.10.2025.
//

import Foundation

final class CoreDataMock: CoreDataProtocol {
    func createTask(_ task: Task) {
        print("TODO")
    }
    
    func deleteTask(_ task: Task) {
        print("TODO")
    }
    
    func fetchAllTasks() -> [CDTask] {
        print("TODO")
        return []
    }
    
    func deleteAllTasks() {
        print("TODO")
    }
    
    func updateTask(_ task: Task) {
        print("TODO")
    }
    
    var storageCount: Int
    var fetchAllResult: [CDClipboardItem] = []
    var createItemResult: [ClipboardItem] = []
    var deleteItemResult: [ClipboardItem] = []
    var pinnedItems: [ClipboardItem] = []
    
    init(storageCount: Int) {
        self.storageCount = storageCount
    }
    
    func createItem(_ item: ClipboardItem) { createItemResult.append(item) }
    
    func deleteItem(_ item: ClipboardItem) { deleteItemResult.append(item) }
    
    func fetchAll() -> [CDClipboardItem] { fetchAllResult }
    
    func deleteAll() {}
    
    func fetchMaxPinned() -> Int32 {
        Int32(pinnedItems.map { $0.pinned ?? 0 }.max() ?? 0)
    }
    
    func pin(_ item: ClipboardItem, maxPin: Int32) {
        var copy = item
        copy.pinned = Int(maxPin) + 1
        pinnedItems.append(copy)
    }
    
    func unpin(_ item: ClipboardItem) {
        if let index = pinnedItems.firstIndex(where: { $0.id == item.id }) {
            pinnedItems[index].pinned = nil
        }
    }
}
