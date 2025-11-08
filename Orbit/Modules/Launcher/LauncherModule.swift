//
//  LauncherModule.swift
//  Orbit
//
//  Created by Vladislav Pankratov on 22.10.2025.
//  Updated by ChatGPT 2025-11-08
//

import Foundation
import AppKit

final class LauncherModule: ModulePlugin {
    let mode: AppMode = .launcher
    private var ctx: ModuleContext?
    private var shellModel: ShellModel?
    
    private let spotlightSearcher = SpotlightSearcher()
    private var currentFileSearchToken: UUID?
    private let appIndexer = AppIndexer()
    
    func activate(context: ModuleContext) {
        ctx = context
        appIndexer.buildIndex {
            NotificationCenter.default.post(name: .appIndexReady, object: nil)
        }
    }
    
    func deactivate() {
        ctx = nil
        shellModel = nil
        spotlightSearcher.stop()
    }
    
    func setShellModel(_ model: ShellModel) {
        shellModel = model
    }
    
    func parse(query: ParsedQuery) -> Any? { query.text }
    
    func search(intent: Any, cancellation: @escaping () -> Bool, emit: @escaping ([ResultItem]) -> Void) {
        guard let q = intent as? String else { return }
        if cancellation() { return }
        
        let base: [ResultItem] = [
            .init(title: "Open Clipboard", subtitle: "Switch to clipboard mode", accessory: "↩︎") { [weak self] in
                self?.shellModel?.switchMode(.clipboard)
            },
            .init(title: "Create Task", subtitle: "Create your own tasks", accessory: "↩︎") {
                NotificationCenter.default.post(name: .showCreateTaskView, object: nil)
            },
            .init(title: "Open Tasks", subtitle: "Switch to tasks mode", accessory: "↩︎") { [weak self] in
                self?.shellModel?.switchMode(.tasks)
            },
            .init(title: "Open Pomodoro", subtitle: "Switch to pomodoro mode", accessory: "↩︎") { [weak self] in
                self?.shellModel?.switchMode(.pomodoro)
            }
        ]
        
        let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            emit(base)
            spotlightSearcher.stop()
            currentFileSearchToken = nil
            return
        }
        
        let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
        let webItem = ResultItem(title: "Search web: \"\(q)\"", subtitle: "Search in default browser", accessory: "↩︎") {
            if let url = URL(string: "https://www.google.com/search?q=\(encoded)") {
                NSWorkspace.shared.open(url)
            }
        }
        
        let matchedApps = appIndexer.search(q, limit: 40)
        let appItems = matchedApps.map { app -> ResultItem in
            ResultItem(
                title: app.name,
                subtitle: app.url.path,
                accessory: "↩︎",
                primaryAction: {
                    NSWorkspace.shared.openApplication(at: app.url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
                },
                source: app.url
            )
        }
        
        if cancellation() { return }
        
        emit([webItem] + appItems + base)
        
        spotlightSearcher.stop()
        currentFileSearchToken = nil
        
        guard trimmed.count >= 2 else {
            return
        }
        
        let token = UUID()
        currentFileSearchToken = token
        spotlightSearcher.search(trimmed, limit: 80) { [weak self] urls in
            guard let self = self else { return }
            // игнорировать если между запусками появился новый поиск
            if self.currentFileSearchToken != token { return }
            if cancellation() { return }
            
            let fileItems = urls.map { url -> ResultItem in
                ResultItem(
                    title: url.lastPathComponent,
                    subtitle: url.path,
                    accessory: "↩︎",
                    primaryAction: {
                        NSWorkspace.shared.open(url)
                    },
                    source: url
                )
            }
            
            var results: [ResultItem] = [webItem] + appItems + fileItems + base
            
            var seenPaths = Set<String>()
            results = results.filter { item in
                if let s = item.source as? URL {
                    let p = s.path
                    if seenPaths.contains(p) { return false }
                    seenPaths.insert(p)
                }
                return true
            }
            
            if cancellation() { return }
            emit(results)
        }
    }
    
    func execute(item: ResultItem, modifiers: EventModifiers) -> Outcome { .done }
    func backgroundTick() {}
}

extension Notification.Name {
    static let showCreateTaskView = Notification.Name("ShowCreateTaskView")
    static let startPomodoro = Notification.Name("StartPomodoro")
    static let appIndexReady = Notification.Name("AppIndexReady")
}
