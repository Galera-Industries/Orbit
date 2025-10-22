//
//  WindowAccessor.swift
//  Orbit
//
//  Created by Tom Tim on 20.10.2025.
//

import SwiftUI
import AppKit

struct WindowAccessor: NSViewRepresentable {
    let configure: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                configure(window)
            }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
