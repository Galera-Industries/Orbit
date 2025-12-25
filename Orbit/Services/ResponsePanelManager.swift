//
//  ResponsePanelManager.swift
//  Orbit
//
//  Created by Auto on 2025.
//

import SwiftUI
import AppKit

extension Notification.Name {
    static let responsePanelToggleLayout = Notification.Name("responsePanelToggleLayout")
    static let responsePanelToggleBackground = Notification.Name("responsePanelToggleBackground")
}

final class ResponsePanelManager {
    static let shared = ResponsePanelManager()
    
    private var panelWindow: NSWindow?
    private var hotkeyID: UInt32?
    private var toggleLayoutHotkeyID: UInt32?
    private var toggleBackgroundHotkeyID: UInt32?
    private var hostingView: NSHostingView<ResponsePanelView>?
    
    private init() {
        setupPanel()
        registerHotkeys()
    }
    
    private func setupPanel() {
        // Убеждаемся, что работаем в главном потоке
        assert(Thread.isMainThread, "setupPanel must be called on main thread")
        
        // Закрываем старое окно если есть
        if let oldWindow = panelWindow {
            oldWindow.orderOut(nil)
            // Удаляем contentView перед освобождением
            if let contentView = oldWindow.contentView {
                contentView.removeFromSuperview()
            }
            oldWindow.contentView = nil
            panelWindow = nil
        }
        
        let panelSize = getPanelSize()
        let panelPosition = getPanelPosition()
        guard let screenFrame = NSScreen.main?.visibleFrame else {
            print("⚠️ Не удалось получить размер экрана")
            return
        }
        
        // Вычисляем позицию окна в зависимости от настроек
        let x: CGFloat
        let y: CGFloat
        
        switch panelPosition {
        case "left-top":
            x = screenFrame.minX + 20
            y = screenFrame.maxY - panelSize.height - 20
        case "left-bottom":
            x = screenFrame.minX + 20
            y = screenFrame.minY + 20
        case "right-bottom":
            x = screenFrame.maxX - panelSize.width - 20
            y = screenFrame.minY + 20
        case "right", "right-top":
            x = screenFrame.maxX - panelSize.width - 20
            y = screenFrame.maxY - panelSize.height - 20
        default:
            x = screenFrame.maxX - panelSize.width - 20
            y = screenFrame.maxY - panelSize.height - 20
        }
        
        let hostingView = NSHostingView(rootView: ResponsePanelView())
        hostingView.autoresizingMask = [.width, .height]
        self.hostingView = hostingView
        
        let window = NSWindow(
            contentRect: NSRect(origin: NSPoint(x: x, y: y), size: panelSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.contentView = hostingView
        window.contentView?.autoresizesSubviews = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = false
        window.hidesOnDeactivate = false
        window.hasShadow = true
        
        panelWindow = window
    }
    
    func toggle() {
        guard let window = panelWindow else {
            setupPanel()
            toggle()
            return
        }
        
        if window.isVisible {
            hide()
        } else {
            show()
        }
    }
    
    func show() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.show()
            }
            return
        }
        
        guard let window = panelWindow else {
            setupPanel()
            if panelWindow != nil {
                show()
            }
            return
        }
        
        // Обновляем позицию на случай изменения настроек
        let panelSize = getPanelSize()
        let panelPosition = getPanelPosition()
        guard let screenFrame = NSScreen.main?.visibleFrame else { return }
        
        let x: CGFloat
        let y: CGFloat
        
        switch panelPosition {
        case "left-top":
            x = screenFrame.minX + 20
            y = screenFrame.maxY - panelSize.height - 20
        case "left-bottom":
            x = screenFrame.minX + 20
            y = screenFrame.minY + 20
        case "right-bottom":
            x = screenFrame.maxX - panelSize.width - 20
            y = screenFrame.minY + 20
        case "right", "right-top":
            x = screenFrame.maxX - panelSize.width - 20
            y = screenFrame.maxY - panelSize.height - 20
        default:
            x = screenFrame.maxX - panelSize.width - 20
            y = screenFrame.maxY - panelSize.height - 20
        }
        
        window.setContentSize(panelSize)
        window.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: panelSize), display: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hide() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.hide()
            }
            return
        }
        panelWindow?.orderOut(nil)
    }
    
    func updatePanel() {
        // Пересоздаём панель при изменении настроек
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let wasVisible = self.panelWindow?.isVisible ?? false
            self.hide()
            
            // Небольшая задержка перед пересозданием, чтобы окно успело закрыться
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self = self else { return }
                self.setupPanel()
                if wasVisible {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                        self?.show()
                    }
                }
            }
        }
    }
    
    private func getPanelSize() -> NSSize {
        let width = UserDefaults.standard.double(forKey: "responsePanelWidth")
        let height = UserDefaults.standard.double(forKey: "responsePanelHeight")
        
        let defaultSize: CGFloat = 50
        return NSSize(
            width: width > 0 ? width : defaultSize,
            height: height > 0 ? height : defaultSize
        )
    }
    
    private func getPanelPosition() -> String {
        let position = UserDefaults.standard.string(forKey: "responsePanelPosition") ?? "right"
        // Миграция старых значений
        if position == "left" {
            UserDefaults.standard.set("left-top", forKey: "responsePanelPosition")
            return "left-top"
        }
        if position == "right" {
            UserDefaults.standard.set("right-top", forKey: "responsePanelPosition")
            return "right-top"
        }
        return position
    }
    
    private func registerHotkeys() {
        // Регистрируем горячую клавишу для показа/скрытия панели
        let keyCodeString = UserDefaults.standard.string(forKey: "responsePanelHotkeyKey") ?? "r"
        let modifiers = UserDefaults.standard.stringArray(forKey: "responsePanelHotkeyModifiers") ?? ["cmd", "opt"]
        
        let keyCode = keyCodeFromString(keyCodeString)
        let carbonMods = carbonModifiersFromStrings(modifiers)
        
        hotkeyID = HotkeyService.shared.register(keyCode: keyCode, carbonModifiers: carbonMods) { [weak self] in
            self?.toggle()
        }
        
        // Горячая клавиша для переключения режима отображения: ⌘⌥L
        toggleLayoutHotkeyID = HotkeyService.shared.register(keyCode: KeyCode.l, carbonModifiers: CarbonMods.cmdOpt) {
            ResponsePanelManager.shared.toggleLayoutMode()
        }
        
        // Горячая клавиша для переключения фона: ⌘⌥B
        toggleBackgroundHotkeyID = HotkeyService.shared.register(keyCode: KeyCode.b, carbonModifiers: CarbonMods.cmdOpt) {
            ResponsePanelManager.shared.toggleBackground()
        }
    }
    
    func updateHotkey() {
        if let id = hotkeyID {
            HotkeyService.shared.unregister(id: id)
        }
        if let id = toggleLayoutHotkeyID {
            HotkeyService.shared.unregister(id: id)
        }
        if let id = toggleBackgroundHotkeyID {
            HotkeyService.shared.unregister(id: id)
        }
        registerHotkeys()
    }
    
    func toggleLayoutMode() {
        let currentMode = UserDefaults.standard.string(forKey: "responsePanelLayoutMode") ?? "horizontal"
        let newMode = currentMode == "horizontal" ? "vertical" : "horizontal"
        UserDefaults.standard.set(newMode, forKey: "responsePanelLayoutMode")
        
        // Обновляем view через NotificationCenter
        NotificationCenter.default.post(name: .responsePanelToggleLayout, object: nil)
    }
    
    func toggleBackground() {
        // Переключаем между прозрачным и вторым режимом
        let currentValue = UserDefaults.standard.bool(forKey: "responsePanelTransparentMode")
        UserDefaults.standard.set(!currentValue, forKey: "responsePanelTransparentMode")
        
        // Обновляем view через NotificationCenter
        NotificationCenter.default.post(name: .responsePanelToggleBackground, object: nil)
    }
    
    private func keyCodeFromString(_ string: String) -> UInt32 {
        switch string.lowercased() {
        case "r": return KeyCode.r
        case "v": return KeyCode.v
        case "t": return KeyCode.t
        case "s": return KeyCode.s
        case "c": return KeyCode.c
        case "m": return KeyCode.m
        case "k": return KeyCode.k
        case "p": return KeyCode.p
        case "x": return KeyCode.x
        case "space": return KeyCode.space
        case "1": return KeyCode.one
        case "2": return KeyCode.two
        case "3": return KeyCode.three
        case "4": return KeyCode.four
        case "5": return KeyCode.five
        case "6": return KeyCode.six
        case "7": return KeyCode.seven
        case "8": return KeyCode.eight
        case "9": return KeyCode.nine
        default: return KeyCode.r
        }
    }
    
    private func carbonModifiersFromStrings(_ strings: [String]) -> UInt32 {
        var mods: UInt32 = 0
        for string in strings {
            switch string.lowercased() {
            case "cmd": mods |= CarbonMods.cmd
            case "opt": mods |= CarbonMods.opt
            case "shift": mods |= CarbonMods.shift
            case "control": mods |= CarbonMods.control
            default: break
            }
        }
        return mods
    }
}


