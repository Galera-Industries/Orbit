//
//  ClipboardModule.swift
//  Orbit
//
//  Created by Vladislav Pankratov on 22.10.2025.
//

import Foundation
import AppKit

final class ClipboardModule: ModulePlugin {
    private var c: ModuleContext? // храним все зависимости
    let mode: AppMode = .clipboard
    func activate(context: ModuleContext) {
        c = context
        c?.clipboardRepository.load()
        c?.clipboardMonitor.onClipboardChange = { [weak self] item in
            self?.c?.clipboardRepository.add(item)
        }
        c?.clipboardMonitor.startMonitoring()
    }
    func deactivate() {
        c?.clipboardMonitor.stopMonitoring()
        c = nil
    }
    
    func parse(query: ParsedQuery) -> Any? { query.text }
    
    func search(intent: Any, cancellation: @escaping () -> Bool, emit: @escaping ([ResultItem]) -> Void) {
        guard let query = intent as? String else { return }
        let items = c?.clipboardRepository.search(query).map { clipItem in
            ResultItem(
                title: clipItem.displayText.prefix(80).description,
                subtitle: formatDate(clipItem.timestamp),
                accessory: "↩︎",
                primaryAction: { [weak self] in
                    self?.pasteItem(clipItem)
                }
            )
        }
        
        if cancellation() { return }
        if let items = items {
            emit(items)
        }
    }
    
    
    func execute(item: ResultItem, modifiers: EventModifiers) -> Outcome { .done }
    func backgroundTick() {}
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func pasteItem(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch item.type {
        case .text:
            if let string = String(data: item.content, encoding: .utf8) {
                pasteboard.setString(string, forType: .string)
            }
        case .image:
            pasteboard.setData(item.content, forType: .tiff)
        case .fileURL:
            if let urlString = String(data: item.content, encoding: .utf8), let fileURL = URL(string: urlString) {
                pasteboard.writeObjects([fileURL as NSURL])
            }
        }
    }
}
