//
//  CoreDataProtocol.swift
//  Orbit
//
//  Created by Кирилл Исаев on 22.10.2025.
//

import Foundation

protocol CoreDataProtocol {
    // Clipboard
    func createItem(_ item: ClipboardItem)
    func deleteItem(_ item: ClipboardItem)
    func fetchAll() -> [CDClipboardItem]
    func deleteAll()
    func fetchMaxPinned() -> Int32
    func pin(_ item: ClipboardItem, maxPin: Int32)
    func unpin(_ item: ClipboardItem)
    
    // Tasks
    func createTask(_ task: Task)
    func deleteTask(_ task: Task)
    func fetchAllTasks() -> [CDTask]
    func deleteAllTasks()
    func updateTask(_ task: Task)
}
