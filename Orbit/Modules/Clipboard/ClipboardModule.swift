//
//  ClipboardModule.swift
//  Orbit
//
//  Created by Vladislav Pankratov on 22.10.2025.
//

import Foundation
import AppKit
import Carbon.HIToolbox
import Combine

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
        
        c?.tracker.rememberNow()
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
                },
                source: clipItem // сохраняем данные, чтобы достать их из UI
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
        formatter.locale = Locale(identifier: "en")
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
            if let paths = try? JSONDecoder().decode([String].self, from: item.content) {
                let urls = paths.map { NSURL(fileURLWithPath: $0) }
                pasteboard.writeObjects(urls)
            }
        }
        
        NSApp.hide(nil)
        activatePreviousApp(c?.tracker.previousApp)
        pasteSimulation()
    }
    
    private func pasteSimulation() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_Command), keyDown: true)
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let vUp = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_Command), keyDown: false)
        
        cmdDown?.flags = .maskCommand
        vDown?.flags = .maskCommand
        
        let loc = CGEventTapLocation.cghidEventTap

        cmdDown?.post(tap: loc)
        vDown?.post(tap: loc)
        vUp?.post(tap: loc)
        cmdUp?.post(tap: loc)
    }
    
    @discardableResult
    private func activatePreviousApp(_ app: NSRunningApplication?) -> Bool {
        guard let app = app else { return false }
        return app.activate(options: [.activateIgnoringOtherApps])
    }
}
