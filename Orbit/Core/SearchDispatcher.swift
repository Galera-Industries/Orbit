//
//  SearchDispatcher.swift
//  Orbit
//
//  Created by Vladislav Pankratov on 22.10.2025.
//

import Foundation
import Combine

final class SearchDispatcher {
    private let router = ModeRouter()
    private let registry: ModuleRegistry
    private var currentTaskCancelled = false
    
    // Паблишеры
    let resultsPublisher = PassthroughSubject<[ResultItem], Never>()
    let modePublisher = PassthroughSubject<AppMode, Never>()
    let parsedPublisher = PassthroughSubject<ParsedQuery, Never>()
    
    init(registry: ModuleRegistry) {
        self.registry = registry
    }
    
    func cancelCurrent() {
        currentTaskCancelled = true
    }
    
    func search(query raw: String, lastMode: AppMode) {
        currentTaskCancelled = false
        
        let parsed = router.route(raw, lastMode: lastMode)
        parsedPublisher.send(parsed)
        modePublisher.send(parsed.mode)
        
        guard let module = registry.module(for: parsed.mode) else {
            resultsPublisher.send([])
            return
        }
        
        let intent = module.parse(query: parsed) ?? parsed.text
        
        module.search(intent: intent, cancellation: { [weak self] in
            self?.currentTaskCancelled ?? true
        }, emit: { [weak self] items in
            guard let self else { return }
            if !self.currentTaskCancelled {
                self.resultsPublisher.send(items)
            }
        })
    }
}
