//
//  ModuleRegistry.swift
//  Orbit
//
//  Created by Vladislav Pankratov on 22.10.2025.
//

import Foundation

final class ModuleRegistry {
    private var modules: [AppMode: ModulePlugin] = [:]
    private let context: ModuleContext
    private weak var shellModel: ShellModel?
    
    init(context: ModuleContext) {
        self.context = context
    }
    
    func register(_ module: ModulePlugin) {
        modules[module.mode] = module
        module.activate(context: context)
        if let shell = shellModel {
            module.setShellModel(shell)
        }
    }
    
    func module(for mode: AppMode) -> ModulePlugin? {
        modules[mode]
    }
    
    func deactivateAll() {
        modules.values.forEach { $0.deactivate() }
    }
    
    func setShellModel(_ shell: ShellModel) {
        self.shellModel = shell
        for module in modules.values {
            module.setShellModel(shell)
        }
    }
}
