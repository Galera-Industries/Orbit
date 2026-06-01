//
//  ResponsePanelManager.swift
//  Orbit
//
//  Created by Auto on 2025.
//

import SwiftUI
import AppKit
internal import os

extension Notification.Name {
    static let responsePanelToggleLayout = Notification.Name("responsePanelToggleLayout")
    static let responsePanelToggleBackground = Notification.Name("responsePanelToggleBackground")
    static let responsePanelTextSizeDidChange = Notification.Name("responsePanelTextSizeDidChange")
}

final class ResponsePanelManager {
    static let shared = ResponsePanelManager()
    
    private var panelWindow: NSWindow?
    private var hotkeyID: UInt32?
    private var toggleLayoutHotkeyID: UInt32?
    private var toggleBackgroundHotkeyID: UInt32?
    private var increaseTextSizeHotkeyID: UInt32?
    private var increaseTextSizeWithShiftHotkeyID: UInt32?
    private var decreaseTextSizeHotkeyID: UInt32?
    private var hostingView: NSHostingView<ResponsePanelView>?

    private enum Defaults {
        static let width: CGFloat = 560
        static let height: CGFloat = 380
        static let horizontalInset: CGFloat = 20
        static let verticalInset: CGFloat = 20
        static let textSize: CGFloat = 12
        static let minTextSize: CGFloat = 9
        static let maxTextSize: CGFloat = 24
    }
    
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
        
        guard let screenFrame = NSScreen.main?.visibleFrame else {
            L.window.error("Failed to get visible screen frame for response panel")
            return
        }
        let panelSize = getPanelSize(screenFrame: screenFrame)
        let panelPosition = getPanelPosition()

        let frame = frameForPanel(
            size: panelSize,
            position: panelPosition,
            screenFrame: screenFrame
        )
        
        let hostingView = NSHostingView(rootView: ResponsePanelView())
        hostingView.autoresizingMask = [.width, .height]
        self.hostingView = hostingView
        
        let window = NSWindow(
            contentRect: frame,
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
        
        // Скрываем окно от записи экрана и демонстрации
        ScreenCaptureShield.apply(to: window)
        
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
        guard let screenFrame = NSScreen.main?.visibleFrame else { return }
        let panelSize = getPanelSize(screenFrame: screenFrame)
        let panelPosition = getPanelPosition()

        let frame = frameForPanel(
            size: panelSize,
            position: panelPosition,
            screenFrame: screenFrame
        )

        window.setContentSize(panelSize)
        window.setFrame(frame, display: true)
        // Используем orderFront вместо makeKeyAndOrderFront, чтобы не активировать приложение
        // и сохранить фокус на предыдущем приложении (например, Safari)
        window.orderFront(nil)
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
    
    private func getPanelSize(screenFrame: NSRect) -> NSSize {
        let storedWidth = CGFloat(UserDefaults.standard.double(forKey: "responsePanelWidth"))
        let storedHeight = CGFloat(UserDefaults.standard.double(forKey: "responsePanelHeight"))
        let width = storedWidth > 0 ? storedWidth : Defaults.width
        let height = storedHeight > 0 ? storedHeight : Defaults.height

        return NSSize(
            width: min(width, screenFrame.width),
            height: min(height, screenFrame.height)
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

    private func getPanelInsets() -> (horizontal: CGFloat, vertical: CGFloat) {
        let defaults = UserDefaults.standard
        let hasHorizontal = defaults.object(forKey: "responsePanelHorizontalInset") != nil
        let hasVertical = defaults.object(forKey: "responsePanelVerticalInset") != nil
        let storedHorizontal = CGFloat(defaults.double(forKey: "responsePanelHorizontalInset"))
        let storedVertical = CGFloat(defaults.double(forKey: "responsePanelVerticalInset"))
        let horizontal = hasHorizontal ? storedHorizontal : Defaults.horizontalInset
        let vertical = hasVertical ? storedVertical : Defaults.verticalInset
        return (horizontal, vertical)
    }

    private func frameForPanel(size: NSSize, position: String, screenFrame: NSRect) -> NSRect {
        let insets = getPanelInsets()
        let horizontalInset = min(insets.horizontal, max(0, screenFrame.width - size.width))
        let verticalInset = min(insets.vertical, max(0, screenFrame.height - size.height))

        let x: CGFloat
        let y: CGFloat

        switch position {
        case "left-top":
            x = screenFrame.minX + horizontalInset
            y = screenFrame.maxY - size.height - verticalInset
        case "left-bottom":
            x = screenFrame.minX + horizontalInset
            y = screenFrame.minY + verticalInset
        case "right-bottom":
            x = screenFrame.maxX - size.width - horizontalInset
            y = screenFrame.minY + verticalInset
        case "right", "right-top":
            x = screenFrame.maxX - size.width - horizontalInset
            y = screenFrame.maxY - size.height - verticalInset
        default:
            x = screenFrame.maxX - size.width - horizontalInset
            y = screenFrame.maxY - size.height - verticalInset
        }

        return NSRect(origin: NSPoint(x: x, y: y), size: size)
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

        // Горячие клавиши размера текста: ⌘⌥- / ⌘⌥+
        decreaseTextSizeHotkeyID = HotkeyService.shared.register(
            keyCode: KeyCode.minus,
            carbonModifiers: CarbonMods.cmdOpt
        ) {
            ResponsePanelManager.shared.adjustTextSize(delta: -1)
        }
        increaseTextSizeHotkeyID = HotkeyService.shared.register(
            keyCode: KeyCode.equal,
            carbonModifiers: CarbonMods.cmdOpt
        ) {
            ResponsePanelManager.shared.adjustTextSize(delta: 1)
        }
        // На ANSI-клавиатуре "+" набирается как Shift + "=".
        increaseTextSizeWithShiftHotkeyID = HotkeyService.shared.register(
            keyCode: KeyCode.equal,
            carbonModifiers: CarbonMods.cmdOptShift
        ) {
            ResponsePanelManager.shared.adjustTextSize(delta: 1)
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
        if let id = increaseTextSizeHotkeyID {
            HotkeyService.shared.unregister(id: id)
        }
        if let id = increaseTextSizeWithShiftHotkeyID {
            HotkeyService.shared.unregister(id: id)
        }
        if let id = decreaseTextSizeHotkeyID {
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

    func adjustTextSize(delta: CGFloat) {
        let currentSize = CGFloat(UserDefaults.standard.double(forKey: "responsePanelTextSize"))
        let normalizedCurrent = currentSize > 0 ? currentSize : Defaults.textSize
        let newSize = min(Defaults.maxTextSize, max(Defaults.minTextSize, normalizedCurrent + delta))
        guard abs(newSize - normalizedCurrent) > 0.001 else { return }
        UserDefaults.standard.set(Double(newSize), forKey: "responsePanelTextSize")
        NotificationCenter.default.post(name: .responsePanelTextSizeDidChange, object: nil)
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


