//
//  Contracts.swift
//  Orbit
//
//  Created by Vladislav Pankratov on 22.10.2025.
//

import Foundation
import SwiftUI
import Combine

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
    case clearQuery
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
    
    var source: Any? // поле для данных
    
    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        accessory: String? = nil,
        primaryAction: @escaping () -> Void,
        secondaryAction: (() -> Void)? = nil,
        source: Any? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.accessory = accessory
        self.primaryAction = .init(run: primaryAction)
        if let s = secondaryAction { self.secondaryAction = .init(run: s) } else { self.secondaryAction = nil }
        self.source = source
    }
}

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let type: ClipboardType
    let content: Data
    var pinned: Int? // от 1 до 100, место на котором запинено
    var bundleID: String? // приложение откуда скопировали
    var appName: String? // имя приложения
    var appIcon: Data? // картинка
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: ClipboardType,
        content: Data,
        pinned: Int? = nil,
        bundleID: String? = nil,
        appName: String? = nil,
        appIcon: Data? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.content = content
        self.pinned = pinned
        self.bundleID = bundleID
        self.appName = appName
        self.appIcon = appIcon
    }
    
    var displayText: String {
        switch type {
        case .text:
            return String(data: content, encoding: .utf8) ?? ""
        case .image:
            return "Image"
        case .fileURL:
            guard
                let paths = try? JSONDecoder().decode([String].self, from: content),
                !paths.isEmpty
            else {
                return "File"
            }
            let filenames = paths.map { URL(fileURLWithPath: $0).lastPathComponent }
            if filenames.count == 1 {
                return filenames[0]
            } else {
                return filenames.joined(separator: ", ")
            }
        }
    }
}

enum ClipboardType: String, Codable {
    case text = "text"
    case image = "image"
    case fileURL = "fileURL"
}

// MARK: - Task Model
struct Task: Identifiable, Equatable {
    let id: UUID
    var title: String
    let createdAt: Date
    var tags: [String]
    var priority: TaskPriority?
    var dueDate: Date?
    var completed: Bool
    
    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        tags: [String] = [],
        priority: TaskPriority? = nil,
        dueDate: Date? = nil,
        completed: Bool = false
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.tags = tags
        self.priority = priority
        self.dueDate = dueDate
        self.completed = completed
    }
    
    static func from(parsedQuery: ParsedQuery) -> Task {
        var dueDate: Date?
        
        if let dueToken = parsedQuery.due {
            let calendar = Calendar.current
            switch dueToken {
            case .today:
                dueDate = calendar.startOfDay(for: Date())
            case .tomorrow:
                dueDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))
            case .nextWeek:
                dueDate = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: Date()))
            case .date(let date):
                dueDate = calendar.startOfDay(for: date)
            }
        }
        
        return Task(
            title: parsedQuery.text.isEmpty ? "Untitled Task" : parsedQuery.text,
            tags: parsedQuery.tags,
            priority: parsedQuery.priority,
            dueDate: dueDate
        )
    }
}

// MARK: - Контекст для модулей (минимум)
final class ModuleContext: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    
    var clipboardMonitor: ClipboardMonitorProtocol = ClipboardMonitor() // var из-за того что внутри есть поле-колбек, которому нужно будет присвоить значение
    let coreData: CoreDataProtocol = CoreDataManager()
    lazy var clipboardRepository: ClipboardRepositoryProtocol = ClipboardRepository(coreData: coreData)
    lazy var tasksRepository: TasksRepositoryProtocol = TasksRepository(coreData: coreData)
    lazy var clipboardHotkeyManager: ClipboardHotkeyManager = ClipboardHotkeyManager(context: self)
    let tracker: FrontAppTracker = FrontAppTracker()
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
    
    func setShellModel(_ model: ShellModel)
}

extension ModulePlugin {
    func setShellModel(_ model: ShellModel) { /* noop */ }
}

// Для модификаторов (Shift и т.п.)
struct EventModifiers: OptionSet {
    let rawValue: Int
    static let shift = EventModifiers(rawValue: 1 << 0)
}
// для фильтра по копированиям
enum Filter: String, CaseIterable, Hashable {
    case all = "all", text = "text", images = "image", files = "fileURL"
    
    var title: String {
        switch self {
        case .all: "All Types"
        case .text: "Text Only"
        case .images: "Images Only"
        case .files: "Files Only"
        }
    }
    
    var icon: String {
        switch self {
        case .all: "tray.full"
        case .text: "text.alignleft"
        case .images: "photo"
        case .files: "doc"
        }
    }
}

// для опций доступных по кнопке Actions
enum Action: String, CaseIterable, Hashable {
    case copyToClipboard = "copyToClipboard"
    case pin = "pin"
    case unpin = "unpin"
    case deleteThis = "deleteThis"
    case deleteAll  = "deleteAll"
    
    var title: String {
        switch self {
        case .copyToClipboard: "Copy To Clipboard"
        case .pin: "Pin Entry"
        case .unpin: "Unpin Entry"
        case .deleteThis: "Delete This Entry"
        case .deleteAll: "Delete All Entries"
        }
    }
    
    var icon: String {
        switch self {
        case .copyToClipboard: "list.clipboard.fill"
        case .pin: "pin.fill"
        case .unpin: "pin.slash.fill"
        case .deleteThis: "trash.fill"
        case .deleteAll: "trash.fill"
        }
    }
}

struct FileURLPayload: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.url)
    }
}
