//
//  HotkeyBootstrap.swift
//  Orbit
//
//  Created by Tom Tim on 20.10.2025.
//

import Foundation
internal import os

enum HotkeyBootstrap {
    private static var registered = false
    
    static func registerDefaults(windowManager: WindowManager, shell: ShellModel) {
        guard !registered else { return }
        registered = true
        let digitkeyCodes: [UInt32] = [
            KeyCode.one, KeyCode.two, KeyCode.three, KeyCode.four, KeyCode.five, KeyCode.six, KeyCode.seven, KeyCode.eight, KeyCode.nine
        ]
        
        // ⌘⌥Space — показать/скрыть лаунчер (последний режим)
        HotkeyService.shared.register(keyCode: KeyCode.space, carbonModifiers: CarbonMods.cmdOpt) {
            L.hotkey.info("⌘⌥Space -> toggle launcher")
            windowManager.toggleAndFocus()
        }
        
        // ⌘⇧T - открыть создание задачи
        HotkeyService.shared.register(keyCode: KeyCode.t, carbonModifiers: CarbonMods.cmdShift) {
            L.hotkey.info("⌘⇧T -> create new task")
            NotificationCenter.default.post(name: .showCreateTaskView, object: nil)
            windowManager.showAndFocus()
        }
        
        // ⌘⇧V - открыть окно в режиме Clipboard
        HotkeyService.shared.register(keyCode: KeyCode.v, carbonModifiers: CarbonMods.cmdShift) {
            L.hotkey.info("⌘⇧V -> open Clipboard mode")
            shell.switchMode(.clipboard, prefillQuery: "") // пустой запрос, но форсируем режим
            windowManager.showAndFocus()
        }
        
        for (index, keyCode) in digitkeyCodes.enumerated() {
            HotkeyService.shared.register(keyCode: keyCode, carbonModifiers: CarbonMods.cmdOpt) {
                L.hotkey.info("⌘⌥\(index) -> Quick Paste \(index + 1)")
                shell.paste(number: index)
            }
        }
        
        HotkeyService.shared.register(keyCode: KeyCode.x, carbonModifiers: CarbonMods.controlShift) {
            L.hotkey.info("⌃⇧X -> Delete All Entries")
            shell.deleteAllFromClipboardHistory()
        }
        
        HotkeyService.shared.register(keyCode: KeyCode.k, carbonModifiers: CarbonMods.cmd) {
            L.hotkey.info("⌘K -> Open Actions")
            DispatchQueue.main.async {
                shell.isActionsMenuOpen.toggle()
            }
        }
        
        // ⌘⌥S - Выбрать область для скриншотов
        HotkeyService.shared.register(keyCode: KeyCode.s, carbonModifiers: CarbonMods.cmdOpt) {
            L.hotkey.info("⌘⌥S -> Select Screenshot Area")
            ScreenshotManager.shared.selectArea()
        }
        
        // ⌘⌥C - Сделать скриншот и отправить в DeepSeek
        HotkeyService.shared.register(keyCode: KeyCode.c, carbonModifiers: CarbonMods.cmdOpt) {
            L.hotkey.info("⌘⌥C -> Capture Screenshot and Send to DeepSeek")
            ScreenshotManager.shared.captureAndSend()
        }
        
        // ⌘⌥M - Извлечь содержимое <div role="main"> из открытой страницы
        HotkeyService.shared.register(keyCode: KeyCode.m, carbonModifiers: CarbonMods.cmdOpt) {
            L.hotkey.info("⌘⌥M -> Extract main content from browser")
            WebContentExtractor.shared.extractMainContent()
        }
    }
    
    static func registerClipboardHotkeys(shell: ShellModel) -> [UInt32] {
        let id1 = HotkeyService.shared.register(keyCode: KeyCode.p, carbonModifiers: CarbonMods.controlShift) {
            L.clipboardActionsHotkey.info("⌃⇧P -> Pin Entry")
            if let item = shell.selectedItem, let clipboardItem = item.source as? ClipboardItem {
                shell.pin(item: clipboardItem)
            }
        }
        
        let id2 = HotkeyService.shared.register(keyCode: KeyCode.x, carbonModifiers: CarbonMods.control) {
            L.clipboardActionsHotkey.info("⌃X -> Delete Entry")
            if let item = shell.selectedItem, let clipboardItem =  item.source as? ClipboardItem {
                shell.deleteItem(item: clipboardItem)
            }
        }
        
        let id3 = HotkeyService.shared.register(keyCode: KeyCode.p, carbonModifiers: CarbonMods.optionControlShift) {
            L.clipboardActionsHotkey.info("⌃⌥⇧P -> Unpin Entry")
            if let item = shell.selectedItem, let clipboardItem =  item.source as? ClipboardItem {
                shell.unpin(item: clipboardItem)
            }
        }
        return [id1, id2, id3]
    }
}
