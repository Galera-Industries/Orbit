//
//  Contracts.swift
//  Orbit
//
//  Created by Vladislav Pankratov on 22.10.2025.
//

import Foundation
import SwiftUI

// MARK: - Режимы
enum AppMode: String, CaseIterable {
    case launcher
    case clipboard
    case tasks
    case pomodoro
}

// MARK: - Приоритет/Дедлайн для задач (пример парсинга токенов)
enum TaskPriority: Int {
    case low = 0, medium = 1, high = 2
}

enum DueToken: Equatable {
    case today
    case tomorrow
    case nextWeek
    case date(Date)
}

// MARK: - Разобранный запрос
struct ParsedQuery {
    let raw: String
    let mode: AppMode
    let text: String               // запрос без префикса и токенов
    let tags: [String]             // #tag
    let priority: TaskPriority?    // !high/!2 и т.п.
    let due: DueToken?             // @today/@2025-10-21
}

// MARK: - Действия для карточки
struct ItemAction {
    let run: () -> Void
}

// MARK: - Результат выполнения
enum Outcome {
    case done
    case closeWindow
    case showError(String)
}

// MARK: - Элемент результата
struct ResultItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let icon: String?          // SFSymbol name (опционально)
    let accessory: String?     // бейдж справа (например хоткей)
    let primaryAction: ItemAction
    let secondaryAction: ItemAction?
    
    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        accessory: String? = nil,
        primaryAction: @escaping () -> Void,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.accessory = accessory
        self.primaryAction = .init(run: primaryAction)
        if let s = secondaryAction { self.secondaryAction = .init(run: s) } else { self.secondaryAction = nil }
    }
}

struct ClipboardItem: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let type: ClipboardType
    let content: Data
}

enum ClipboardType: String {
    case text
    case image
    case fileURL
}

// MARK: - Контекст для модулей (минимум)
struct ModuleContext {
    // сюда можно добавлять зависимости: WindowManager, EventBus, сервисы
}

// MARK: - Протокол плагина (модуля)
protocol ModulePlugin {
    var mode: AppMode { get }
    func activate(context: ModuleContext)
    func deactivate()
    
    /// Верните nil если запрос не ваш, иначе intent — произвольная структура или просто "эхо"
    func parse(query: ParsedQuery) -> Any?
    
    /// Поиск — синхронный или быстрый. Для асинхронных источников можно вызывать completion несколько раз.
    func search(intent: Any, cancellation: @escaping () -> Bool, emit: @escaping ([ResultItem]) -> Void)
    
    /// Выполнение одного из ResultItem — обычно кликом/Enter
    func execute(item: ResultItem, modifiers: EventModifiers) -> Outcome
    
    /// Периодическая подкачка данных/очистка кеша (опционально)
    func backgroundTick()
}

// Для модификаторов (Shift и т.п.)
struct EventModifiers: OptionSet {
    let rawValue: Int
    static let shift = EventModifiers(rawValue: 1 << 0)
}
