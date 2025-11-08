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
        
        let bid = readSourceBundleID(from: pasteboard)
        
        let source: (String?, String?, Data?) = {
            if let bid { return sourceFromBundleID(bid)}
            return currentFrontmostSource()
        }()
        
        if let item = captureCurrentClipboard() { // если получилось захватит вызываем апдейт клипборда
            var e = item
            e.bundleID = source.0
            e.appName = source.1
            e.appIcon = source.2
            onClipboardChange?(e)
        }
    }
    
    private func captureCurrentClipboard() -> ClipboardItem? {
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = fileURLs.first,
           FileManager.default.fileExists(atPath: url.path) {

            // Исключаем случай, когда это просто временное изображение из Preview или Safari
            // (такие URL обычно начинаются с /private/var или /var/folders)
            if !url.path.starts(with: "/private/var") && !url.path.starts(with: "/var/folders") {
                if let urlsData = try? JSONEncoder().encode(fileURLs.map { $0.path }) {
                    return ClipboardItem(type: .fileURL, content: urlsData)
                }
            }
        }
        if let imageData = pasteboard.data(forType: .tiff), !imageData.isEmpty {
            if NSImage(data: imageData) != nil { // проверяем что это вообще картинка
                return ClipboardItem(type: .image, content: imageData)
            }
        }
        if let string = pasteboard.string(forType: .string),
           let data = string.data(using: .utf8),
           !data.isEmpty {
            return ClipboardItem(type: .text, content: data)
        }
        return nil
    }
    
    private func readSourceBundleID(from pb: NSPasteboard) -> String? {
        guard let item = pb.pasteboardItems?.first,
              let data = item.data(forType: NSPasteboard.PasteboardType("org.nspasteboard.source")),
              let bid = String(data: data, encoding: .utf8),
              !bid.isEmpty else {
            return nil
        }
        return bid
    }
    
    private func sourceFromBundleID(_ bid: String) -> (String, String?, Data?) {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bid).first
        if let app = running {
            return (bid, app.localizedName, app.icon?.jpegData())
        } else {
            return (bid, nil, nil)
        }
    }
    
    private func currentFrontmostSource() -> (String?, String?, Data?) {
        let app = NSWorkspace.shared.frontmostApplication
        return (app?.bundleIdentifier, app?.localizedName, app?.icon?.jpegData())
    }
}

protocol ClipboardMonitorProtocol {
    func startMonitoring()
    func stopMonitoring()
    var onClipboardChange: ((ClipboardItem) -> Void)? { get set }
}
