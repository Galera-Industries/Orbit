//
//  KeyEventMonitor.swift
//  Orbit
//
//  Created by Tom Tim on 20.10.2025.
//

import AppKit

// MARK:  Локальный монитор, чтобы ловить стрелки/Enter/Esc, когда фокус в TextField.
final class KeyEventMonitor {
    private var monitor: Any?
    init(handler: @escaping (NSEvent) -> NSEvent?) {
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown], handler: handler)
    }
    deinit {
        if let m = monitor { NSEvent.removeMonitor(m) }
    }
}
