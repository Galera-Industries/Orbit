//
//  ClipboardMonitor.swift
//  Orbit
//
//  Created by Кирилл Исаев on 22.10.2025.
//

import AppKit

/// Класс для отслеживания буфера обмена пользователя
final class ClipboardMonitor: ClipboardMonitorProtocol {
    private var timer: Timer? // сомнительное решение, возможно нужно другой вид таймера использовать
    private var lastChangeCount: Int
    private let pasteboard = NSPasteboard.general
    private let pollInterval: TimeInterval = 0.5 // использую поллинг потому что нет системных ивентов на CMD+C, можно попробовать захардкоить в будущем(некст пр :) )
    
    var onClipboardChange: ((ClipboardItem) -> Void)?
    
    init() {
        lastChangeCount = pasteboard.changeCount
    }
    
    /// начинаем поллинг обновлений буфера обмена
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }
    
    /// останавливаем поллинг обновлений буфера обмена
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    /// проверяем что появились новые "копирования"
    private func checkForChanges() {
        let currentChangeCount = pasteboard.changeCount // сравниваем с прошлым id
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount
        
        if let item = captureCurrentClipboard() { // если получилось захватит вызываем апдейт клипборда
            onClipboardChange?(item)
        }
    }
    
    private func captureCurrentClipboard() -> ClipboardItem? {
        if let stringData = pasteboard.data(forType: .string), !stringData.isEmpty {
            return ClipboardItem(type: .text, content: stringData)
        }
        if let imageData = pasteboard.data(forType: .tiff), !imageData.isEmpty {
            return ClipboardItem(type: .image, content: imageData)
        }
        if let fileURLString = pasteboard.string(forType: .fileURL), !fileURLString.isEmpty,
            let fileURL = URL(string: fileURLString) {
            let fileURLData = fileURL.dataRepresentation
            return ClipboardItem(type: .fileURL, content: fileURLData)
        }
        return nil
    }
}

protocol ClipboardMonitorProtocol {
    func startMonitoring()
    func stopMonitoring()
    var onClipboardChange: ((ClipboardItem) -> Void)? { get set }
}
