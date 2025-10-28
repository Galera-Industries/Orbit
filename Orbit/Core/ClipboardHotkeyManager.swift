//
//  ClipboardHotkeyManager.swift
//  Orbit
//
//  Created by Кирилл Исаев on 28.10.2025.
//

import Foundation

final class ClipboardHotkeyManager: ClipboardHotkeyProtocol {
    private let clipboardRepository: ClipboardRepositoryProtocol
    
    init(clipboardRepository: ClipboardRepositoryProtocol) {
        self.clipboardRepository = clipboardRepository
    }
    
    func pin(item: ClipboardItem) {
        // soon, много делать, т к нужно будет создавать новое поле pinned, опциональное, Int
    }
    
    func delete(item: ClipboardItem) {
        clipboardRepository.delete(item: item)
    }
}

protocol ClipboardHotkeyProtocol {
    func pin(item: ClipboardItem)
    func delete(item: ClipboardItem)
}
