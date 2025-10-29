//
//  ClipboardHotkeyManager.swift
//  Orbit
//
//  Created by Кирилл Исаев on 28.10.2025.
//

import Foundation

final class ClipboardHotkeyManager: ClipboardHotkeyProtocol {
    private let clipboardRepository: ClipboardRepositoryProtocol
    var maxPinned: Int32 = 0
    
    init(context: ModuleContext) {
        self.clipboardRepository = context.clipboardRepository
        maxPinned = clipboardRepository.getMaxPin()
    }
    
    func pin(item: ClipboardItem) {
        clipboardRepository.pin(item: item, maxPin: maxPinned)
        maxPinned += 1
    }
    
    func delete(item: ClipboardItem) {
        clipboardRepository.delete(item: item)
    }
}

protocol ClipboardHotkeyProtocol {
    func pin(item: ClipboardItem)
    func delete(item: ClipboardItem)
}
