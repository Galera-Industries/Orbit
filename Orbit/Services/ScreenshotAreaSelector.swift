//
//  ScreenshotAreaSelector.swift
//  Orbit
//

import Foundation
import AppKit
import CoreGraphics
import SwiftUI

final class ScreenshotAreaSelector {
    static let shared = ScreenshotAreaSelector()
    
    private var selectionWindows: [NSWindow] = []
    private var selectionRect: CGRect?
    private var completionHandler: ((ScreenshotArea?) -> Void)?
    private var cancelTimer: Timer?
    private var isSelecting = false  // Флаг активного выбора
    
    private init() {}
    
    /// Запускает процесс выбора области экрана
    func selectArea(completion: @escaping (CGRect?) -> Void) {
        print("📍 selectArea() started")
        
        // Проверяем, не активен ли уже выбор
        guard !isSelecting else {
            print("⚠️ Selection already in progress")
            return
        }
        
        isSelecting = true
        
        // Отменяем предыдущий выбор, если он активен
        cleanupWindows()
        
        // Адаптируем старый API к новому
        completionHandler = { [weak self] area in
            self?.isSelecting = false
            completion(area?.rect)
        }
        
        // Небольшая задержка перед созданием окон
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.createSelectionWindowsOnAllScreens()
        }
        
        // Таймаут на случай зависания (60 секунд)
        cancelTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { [weak self] _ in
            print("⏰ Selection timeout")
            self?.cancelSelection()
        }
    }
    
    private func createSelectionWindowsOnAllScreens() {
        print("📍 Creating selection windows on \(NSScreen.screens.count) screens")
        
        selectionWindows.removeAll()
        
        // Создаем окно на каждом экране
        for (index, screen) in NSScreen.screens.enumerated() {
            let screenFrame = screen.frame
            print("📺 Screen \(index): \(screenFrame)")
            
            let window = SelectionWindow(
                contentRect: screenFrame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            window.level = .screenSaver
            window.backgroundColor = NSColor.black.withAlphaComponent(0.01) // Почти прозрачный, но ловит клики
            window.isOpaque = false
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.isReleasedWhenClosed = false
            window.hidesOnDeactivate = false
            window.acceptsMouseMovedEvents = true
            ScreenCaptureShield.apply(to: window)
            
            // Создаем кастомный view
            let selectionView = SelectionView(frame: NSRect(origin: .zero, size: screenFrame.size), screen: screen)
            selectionView.onComplete = { [weak self] area in
                print("✅ SelectionView.onComplete called")
                self?.finishSelection(with: area)
            }
            selectionView.onCancel = { [weak self] in
                print("❌ SelectionView.onCancel called")
                self?.cancelSelection()
            }
            
            window.contentView = selectionView
            window.delegate = selectionView // Для отслеживания потери фокуса
            selectionWindows.append(window)
        }
        
        print("📍 Showing \(selectionWindows.count) windows")
        
        // Показываем окна
        NSApp.activate(ignoringOtherApps: true)
        
        for (index, window) in selectionWindows.enumerated() {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            print("📍 Window \(index) shown, isVisible: \(window.isVisible), level: \(window.level.rawValue)")
        }
        
        // Делаем первое окно key window и first responder
        if let firstWindow = selectionWindows.first {
            firstWindow.makeKey()
            if let selectionView = firstWindow.contentView as? SelectionView {
                let success = firstWindow.makeFirstResponder(selectionView)
                print("📍 makeFirstResponder: \(success)")
            }
        }
        
        print("📍 Windows setup complete, waiting for user input...")
    }
    
    private func finishSelection(with area: ScreenshotArea) {
        print("📍 finishSelection called with area: \(area.rect)")
        
        cancelTimer?.invalidate()
        cancelTimer = nil
        
        let savedArea = area
        cleanupWindows()
        self.savedArea = savedArea
        
        let handler = completionHandler
        completionHandler = nil
        isSelecting = false
        
        handler?(savedArea)
        
        print("✅ Область сохранена: \(savedArea.rect) на экране \(savedArea.displayID)")
    }
    
    private func cancelSelection() {
        print("📍 cancelSelection called")
        
        cancelTimer?.invalidate()
        cancelTimer = nil
        
        cleanupWindows()
        
        let handler = completionHandler
        completionHandler = nil
        isSelecting = false
        
        handler?(nil)
        
        print("❌ Выбор области отменён")
    }
    
    private func cleanupWindows() {
        print("📍 cleanupWindows called, windows count: \(selectionWindows.count)")
        
        for window in selectionWindows {
            window.orderOut(nil)
        }
        selectionWindows.removeAll()
        selectionRect = nil
    }
    
    /// Структура для сохранения области с информацией об экране
    struct ScreenshotArea {
        let rect: CGRect
        let displayID: CGDirectDisplayID
        
        var rectCodable: CGRectCodable {
            CGRectCodable(rect: rect)
        }
    }
    
    /// Получает сохраненную область
    var savedArea: ScreenshotArea? {
        get {
            if let data = UserDefaults.standard.data(forKey: "screenshotAreaWithDisplay") {
                if let area = try? JSONDecoder().decode(ScreenshotArea.self, from: data) {
                    return area
                }
            }
            
            if let data = UserDefaults.standard.data(forKey: "screenshotArea"),
               let rectCodable = try? JSONDecoder().decode(CGRectCodable.self, from: data) {
                return ScreenshotArea(rect: rectCodable.rect, displayID: CGMainDisplayID())
            }
            
            return nil
        }
        set {
            if let area = newValue {
                if let data = try? JSONEncoder().encode(area) {
                    UserDefaults.standard.set(data, forKey: "screenshotAreaWithDisplay")
                    let rectCodable = CGRectCodable(rect: area.rect)
                    if let rectData = try? JSONEncoder().encode(rectCodable) {
                        UserDefaults.standard.set(rectData, forKey: "screenshotArea")
                    }
                }
            } else {
                UserDefaults.standard.removeObject(forKey: "screenshotAreaWithDisplay")
                UserDefaults.standard.removeObject(forKey: "screenshotArea")
            }
        }
    }
    
    var savedRect: CGRect? {
        return savedArea?.rect
    }
}

// MARK: - Codable

struct CGRectCodable: Codable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    
    var rect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
    
    init(rect: CGRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.size.width
        self.height = rect.size.height
    }
}

extension ScreenshotAreaSelector.ScreenshotArea: Codable {
    enum CodingKeys: String, CodingKey {
        case rect, displayID
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rectCodable = try container.decode(CGRectCodable.self, forKey: .rect)
        rect = rectCodable.rect
        displayID = try container.decode(UInt32.self, forKey: .displayID)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(CGRectCodable(rect: rect), forKey: .rect)
        try container.encode(displayID, forKey: .displayID)
    }
}

// MARK: - SelectionWindow

private class SelectionWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    override func resignKey() {
        // НЕ вызываем super - не даём окну потерять key статус
        print("⚠️ SelectionWindow.resignKey() called but ignored")
    }
    
    override func resignMain() {
        print("⚠️ SelectionWindow.resignMain() called but ignored")
    }
}

// MARK: - SelectionView

private class SelectionView: NSView, NSWindowDelegate {
    var onComplete: ((ScreenshotAreaSelector.ScreenshotArea) -> Void)?
    var onCancel: (() -> Void)?
    
    private let screen: NSScreen
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?
    private var isDragging = false
    private var trackingArea: NSTrackingArea?
    
    init(frame: NSRect, screen: NSScreen) {
        self.screen = screen
        super.init(frame: frame)
        
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.3).cgColor
        
        print("📍 SelectionView created for screen: \(screen.frame)")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }
    
    // MARK: - NSWindowDelegate
    
    func windowDidResignKey(_ notification: Notification) {
        print("⚠️ Window did resign key - re-acquiring")
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeKeyAndOrderFront(nil)
        }
    }
    
    func windowDidResignMain(_ notification: Notification) {
        print("⚠️ Window did resign main")
    }
    
    // MARK: - View Lifecycle
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existingTrackingArea = trackingArea {
            removeTrackingArea(existingTrackingArea)
        }
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        
        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        print("📍 SelectionView.viewDidMoveToWindow()")
        
        if let window = window {
            window.makeFirstResponder(self)
            window.delegate = self
        }
        
        NSCursor.crosshair.push()
    }
    
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        
        if newWindow == nil {
            NSCursor.pop()
        }
    }
    
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .crosshair)
    }
    
    // MARK: - Mouse Events
    
    override func mouseEntered(with event: NSEvent) {
        NSCursor.crosshair.set()
    }
    
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        startPoint = location
        currentPoint = location
        isDragging = true
        needsDisplay = true
        
        print("🖱️ mouseDown at: \(location)")
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        print("🖱️ mouseUp, isDragging: \(isDragging)")
        
        guard isDragging, let start = startPoint, let current = currentPoint else {
            isDragging = false
            return
        }
        
        let rect = CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        
        print("🖱️ Selected rect in view coords: \(rect)")
        
        isDragging = false
        startPoint = nil
        currentPoint = nil
        
        if rect.width > 10 && rect.height > 10 {
            let screenFrame = screen.frame
            
            let globalRect = CGRect(
                x: rect.origin.x + screenFrame.origin.x,
                y: rect.origin.y + screenFrame.origin.y,
                width: rect.width,
                height: rect.height
            )
            
            let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? CGMainDisplayID()
            
            print("📐 Screen frame: \(screenFrame)")
            print("📐 Global rect: \(globalRect)")
            print("📐 Display ID: \(displayID)")
            
            let area = ScreenshotAreaSelector.ScreenshotArea(rect: globalRect, displayID: displayID)
            
            onComplete?(area)
        } else {
            print("⚠️ Area too small: \(rect.size)")
            needsDisplay = true
        }
    }
    
    // MARK: - Keyboard Events
    
    override func keyDown(with event: NSEvent) {
        print("⌨️ keyDown: keyCode=\(event.keyCode)")
        
        if event.keyCode == 53 { // ESC
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        // Фон
        NSColor.black.withAlphaComponent(0.3).setFill()
        bounds.fill()
        
        // Инструкции в центре (только если не перетаскиваем)
        if !isDragging {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 18, weight: .medium),
                .foregroundColor: NSColor.white,
                .paragraphStyle: paragraphStyle
            ]
            
            let text = "Выберите область для скриншотов\nПеретащите мышью • ESC для отмены"
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (bounds.width - textSize.width) / 2,
                y: (bounds.height - textSize.height) / 2 + 50,
                width: textSize.width + 10,
                height: textSize.height + 10
            )
            
            // Фон для текста
            let bgRect = textRect.insetBy(dx: -20, dy: -15)
            NSColor.black.withAlphaComponent(0.7).setFill()
            let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 10, yRadius: 10)
            bgPath.fill()
            
            text.draw(in: textRect, withAttributes: attributes)
        }
        
        // Выделенная область
        if let start = startPoint, let current = currentPoint, isDragging {
            let rect = CGRect(
                x: min(start.x, current.x),
                y: min(start.y, current.y),
                width: abs(current.x - start.x),
                height: abs(current.y - start.y)
            )
            
            // Очищаем выделенную область
            NSColor.clear.setFill()
            rect.fill(using: .copy)
            
            // Рамка
            NSColor.white.setStroke()
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 2
            path.stroke()
            
            // Угловые маркеры
            let markerSize: CGFloat = 10
            NSColor.white.setFill()
            
            // Углы
            let corners = [
                CGPoint(x: rect.minX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.minY),
                CGPoint(x: rect.minX, y: rect.maxY),
                CGPoint(x: rect.maxX, y: rect.maxY)
            ]
            
            for corner in corners {
                let markerRect = CGRect(
                    x: corner.x - markerSize/2,
                    y: corner.y - markerSize/2,
                    width: markerSize,
                    height: markerSize
                )
                NSBezierPath(ovalIn: markerRect).fill()
            }
            
            // Размер
            let sizeText = "\(Int(rect.width)) × \(Int(rect.height))"
            let sizeAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.white
            ]
            
            let sizeSize = sizeText.size(withAttributes: sizeAttrs)
            let padding: CGFloat = 4
            let sizeRect = CGRect(
                x: rect.midX - sizeSize.width/2 - padding,
                y: rect.minY - sizeSize.height - 10,
                width: sizeSize.width + padding * 2,
                height: sizeSize.height + padding
            )
            
            NSColor.black.withAlphaComponent(0.8).setFill()
            NSBezierPath(roundedRect: sizeRect, xRadius: 4, yRadius: 4).fill()
            
            sizeText.draw(
                at: CGPoint(x: sizeRect.origin.x + padding, y: sizeRect.origin.y + padding/2),
                withAttributes: sizeAttrs
            )
        }
    }
}
