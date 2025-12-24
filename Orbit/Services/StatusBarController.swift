//
//  StatusBarController.swift
//  Orbit
//
//  Created by Vladislav Pankratov on 22.10.2025.
//

import AppKit
internal import os

final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let windowManager: WindowManager
    private let menu = NSMenu()
    
    init(windowManager: WindowManager) {
        self.windowManager = windowManager
        super.init()
        setup()
    }
    
    private func setup() {
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "sparkles",
                accessibilityDescription: "Launcher"
            )
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        let toggle = NSMenuItem(
            title: "Toggle Launcher",
            action: #selector(toggle),
            keyEquivalent: ""
        )
        toggle.target = self
        
        let settings = NSMenuItem(
            title: "Screenshot Settings",
            action: #selector(showSettings),
            keyEquivalent: ""
        )
        settings.target = self
        
        let quit = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quit.keyEquivalentModifierMask = [.command]
        quit.target = self
        
        menu.addItem(toggle)
        menu.addItem(.separator())
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(quit)
        menu.delegate = self
    }
    
    @objc
    private func handleClick(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            windowManager.toggleAndFocus()
            return
        }
        
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            L.window.info("StatusItem right click -> show menu")
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            L.window.info("StatusItem left click -> toggle")
            windowManager.toggleAndFocus()
        }
    }
    
    @objc
    private func toggle() {
        windowManager.toggleAndFocus()
    }
    
    @objc
    private func showSettings() {
        NotificationCenter.default.post(name: .showScreenshotSettings, object: nil)
    }
    
    @objc
    private func quit() {
        NSApp.terminate(nil)
    }
}

extension Notification.Name {
    static let showScreenshotSettings = Notification.Name("showScreenshotSettings")
}
