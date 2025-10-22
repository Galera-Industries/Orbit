//
//  EventBus.swift
//  Orbit
//
//  Created by Vladislav Pankratov on 22.10.2025.
//

import Foundation
import Combine

// События ядра
enum AppEvent {
    case queryChanged(String)
    case resultsUpdated(Int)
    case itemExecuted(ResultItem)
    case modeSwitched(AppMode)
    case hotkeyTriggered(String)
}

final class EventBus {
    let events = PassthroughSubject<AppEvent, Never>()
    
    func post(_ e: AppEvent) { events.send(e) }
    
    // удобные паблишеры
    var modePublisher: AnyPublisher<AppMode, Never> {
        events
            .compactMap { e in
                if case let .modeSwitched(m) = e { return m }
                return nil
            }
            .eraseToAnyPublisher()
    }
}
