//
//  HotkeyService.swift
//  Orbit
//
//  Created by Tom Tim on 20.10.2025.
//

import Foundation
import Carbon.HIToolbox
internal import os

final class HotkeyService {
    static let shared = HotkeyService()
    
    private var hotKeyRefs: [UInt32: EventHotKeyRef?] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var eventHandlerRef: EventHandlerRef?
    private var nextID: UInt32 = 1
    private var installed = false
    
    private init() {
        installHandlerIfNeeded()
    }
    
    deinit {
        for (_, ref) in hotKeyRefs {
            if let r = ref { UnregisterEventHotKey(r) }
        }
        if let h = eventHandlerRef { RemoveEventHandler(h) }
    }
    
    private func installHandlerIfNeeded() {
        guard !installed else { return }
        var eventSpec = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        
        let callback: EventHandlerUPP = {
            _,
            eventRef,
            userData in
            guard let userData else { return noErr }
            
            let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
            
            var hkID = EventHotKeyID()
            let status = GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hkID
            )
            guard status == noErr else { return noErr }
            
            if service.eventHotKeyPressed(eventRef) {
                L.hotkey.info("Hotkey pressed id=\(hkID.id)")
                service.handlers[hkID.id]?()
            }
            return noErr
        }
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            eventSpec.count,
            &eventSpec,
            selfPtr,
            &eventHandlerRef
        )
        installed = true
    }
    
    private func eventHotKeyPressed(_ event: EventRef?) -> Bool {
        var kind: UInt32 = 0
        if let event {
            kind = GetEventKind(event)
        }
        return kind == UInt32(kEventHotKeyPressed)
    }
    
    @discardableResult
    func register(keyCode: UInt32, carbonModifiers: UInt32, handler: @escaping () -> Void) -> UInt32 {
        installHandlerIfNeeded()
        let id = nextID; nextID += 1
        
        let hotKeyID = EventHotKeyID(
            signature: OSType(UInt32(bigEndian: "HKEY".utf8.reduce(0) { ($0 << 8) | UInt32($1) })),
            id: id
        )
        var hotKeyRef: EventHotKeyRef?
        
        let status = RegisterEventHotKey(
            keyCode,
            carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status == noErr {
            hotKeyRefs[id] = hotKeyRef
            handlers[id] = handler
            L.hotkey.info("Registered hotkey id=\(id), keyCode=\(keyCode), mods=\(carbonModifiers)")
        } else {
            L.hotkey.error("Failed to register hotkey keyCode=\(keyCode), mods=\(carbonModifiers), status=\(status)")
        }
        return id
    }
    
    func unregister(id: UInt32) {
        if let ref = hotKeyRefs[id], let r = ref { UnregisterEventHotKey(r) }
        hotKeyRefs[id] = nil
        handlers[id] = nil
    }
}

enum KeyCode {
    static let v: UInt32 = UInt32(kVK_ANSI_V)      // 9
    static let t: UInt32 = UInt32(kVK_ANSI_T)      
    static let space: UInt32 = UInt32(kVK_Space)   // 49
    static let one: UInt32 = UInt32(kVK_ANSI_1)
    static let two: UInt32 = UInt32(kVK_ANSI_2)
    static let three: UInt32 = UInt32(kVK_ANSI_3)
    static let four: UInt32 = UInt32(kVK_ANSI_4)
    static let five: UInt32 = UInt32(kVK_ANSI_5)
    static let six: UInt32 = UInt32(kVK_ANSI_6)
    static let seven: UInt32 = UInt32(kVK_ANSI_7)
    static let eight: UInt32 = UInt32(kVK_ANSI_8)
    static let nine: UInt32 = UInt32(kVK_ANSI_9)
    static let p: UInt32 = UInt32(kVK_ANSI_P)
    static let x: UInt32 = UInt32(kVK_ANSI_X)
    static let enter: UInt32 = UInt32(kVK_Return)
    static let k: UInt32 = UInt32(kVK_ANSI_K)
    static let s: UInt32 = UInt32(kVK_ANSI_S)
    static let c: UInt32 = UInt32(kVK_ANSI_C)
    static let m: UInt32 = UInt32(kVK_ANSI_M)
}
enum CarbonMods {
    static let cmd: UInt32 = UInt32(cmdKey)
    static let opt: UInt32 = UInt32(optionKey)
    static let shift: UInt32 = UInt32(shiftKey)
    static let control: UInt32 = UInt32(controlKey)
    /// типа cmd и opt нажаты одновременно
    static let cmdOpt: UInt32 = UInt32(cmdKey | optionKey)
    static let cmdShift: UInt32 = UInt32(cmdKey | shiftKey)
    static let controlShift: UInt32 = UInt32(controlKey | shiftKey)
    static let optionControlShift: UInt32 = UInt32(optionKey | controlKey | shiftKey)
}
