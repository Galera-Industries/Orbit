//
//  ClipboardMonitorMock.swift
//  Orbit
//
//  Created by Кирилл Исаев on 29.10.2025.
//

import Foundation

final class ClipboardMonitorMock: ClipboardMonitorProtocol {
    var startCalled = false
    var stopCalled = false
    var onClipboardChange: ((ClipboardItem) -> Void)?
    
    private var queue: [ClipboardItem] = []
    private var isMonitoring = false

    
    func startMonitoring() {
        startCalled = true
        isMonitoring = true
        processQueue()
    }
    
    func stopMonitoring() {
        stopCalled = true
        isMonitoring = false
    }
    
    func simulateClipboardChange(_ item: ClipboardItem) {
        queue.insert(item, at: 0)
        processQueue()
    }
    
    func enqueue(_ items: [ClipboardItem]) {
        queue.append(contentsOf: items)
        processQueue()
    }
    
    private func processQueue() {
        guard isMonitoring else { return }
        guard !queue.isEmpty else { return }
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, self.isMonitoring else { return }
            let item = self.queue.removeFirst()
            DispatchQueue.main.async {
                self.onClipboardChange?(item)
            }
            self.processQueue()
        }
    }
}

