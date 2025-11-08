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

final class ShellModel: ObservableObject {
    // State + Events
    private let eventBus = EventBus()
    private var ignoreNextDispatcherMode = false
    let context = ModuleContext()
    private lazy var registry = ModuleRegistry(context: context)
    private lazy var dispatcher = SearchDispatcher(registry: registry)
    private lazy var clipboardHotkeyManager = ClipboardHotkeyManager(context: context)
    private var bag = Set<AnyCancellable>()

    private var state = AppState()
    internal var window: WindowManager?

    // Публичные observable-свойства
    @Published var query: String = ""
    @Published var selectedIndex: Int = 0
    @Published private(set) var results: [ResultItem] = []
    @Published var isActionsMenuOpen: Bool = false // открыто/закрыто actions menu
    @Published var showCreateTaskView: Bool = false
    private var allResults: [ResultItem] = []

    // Совместимость с текущим UI
    var filteredItems: [ResultItem] { results }

    init() {
        // Регистрация минимальных модулей (моки — чтобы было что показывать)
        registry.register(LauncherModule())
        registry.register(ClipboardModule())
        registry.register(TasksModule())
        registry.register(PomodoroModule())
        registry.setShellModel(self)

        // Подписки
        dispatcher.resultsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                guard let self = self else { return }
                let sortedItems = self.sortResults(in: items, where: ClipboardItem.self, using: clipboardSortRule) // для пинов
                self.allResults = sortedItems
                self.results = sortedItems
                self.eventBus.post(.resultsUpdated(items.count))
                self.resetSelection()
            }
            .store(in: &bag)

        dispatcher.modePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                guard let self = self else { return }
                if self.ignoreNextDispatcherMode {
                    L.search.info("Ignored dispatcher mode '\(mode.rawValue)' because switchMode was explicit.")
                    self.ignoreNextDispatcherMode = false
                    return
                }
                L.search.info("dispatcher requested mode -> \(mode.rawValue)")
                self.state.mode = mode
                self.eventBus.post(.modeSwitched(mode))
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
            if currentMode != .launcher {
                switchMode(.launcher)
            } else {
                window?.hide()
            }
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
        ignoreNextDispatcherMode = true
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

        if alternative, let s = item.secondaryAction {
            s.run()
        } else {
            item.primaryAction.run()
        }

        let module = registry.module(for: state.mode)
        let modifiers: EventModifiers = alternative ? .shift : []
        let outcome = module?.execute(item: item, modifiers: modifiers) ?? .done

        switch outcome {
        case .clearQuery:
            query = ""
            performSearch()
            resetSelection()
        case .closeWindow:
            break
        case .done, .showError:
            break
        }

        state.history.insert(query, at: 0)
        eventBus.post(.itemExecuted(item))
    }

    func paste(number: Int = 0) {
        if let item = context.clipboardRepository.getByOrder(number) {
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

        allResults = allResults.map { result in
            guard var source = result.source as? ClipboardItem else { return result }
            if source.id == item.id {
                var updated = result
                source.pinned = Int(clipboardHotkeyManager.maxPinned)
                updated.source = source
                return updated
            } else {
                return result
            }
        }

        allResults = sortResults(in: allResults, where: ClipboardItem.self, using: clipboardSortRule)
        results = allResults
    }

    func unpin(item: ClipboardItem) {
        clipboardHotkeyManager.unpin(item: item)

        allResults = allResults.map { result in
            guard var source = result.source as? ClipboardItem else { return result }
            if source.id == item.id {
                var updated = result
                source.pinned = nil // unpin
                updated.source = source
                return updated
            } else {
                return result
            }
        }

        allResults = sortResults(in: allResults, where: ClipboardItem.self, using: clipboardSortRule)
        results = allResults
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
        context.clipboardRepository.deleteAll()
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

    private func sortResults<T>(
        in results: [ResultItem],
        where type: T.Type,
        using rule: (T, T) -> Bool
    ) -> [ResultItem] {
        var typedItems: [ResultItem] = []
        var indices: [Int] = []

        for (index, item) in results.enumerated() {
            if item.source is T {
                typedItems.append(item)
                indices.append(index)
            }
        }

        let sorted = typedItems.sorted {
            guard let a = $0.source as? T, let b = $1.source as? T else { return false }
            return rule(a, b)
        }

        var updated = results
        for (sortedItem, idx) in zip(sorted, indices) {
            updated[idx] = sortedItem
        }

        return updated
    }


    private func clipboardSortRule(_ lhs: ClipboardItem, _ rhs: ClipboardItem) -> Bool {
        switch (lhs.pinned, rhs.pinned) {
        case let (l?, r?): // оба закреплены
            return l < r
        case (nil, nil): // оба не закреплены
            return lhs.timestamp > rhs.timestamp
        case (_?, nil): // левый закреплён, правый нет
            return true
        case (nil, _?): // левый не закреплён, правый закреплён
            return false
        }
    }
}
