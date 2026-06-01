//
//  HotkeyConfig.swift
//  Orbit
//

import Foundation
import Combine
import Carbon.HIToolbox

struct HotkeyEntry: Identifiable, Codable {
    let id: String
    let label: String
    let defaultKeyChar: String
    let defaultModifiers: [String]
    var keyChar: String
    var modifiers: [String]
    var enabled: Bool
}

final class HotkeyConfig: ObservableObject {
    static let shared = HotkeyConfig()

    @Published var entries: [HotkeyEntry] = []

    static let defaultEntries: [HotkeyEntry] = [
        HotkeyEntry(id: "launcher",       label: "Показать/скрыть лаунчер",       defaultKeyChar: "space", defaultModifiers: ["cmd", "opt"],    keyChar: "space", modifiers: ["cmd", "opt"],    enabled: true),
        HotkeyEntry(id: "createTask",     label: "Создать задачу",                 defaultKeyChar: "t",     defaultModifiers: ["cmd", "shift"],  keyChar: "t",     modifiers: ["cmd", "shift"],  enabled: true),
        HotkeyEntry(id: "clipboard",      label: "Открыть буфер обмена",           defaultKeyChar: "v",     defaultModifiers: ["cmd", "shift"],  keyChar: "v",     modifiers: ["cmd", "shift"],  enabled: true),
        HotkeyEntry(id: "screenshotArea", label: "Выбрать область скриншота",      defaultKeyChar: "s",     defaultModifiers: ["cmd", "opt"],    keyChar: "s",     modifiers: ["cmd", "opt"],    enabled: true),
        HotkeyEntry(id: "screenshotSend", label: "Скриншот → ChatGPT",            defaultKeyChar: "c",     defaultModifiers: ["cmd", "opt"],    keyChar: "c",     modifiers: ["cmd", "opt"],    enabled: true),
        HotkeyEntry(id: "browserExtract", label: "Извлечь контент из браузера",   defaultKeyChar: "m",     defaultModifiers: ["cmd", "opt"],    keyChar: "m",     modifiers: ["cmd", "opt"],    enabled: true),
        HotkeyEntry(id: "browserExtractDataset", label: "Извлечь датасет-вопросы из браузера", defaultKeyChar: "n", defaultModifiers: ["cmd", "opt"], keyChar: "n", modifiers: ["cmd", "opt"], enabled: true),
        HotkeyEntry(id: "pyCharmProgress", label: "PyCharm: отправить прогресс main.py в GPT", defaultKeyChar: "p", defaultModifiers: ["cmd", "opt"], keyChar: "p", modifiers: ["cmd", "opt"], enabled: true),
        HotkeyEntry(id: "fileResearch",   label: "Отправить последний файл в GPT", defaultKeyChar: "z",     defaultModifiers: ["cmd", "opt"],    keyChar: "z",     modifiers: ["cmd", "opt"],    enabled: true),
        HotkeyEntry(id: "actions",        label: "Открыть меню Actions",           defaultKeyChar: "k",     defaultModifiers: ["cmd"],           keyChar: "k",     modifiers: ["cmd"],           enabled: true),
        HotkeyEntry(id: "clipDigits",     label: "Быстрая вставка ⌘⌥1-9",         defaultKeyChar: "1-9",   defaultModifiers: ["cmd", "opt"],    keyChar: "1-9",   modifiers: ["cmd", "opt"],    enabled: true),
        HotkeyEntry(id: "deleteAllClip",  label: "Удалить все из буфера",          defaultKeyChar: "x",     defaultModifiers: ["ctrl", "shift"], keyChar: "x",     modifiers: ["ctrl", "shift"], enabled: true),
    ]

    private static let storageKey = "hotkeyConfig_v1"

    private init() { load() }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let stored = try? JSONDecoder().decode([HotkeyEntry].self, from: data) else {
            entries = Self.defaultEntries
            return
        }
        var merged = stored
        for def in Self.defaultEntries where !merged.contains(where: { $0.id == def.id }) {
            merged.append(def)
        }
        entries = merged
    }

    func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    func entry(for id: String) -> HotkeyEntry? {
        entries.first(where: { $0.id == id })
    }

    func update(id: String, keyChar: String? = nil, modifiers: [String]? = nil, enabled: Bool? = nil) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        if let kc = keyChar { entries[idx].keyChar = kc }
        if let mods = modifiers { entries[idx].modifiers = mods }
        if let en = enabled { entries[idx].enabled = en }
        save()
    }

    // MARK: - Carbon helpers

    static func keyCode(for char: String) -> UInt32? {
        let map: [String: UInt32] = [
            "a": UInt32(kVK_ANSI_A), "b": UInt32(kVK_ANSI_B), "c": UInt32(kVK_ANSI_C),
            "d": UInt32(kVK_ANSI_D), "e": UInt32(kVK_ANSI_E), "f": UInt32(kVK_ANSI_F),
            "g": UInt32(kVK_ANSI_G), "h": UInt32(kVK_ANSI_H), "i": UInt32(kVK_ANSI_I),
            "j": UInt32(kVK_ANSI_J), "k": UInt32(kVK_ANSI_K), "l": UInt32(kVK_ANSI_L),
            "m": UInt32(kVK_ANSI_M), "n": UInt32(kVK_ANSI_N), "o": UInt32(kVK_ANSI_O),
            "p": UInt32(kVK_ANSI_P), "q": UInt32(kVK_ANSI_Q), "r": UInt32(kVK_ANSI_R),
            "s": UInt32(kVK_ANSI_S), "t": UInt32(kVK_ANSI_T), "u": UInt32(kVK_ANSI_U),
            "v": UInt32(kVK_ANSI_V), "w": UInt32(kVK_ANSI_W), "x": UInt32(kVK_ANSI_X),
            "y": UInt32(kVK_ANSI_Y), "z": UInt32(kVK_ANSI_Z),
            "1": UInt32(kVK_ANSI_1), "2": UInt32(kVK_ANSI_2), "3": UInt32(kVK_ANSI_3),
            "4": UInt32(kVK_ANSI_4), "5": UInt32(kVK_ANSI_5), "6": UInt32(kVK_ANSI_6),
            "7": UInt32(kVK_ANSI_7), "8": UInt32(kVK_ANSI_8), "9": UInt32(kVK_ANSI_9),
            "space": UInt32(kVK_Space),
        ]
        return map[char.lowercased()]
    }

    static func carbonMods(for modifiers: [String]) -> UInt32 {
        modifiers.reduce(UInt32(0)) { result, mod in
            switch mod {
            case "cmd":   return result | UInt32(cmdKey)
            case "opt":   return result | UInt32(optionKey)
            case "shift": return result | UInt32(shiftKey)
            case "ctrl":  return result | UInt32(controlKey)
            default:      return result
            }
        }
    }

    static func displayString(keyChar: String, modifiers: [String]) -> String {
        var parts: [String] = []
        if modifiers.contains("ctrl")  { parts.append("⌃") }
        if modifiers.contains("opt")   { parts.append("⌥") }
        if modifiers.contains("shift") { parts.append("⇧") }
        if modifiers.contains("cmd")   { parts.append("⌘") }
        parts.append(keyChar == "space" ? "Space" : keyChar.uppercased())
        return parts.joined()
    }
}
