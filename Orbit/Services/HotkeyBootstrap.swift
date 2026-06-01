//
//  HotkeyBootstrap.swift
//  Orbit
//
//  Created by Tom Tim on 20.10.2025.
//

import Foundation
internal import os

enum HotkeyBootstrap {
    private static var globalHotkeyIDs: [UInt32] = []
    private static weak var storedWindowManager: WindowManager?
    private static weak var storedShell: ShellModel?

    static func registerDefaults(windowManager: WindowManager, shell: ShellModel) {
        storedWindowManager = windowManager
        storedShell = shell
        reloadGlobalHotkeys(windowManager: windowManager, shell: shell)
    }

    static func reload() {
        guard let wm = storedWindowManager, let sh = storedShell else { return }
        reloadGlobalHotkeys(windowManager: wm, shell: sh)
    }

    private static func reloadGlobalHotkeys(windowManager: WindowManager, shell: ShellModel) {
        for id in globalHotkeyIDs {
            HotkeyService.shared.unregister(id: id)
        }
        globalHotkeyIDs.removeAll()

        let config = HotkeyConfig.shared

        func register(entryID: String, keyCode: UInt32, mods: UInt32, handler: @escaping () -> Void) {
            guard config.entry(for: entryID)?.enabled != false else { return }
            let id = HotkeyService.shared.register(keyCode: keyCode, carbonModifiers: mods, handler: handler)
            globalHotkeyIDs.append(id)
        }

        func registerFromConfig(entryID: String, defaultKey: UInt32, defaultMods: UInt32, handler: @escaping () -> Void) {
            guard let entry = config.entry(for: entryID), entry.enabled else { return }
            let keyCode = HotkeyConfig.keyCode(for: entry.keyChar) ?? defaultKey
            let mods = HotkeyConfig.carbonMods(for: entry.modifiers)
            let id = HotkeyService.shared.register(keyCode: keyCode, carbonModifiers: mods, handler: handler)
            globalHotkeyIDs.append(id)
        }

        // ⌘⌥Space — показать/скрыть лаунчер
        if let entry = config.entry(for: "launcher"), entry.enabled {
            // Space is special-cased: always use kVK_Space regardless of keyChar
            let mods = HotkeyConfig.carbonMods(for: entry.modifiers)
            let id = HotkeyService.shared.register(keyCode: KeyCode.space, carbonModifiers: mods) {
                L.hotkey.info("launcher hotkey -> toggle launcher")
                windowManager.toggleAndFocus()
            }
            globalHotkeyIDs.append(id)
        }

        // ⌘⇧T — создать задачу
        registerFromConfig(entryID: "createTask", defaultKey: KeyCode.t, defaultMods: CarbonMods.cmdShift) {
            L.hotkey.info("createTask hotkey -> create new task")
            NotificationCenter.default.post(name: .showCreateTaskView, object: nil)
            windowManager.showAndFocus()
        }

        // ⌘⇧V — буфер обмена
        registerFromConfig(entryID: "clipboard", defaultKey: KeyCode.v, defaultMods: CarbonMods.cmdShift) {
            L.hotkey.info("clipboard hotkey -> open Clipboard mode")
            shell.switchMode(.clipboard, prefillQuery: "")
            windowManager.showAndFocus()
        }

        // ⌘⌥1-9 — быстрая вставка
        if config.entry(for: "clipDigits")?.enabled != false {
            let digitKeyCodes: [UInt32] = [
                KeyCode.one, KeyCode.two, KeyCode.three, KeyCode.four, KeyCode.five,
                KeyCode.six, KeyCode.seven, KeyCode.eight, KeyCode.nine
            ]
            let clipMods = HotkeyConfig.carbonMods(for: config.entry(for: "clipDigits")?.modifiers ?? ["cmd", "opt"])
            for (index, keyCode) in digitKeyCodes.enumerated() {
                let idx = index
                let id = HotkeyService.shared.register(keyCode: keyCode, carbonModifiers: clipMods) {
                    L.hotkey.info("clipDigit hotkey -> Quick Paste \(idx + 1)")
                    shell.paste(number: idx)
                }
                globalHotkeyIDs.append(id)
            }
        }

        // ⌃⇧X — удалить все из буфера
        registerFromConfig(entryID: "deleteAllClip", defaultKey: KeyCode.x, defaultMods: CarbonMods.controlShift) {
            L.hotkey.info("deleteAllClip hotkey -> Delete All Entries")
            shell.deleteAllFromClipboardHistory()
        }

        // ⌘K — Actions
        registerFromConfig(entryID: "actions", defaultKey: KeyCode.k, defaultMods: CarbonMods.cmd) {
            L.hotkey.info("actions hotkey -> Open Actions")
            DispatchQueue.main.async { shell.isActionsMenuOpen.toggle() }
        }

        // ⌘⌥S — выбрать область скриншота
        registerFromConfig(entryID: "screenshotArea", defaultKey: KeyCode.s, defaultMods: CarbonMods.cmdOpt) {
            L.hotkey.info("screenshotArea hotkey -> Select Screenshot Area")
            ScreenshotManager.shared.selectArea()
        }

        // ⌘⌥C — скриншот и отправить
        registerFromConfig(entryID: "screenshotSend", defaultKey: KeyCode.c, defaultMods: CarbonMods.cmdOpt) {
            L.hotkey.info("screenshotSend hotkey -> Capture Screenshot and Send to DeepSeek")
            ScreenshotManager.shared.captureAndSend()
        }

        // ⌘⌥M — извлечь контент из браузера
        registerFromConfig(entryID: "browserExtract", defaultKey: KeyCode.m, defaultMods: CarbonMods.cmdOpt) {
            L.hotkey.info("browserExtract hotkey -> Extract main content from browser")
            WebContentExtractor.shared.extractMainContent()
        }

        // ⌘⌥N — извлечь датасет-вопросы из браузера (информативный сценарий)
        registerFromConfig(entryID: "browserExtractDataset", defaultKey: KeyCode.n, defaultMods: CarbonMods.cmdOpt) {
            L.hotkey.info("browserExtractDataset hotkey -> Extract dataset questions from browser")
            WebContentExtractor.shared.extractDatasetQuestionContent()
        }

        // ⌘⌥P — сформировать контекст по main.py и отправить в ChatGPT
        registerFromConfig(entryID: "pyCharmProgress", defaultKey: KeyCode.p, defaultMods: CarbonMods.cmdOpt) {
            L.hotkey.info("pyCharmProgress hotkey -> Send PyCharm main.py progress to ChatGPT")
            WebContentExtractor.shared.sendPyCharmProgressContext()
        }

        // ⌘⌥Z — отправить последний файл из папки напрямую в GPT
        registerFromConfig(entryID: "fileResearch", defaultKey: KeyCode.z, defaultMods: CarbonMods.cmdOpt) {
            L.hotkey.info("fileResearch hotkey -> Send latest file to GPT")
            FileResearchModule.sendLatestFileToChatGPT()
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
            if let item = shell.selectedItem, let clipboardItem = item.source as? ClipboardItem {
                shell.deleteItem(item: clipboardItem)
            }
        }

        let id3 = HotkeyService.shared.register(keyCode: KeyCode.p, carbonModifiers: CarbonMods.optionControlShift) {
            L.clipboardActionsHotkey.info("⌃⌥⇧P -> Unpin Entry")
            if let item = shell.selectedItem, let clipboardItem = item.source as? ClipboardItem {
                shell.unpin(item: clipboardItem)
            }
        }
        return [id1, id2, id3]
    }
}
