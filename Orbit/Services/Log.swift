//
//  Log.swift
//  Orbit
//
//  Created by Vladislav Pankratov on 22.10.2025.
//

import OSLog

enum L {
    static let hotkey = Logger(subsystem: "ru.sundayti.orbit", category: "hotkey")
    static let window = Logger(subsystem: "ru.sundayti.orbit", category: "window")
    static let search = Logger(subsystem: "ru.sundayti.orbit", category: "search")
    static let router = Logger(subsystem: "ru.sundayti.orbit", category: "router")
    static let ax = Logger(subsystem: "ru.sundayti.orbit", category: "accessibility")
}
