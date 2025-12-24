//
//  SettingsModule.swift
//  Orbit
//
//  Created by Auto on 2025.
//

import Foundation

final class SettingsModule: ModulePlugin {
    let mode: AppMode = .settings
    private var ctx: ModuleContext?
    private var shellModel: ShellModel?
    
    func activate(context: ModuleContext) {
        ctx = context
    }
    
    func deactivate() {
        ctx = nil
        shellModel = nil
    }
    
    func setShellModel(_ model: ShellModel) {
        shellModel = model
    }
    
    func parse(query: ParsedQuery) -> Any? { query.text }
    
    func search(intent: Any, cancellation: @escaping () -> Bool, emit: @escaping ([ResultItem]) -> Void) {
        let items: [ResultItem] = [
            ResultItem(
                title: "Screenshot Settings",
                subtitle: "Configure screenshot area, DeepSeek API, and Telegram",
                accessory: "↩︎",
                primaryAction: {
                    NotificationCenter.default.post(name: .showScreenshotSettings, object: nil)
                }
            ),
            ResultItem(
                title: "Select Screenshot Area",
                subtitle: "Choose area for screenshots (⌘⌥S)",
                accessory: "⌘⌥S",
                primaryAction: {
                    ScreenshotManager.shared.selectArea()
                }
            ),
        ]
        
        emit(items)
    }
    
    func execute(item: ResultItem, modifiers: EventModifiers) -> Outcome {
        item.primaryAction.run()
        return .done
    }
    
    func backgroundTick() {}
}


