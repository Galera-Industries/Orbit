//
//  CoreDataMock.swift
//  Orbit
//
//  Created by Кирилл Исаев on 27.10.2025.
//

import Foundation

final class CoreDataMock: CoreDataProtocol {
    var storageCount: Int
    var fetchAllResult: [CDClipboardItem] = []
    var createItemResult: [ClipboardItem] = []
    var deleteItemResult: [ClipboardItem] = []
    
    init(storageCount: Int) {
        self.storageCount = storageCount
    }
    
    func createItem(_ item: ClipboardItem) { createItemResult.append(item) }
    
    func deleteItem(_ item: ClipboardItem) { deleteItemResult.append(item) }
    
    func fetchAll() -> [CDClipboardItem] { fetchAllResult }
    func deleteAll() {}
}
