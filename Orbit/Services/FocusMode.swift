//
//  FocusMode.swift
//  Orbit
//
//  Created by Ulyana Eskova on 03.11.2025.
//


import Foundation
import AppKit

enum FocusMode {
    private static var internalState = false
    
    static func enable() {
        if trySystemUIServer() || tryControlCenter() {
            print("🔕 FocusMode: system DND toggled")
        } else {
            internalState = true
            print("🔕 FocusMode: internal fallback enabled")
        }
    }
    
    static func disable() {
        internalState = false
        print("🔔 FocusMode: disabled")
    }
    
    // MARK: - Private
    
    @discardableResult
    private static func trySystemUIServer() -> Bool {
        let script = """
        tell application "System Events"
            if exists process "SystemUIServer" then
                tell process "SystemUIServer"
                    click menu bar item "Control Center" of menu bar 1
                    delay 0.4
                    try
                        click menu item "Do Not Disturb" of menu 1 of menu bar item "Control Center" of menu bar 1
                        return true
                    on error
                        return false
                    end try
                end tell
            else
                return false
            end if
        end tell
        """
        return runAppleScript(script)
    }

    @discardableResult
    private static func tryControlCenter() -> Bool {
        let script = """
        tell application "System Events"
            if exists process "ControlCenter" then
                tell process "ControlCenter"
                    click menu bar item "Control Center" of menu bar 1
                    delay 0.4
                    try
                        click menu item "Do Not Disturb" of menu 1 of menu bar item "Control Center" of menu bar 1
                        return true
                    on error
                        return false
                    end try
                end tell
            else
                return false
            end if
        end tell
        """
        return runAppleScript(script)
    }

    @discardableResult
    private static func runAppleScript(_ source: String) -> Bool {
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            print("AppleScript error:", error)
            return false
        }
        return result.booleanValue
    }
}
