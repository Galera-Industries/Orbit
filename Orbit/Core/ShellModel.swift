//
//  ShellModel.swift
//  Orbit
//
//  Created by Tom Tim on 20.10.2025.
//

import Foundation
import Combine
import AppKit
import Carbon
internal import os

// ResultItem переехал в Contracts.swift

final class ShellModel: ObservableObject {
    // State + Events
    private let eventBus = EventBus()
    private let registry = ModuleRegistry()
    private lazy var dispatcher = SearchDispatcher(registry: registry)
    private lazy var clipboardHotkeyManager = ClipboardHotkeyManager(clipboardRepository: registry.context.clipboardRepository)
    private var bag = Set<AnyCancellable>()
    
    private var state = AppState()
    
    // Публичные observable-свойства
    @Published var query: String = ""
    @Published var selectedIndex: Int = 0
    @Published private(set) var results: [ResultItem] = []
    @Published var isActionsMenuOpen: Bool = false // открыто/закрыто actions menu
    private var allResults: [ResultItem] = []
    
    // Совместимость с текущим UI
    var filteredItems: [ResultItem] { results }
    var sortedItems: [ClipboardItem] {
        filteredItems
            .compactMap {$0.source as? ClipboardItem}
            .sorted {
            switch ($0.pinned, $1.pinned) {
            case let (p1?, p2?): return p1 < p2 // оба закреплены -> сортируем по приоритету
            case (nil, nil): return false // оба не закреплены -> порядок не меняем
            case (nil, _?): return false // незакреплённые идут ниже
            case (_?, nil): return true // закреплённые выше
            }
        }
    }
    
    init() {
        // Регистрация минимальных модулей (моки — чтобы было что показывать)
        registry.register(LauncherModule())
        registry.register(ClipboardModule())
        registry.register(TasksModule())
        registry.register(PomodoroModule())
        
        // Подписки
        dispatcher.resultsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.allResults = items
                self?.results = items
                self?.eventBus.post(.resultsUpdated(items.count))
                self?.resetSelection()
            }
            .store(in: &bag)
        
        dispatcher.modePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.state.mode = mode
                self?.eventBus.post(.modeSwitched(mode))
            }
            .store(in: &bag)
        
        // Запуск начального поиска
        performSearch()
    }
    
    // Навигация
    func moveSelection(_ delta: Int) {
        let count = filteredItems.count
        guard count > 0 else { selectedIndex = 0; return }
        selectedIndex = (selectedIndex + delta + count) % count
    }
    func resetSelection() { selectedIndex = 0 }
    
    
    func handleEscape() {
        if query.isEmpty {
            return
        } else {
            query = ""
            performSearch()
            resetSelection()
        }
    }
    
    // Поиск (debounce/отмена старых)
    private var queryDebounceCancellable: AnyCancellable?
    
    func bindQuery(_ publisher: AnyPublisher<String, Never>) {
        queryDebounceCancellable = publisher
            .removeDuplicates()
            .debounce(for: .milliseconds(120), scheduler: DispatchQueue.main)
            .sink { [weak self] q in
                self?.query = q
                self?.performSearch()
            }
    }
    
    
    // Текущий режим наружу (read-only)
    var currentMode: AppMode { state.mode }
    
    // Принудительное переключение режима (без ввода префикса)
    func switchMode(_ mode: AppMode, prefillQuery: String? = nil) {
        L.search.info("switchMode -> \(mode.rawValue, privacy: .public)")
        state.mode = mode
        if let q = prefillQuery { query = q }
        performSearch()
    }
    
    func performSearch() {
        dispatcher.cancelCurrent()
        L.search.info("performSearch q='\(self.query, privacy: .public)' lastMode=\(self.state.mode.rawValue, privacy: .public)")
        eventBus.post(.queryChanged(query))
        dispatcher.search(query: query, lastMode: state.mode)
    }
    
    func executeSelected(alternative: Bool = false) {
        guard filteredItems.indices.contains(selectedIndex) else { return }
        let item = filteredItems[selectedIndex]
        L.search.info("executeSelected alt=\(alternative) title='\(item.title, privacy: .public)'")
        if alternative, let s = item.secondaryAction { s.run() } else { item.primaryAction.run() }
        state.history.insert(query, at: 0)
        eventBus.post(.itemExecuted(item))
    }
    
    func paste(number: Int = 0) {
        if let item = registry.context.clipboardRepository.getByOrder(number) {
            pasteItem(item)
            pasteSimulation()
        }
    }
    
    func switchFilter(filter: Filter) {
        if filter == .all {
            results = allResults
            return
        }

        results = allResults.filter { item in
            guard let copyItem = item.source as? ClipboardItem else { return false }
            return copyItem.type.rawValue == filter.rawValue
        }
    }
    // Pin - метод который вызывается, когда пользователь жмет Action Pin на экране Clipboard History
    func pin(item: ClipboardItem) {
        clipboardHotkeyManager.pin(item: item)
    }
    
    // DeleteItem - метод который вызывается, когда пользователь жмет Action Delete Entry на экране Clipboard History 
    func deleteItem(item: ClipboardItem) {
        clipboardHotkeyManager.delete(item: item)
        if let index = allResults.firstIndex(where: {$0.source as? ClipboardItem == item }) {
            allResults.remove(at: index)
        }
        results = allResults
    }
    
    // Метод вызывается вне зависимости нажали мы через Action на экране Clipboard History или просто прожали
    func deleteAllFromClipboardHistory() {
        registry.context.clipboardRepository.deleteAll()
        allResults.removeAll(where: {$0.source is ClipboardItem })
        results = allResults
    }
    
    private func pasteItem(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch item.type {
        case .text:
            if let string = String(data: item.content, encoding: .utf8) {
                pasteboard.setString(string, forType: .string)
            }
        case .image:
            pasteboard.setData(item.content, forType: .tiff)
        case .fileURL:
            if let paths = try? JSONDecoder().decode([String].self, from: item.content) {
                let urls = paths.map { NSURL(fileURLWithPath: $0) }
                pasteboard.writeObjects(urls)
            }
        }
    }
    
    private func pasteSimulation() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_Command), keyDown: true)
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let vUp = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_Command), keyDown: false)
        
        cmdDown?.flags = .maskCommand
        vDown?.flags = .maskCommand
        
        let loc = CGEventTapLocation.cghidEventTap

        cmdDown?.post(tap: loc)
        vDown?.post(tap: loc)
        vUp?.post(tap: loc)
        cmdUp?.post(tap: loc)
    }
}
