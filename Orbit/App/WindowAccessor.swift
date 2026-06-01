//
//  WindowAccessor.swift
//  Orbit
//
//  Created by Tom Tim on 20.10.2025.
//

import SwiftUI
import AppKit

enum ScreenCaptureShield {
    private static var isEnabled = false
    private static var observers: [NSObjectProtocol] = []

    static func enableForAllAppWindows() {
        guard !isEnabled else { return }
        isEnabled = true

        applyToAllAppWindows()

        let center = NotificationCenter.default
        observers.append(
            center.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: nil,
                queue: .main
            ) { note in
                guard let window = note.object as? NSWindow else { return }
                apply(to: window)
            }
        )
        observers.append(
            center.addObserver(
                forName: NSWindow.didBecomeMainNotification,
                object: nil,
                queue: .main
            ) { note in
                guard let window = note.object as? NSWindow else { return }
                apply(to: window)
            }
        )
        observers.append(
            center.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification,
                object: nil,
                queue: .main
            ) { note in
                guard let window = note.object as? NSWindow else { return }
                apply(to: window)
            }
        )
    }

    static func apply(to window: NSWindow) {
        window.sharingType = .none
    }

    private static func applyToAllAppWindows() {
        NSApp.windows.forEach { apply(to: $0) }
    }
}

struct WindowAccessor: NSViewRepresentable {
    let configure: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                ScreenCaptureShield.apply(to: window)
                configure(window)
            }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
