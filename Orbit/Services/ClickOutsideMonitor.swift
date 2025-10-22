//
//  ClickOutsideMonitor.swift
//  Orbit
//
//  Created by Vladislav Pankratov on 22.10.2025.
//

import AppKit

// MARK: тут я отлавливаю клики вне Orbit, чтобы закрывать его
final class ClickOutsideMonitor {
    private var globalMon: Any?
    private var localMon: Any?
    
    init(window: NSWindow, onOutside: @escaping () -> Void) {
        globalMon = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { _ in
            guard window.isVisible else { return }
            let p = NSEvent.mouseLocation
            if !window.frame.contains(p) {
                onOutside()
            }
        }
        
        localMon = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { event in
            guard window.isVisible else { return event }
            let p = NSEvent.mouseLocation
            if !window.frame.contains(p) {
                onOutside()
            }
            return event
        }
    }
    
    deinit {
        if let m = globalMon { NSEvent.removeMonitor(m) }
        if let m = localMon { NSEvent.removeMonitor(m) }
    }
}
