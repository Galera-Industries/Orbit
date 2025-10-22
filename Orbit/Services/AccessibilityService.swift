//
//  AccessibilityService.swift
//  Orbit
//
//  Created by Tom Tim on 20.10.2025.
//

import Foundation
import ApplicationServices
import AppKit
import Carbon.HIToolbox
internal import os

final class AccessibilityService {
    static let shared = AccessibilityService()
    
    @discardableResult
    func ensureAuthorized(prompt: Bool) -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: prompt] as CFDictionary
        let ok = AXIsProcessTrustedWithOptions(opts)
        L.ax.info("AX trusted = \(ok)")
        return ok
    }
    
    func quickPaste() {
        if !ensureAuthorized(prompt: true) {
            L.ax.error("Accessibility permission NOT granted — cannot paste")
            return
        }
        L.ax.info("quickPaste scheduled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            L.ax.info("quickPaste -> Cmd+V")
            self.pressCommandV()
        }
    }
    
    private func pressCommandV() {
        guard let src = CGEventSource(stateID: .combinedSessionState) else { return }
        
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = .maskCommand
        
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUp?.flags = .maskCommand
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
