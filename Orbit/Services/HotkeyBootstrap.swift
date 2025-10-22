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
        
        // ⌘⌥Space — показать/скрыть лаунчер (последний режим)
        HotkeyService.shared.register(keyCode: KeyCode.space, carbonModifiers: CarbonMods.cmdOpt) {
            L.hotkey.info("⌘⌥Space -> toggle launcher")
            windowManager.toggleAndFocus()
        }
        
        // ⌘⇧V - открыть окно в режиме Clipboard
        HotkeyService.shared.register(keyCode: KeyCode.v, carbonModifiers: CarbonMods.cmdShift) {
            L.hotkey.info("⌘⇧V -> open Clipboard mode")
            shell.switchMode(.clipboard, prefillQuery: "") // пустой запрос, но форсируем режим
            windowManager.showAndFocus()
        }
    }
}
