//
//  AppState.swift
//  Orbit
//
//  Created by Vladislav Pankratov on 22.10.2025.
//

import Foundation

struct UserSettings: Codable, Equatable {
    var openHotkey: String = "cmd+opt+space"
    var quickPasteHotkey: String = "cmd+shift+v"
}

final class AppState {
    var mode: AppMode = .launcher
    var query: String = ""
    var history: [String] = []
    var settings = UserSettings()
}
