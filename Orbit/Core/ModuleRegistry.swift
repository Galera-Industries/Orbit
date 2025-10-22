//
//  ModuleRegistry.swift
//  Orbit
//
//  Created by Vladislav Pankratov on 22.10.2025.
//

import Foundation

final class ModuleRegistry {
    private var modules: [AppMode: ModulePlugin] = [:]
    private var context = ModuleContext()
    
    func register(_ module: ModulePlugin) {
        modules[module.mode] = module
        module.activate(context: context)
    }
    
    func module(for mode: AppMode) -> ModulePlugin? {
        modules[mode]
    }
    
    func deactivateAll() {
        modules.values.forEach { $0.deactivate() }
    }
}
