//
//  AppCommands.swift
//  Orbit
//
//  Created by Tom Tim on 20.10.2025.
//

import SwiftUI

struct AppCommands: Commands {
    @ObservedObject var shell: ShellModel
    
    var body: some Commands {
        CommandGroup(after: .textEditing) {
            Button("Execute") { shell.executeSelected() }
                .keyboardShortcut(.return, modifiers: [])
            
            Button("Execute Alternative") { shell.executeSelected(alternative: true) }
                .keyboardShortcut(.return, modifiers: [.shift])
            
            Button("Move Up") { shell.moveSelection(-1) }
                .keyboardShortcut(.upArrow, modifiers: [])
            
            Button("Move Down") { shell.moveSelection(1) }
                .keyboardShortcut(.downArrow, modifiers: [])
            
            Button("Clear / Close") { shell.handleEscape() }
                .keyboardShortcut(.escape, modifiers: [])
        }
    }
}
