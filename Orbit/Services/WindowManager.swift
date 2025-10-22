//
//  WindowManager.swift
//  Orbit
//
//  Created by Tom Tim on 20.10.2025.
//

import SwiftUI
import AppKit
import Combine

extension Notification.Name {
    static let focusSearchField = Notification.Name("FocusSearchField")
}

final class WindowManager: ObservableObject {
    weak var window: NSWindow?
    private var clickMonitor: ClickOutsideMonitor?
    private var obs: Any?
    
    func showAndFocus() {
        guard let w = window else { return }
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
        NotificationCenter.default.post(name: .focusSearchField, object: nil)
    }
    
    func hide() { window?.orderOut(nil) }
    
    func toggleAndFocus() {
        guard let w = window else { return }
        if w.isVisible && NSApp.isActive { hide() } else { showAndFocus() }
    }
    
    func enableAutoHideOnBlur() {
        guard let w = window else { return }
        
        clickMonitor = ClickOutsideMonitor(window: w) { [weak self] in
            self?.hide()
        }
        
        obs = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.hide()
        }
    }
}
