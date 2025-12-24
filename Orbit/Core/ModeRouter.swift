//
//  ModeRouter.swift
//  Orbit
//
//  Created by Vladislav Pankratov on 22.10.2025.
//

import Foundation
internal import os

final class ModeRouter {
    func route(_ raw: String, lastMode: AppMode) -> ParsedQuery {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var mode: AppMode = lastMode
        var body = trimmed
        
        if trimmed.hasPrefix(">") {
            mode = .launcher
            body = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
        } else if trimmed.lowercased().hasPrefix("clip") {
            mode = .clipboard
            body = String(trimmed.dropFirst("clip".count)).trimmingCharacters(in: .whitespaces)
        } else if trimmed.lowercased().hasPrefix("task") || trimmed.lowercased().hasPrefix("todo") {
            mode = .tasks
            let cut = trimmed.lowercased().hasPrefix("task") ? "task".count : "todo".count
            body = String(trimmed.dropFirst(cut)).trimmingCharacters(in: .whitespaces)
        } else if trimmed.lowercased().hasPrefix("pomo") {
            mode = .pomodoro
            body = String(trimmed.dropFirst("pomo".count)).trimmingCharacters(in: .whitespaces)
        } else if trimmed.lowercased().hasPrefix("settings") || trimmed.lowercased().hasPrefix("prefs") || trimmed.lowercased().hasPrefix("config") {
            mode = .settings
            let cut = trimmed.lowercased().hasPrefix("settings") ? "settings".count : (trimmed.lowercased().hasPrefix("prefs") ? "prefs".count : "config".count)
            body = String(trimmed.dropFirst(cut)).trimmingCharacters(in: .whitespaces)
        } else if trimmed.isEmpty {
            mode = lastMode == .tasks ? .launcher : lastMode
            body = ""
        }
        
        L.router.info("route(raw='\(trimmed, privacy: .public)') -> mode=\(mode.rawValue, privacy: .public), body='\(body, privacy: .public)'")
        return QueryParser()?.parse(body, mode: mode) ?? ParsedQuery(raw: "", mode: .launcher, text: "", tags: [""], priority: nil, due: nil)
    }
}
