//
//  ModuleRegistry.swift
//  Orbit
//
//  Created by Vladislav Pankratov on 22.10.2025.
//

import Foundation

final class ModuleRegistry {
    private var modules: [AppMode: ModulePlugin] = [:]
    var context = ModuleContext() // хочу чтобы был доступ на уровне ShellModule
    
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
