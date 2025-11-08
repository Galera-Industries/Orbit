//
//  CalendarService.swift
//  Orbit
//
//  Created by Auto on 2025.
//

import Foundation
import EventKit
import Combine

final class CalendarService {
    static let shared = CalendarService()
    
    private let eventStore = EKEventStore()
    private var authorizationStatus: EKAuthorizationStatus = .notDetermined
    
    private init() {}
    
    // Запрашивает разрешение на доступ к календарю
    func requestAccess() async -> Bool {
        do {
            let status = try await eventStore.requestAccess(to: .event)
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            return status
        } catch {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            return false
        }
    }
    
    // Создает событие в календаре для задачи
    func createEvent(for task: Task) async throws -> String? {
        // Запрашиваем доступ, если еще не получен
        if authorizationStatus != .authorized {
            let granted = await requestAccess()
            if !granted {
                throw CalendarError.accessDenied
            }
        }
        
        // Получаем календарь по умолчанию или создаем новый
        guard let calendar = getDefaultCalendar() else {
            throw CalendarError.calendarNotFound
        }
        
        // Создаем событие
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = formatEventTitle(for: task)
        event.notes = formatEventNotes(for: task)
        
        // Устанавливаем дату начала и окончания
        if let dueDate = task.dueDate {
            // Если есть дедлайн, создаем событие на весь день
            let calendar = Calendar.current
            let startDate = calendar.startOfDay(for: dueDate)
            event.startDate = startDate
            event.endDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
            event.isAllDay = true
        } else {
            // Если нет дедлайна, создаем событие на сегодня
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            event.startDate = today
            event.endDate = calendar.date(byAdding: .day, value: 1, to: today) ?? today
            event.isAllDay = true
        }
        
        // Устанавливаем приоритет (в EventKit нет прямого приоритета, используем notes)
        // Сохраняем eventIdentifier для последующего удаления/обновления
        do {
            try eventStore.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            throw CalendarError.saveFailed(error)
        }
    }
    
    // Обновляет событие в календаре
    func updateEvent(eventIdentifier: String, for task: Task) async throws -> String {
        if authorizationStatus != .authorized {
            let granted = await requestAccess()
            if !granted {
                throw CalendarError.accessDenied
            }
        }
        
        guard let event = eventStore.event(withIdentifier: eventIdentifier) else {
            // Если событие не найдено, создаем новое
            if let newIdentifier = try await createEvent(for: task) {
                return newIdentifier
            }
            throw CalendarError.saveFailed(NSError(domain: "CalendarService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create new event"]))
        }
        
        event.title = formatEventTitle(for: task)
        event.notes = formatEventNotes(for: task)
        
        if let dueDate = task.dueDate {
            let calendar = Calendar.current
            let startDate = calendar.startOfDay(for: dueDate)
            event.startDate = startDate
            event.endDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
            event.isAllDay = true
        } else {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            event.startDate = today
            event.endDate = calendar.date(byAdding: .day, value: 1, to: today) ?? today
            event.isAllDay = true
        }
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return eventIdentifier
        } catch {
            throw CalendarError.saveFailed(error)
        }
    }
    
    // Удаляет событие из календаря
    func deleteEvent(eventIdentifier: String) async throws {
        if authorizationStatus != .authorized {
            let granted = await requestAccess()
            if !granted {
                throw CalendarError.accessDenied
            }
        }
        
        guard let event = eventStore.event(withIdentifier: eventIdentifier) else {
            // Событие уже удалено или не существует
            return
        }
        
        do {
            try eventStore.remove(event, span: .thisEvent)
        } catch {
            throw CalendarError.deleteFailed(error)
        }
    }
    
    // Получает календарь по умолчанию
    private func getDefaultCalendar() -> EKCalendar? {
        // Пытаемся найти календарь "Orbit" или используем календарь по умолчанию
        let calendars = eventStore.calendars(for: .event)
        
        // Ищем календарь "Orbit"
        if let orbitCalendar = calendars.first(where: { $0.title == "Orbit" }) {
            return orbitCalendar
        }
        
        // Используем календарь по умолчанию
        return eventStore.defaultCalendarForNewEvents
    }
    
    // Форматирует заголовок события
    private func formatEventTitle(for task: Task) -> String {
        var title = task.title
        
        // Добавляем приоритет в заголовок
        if let priority = task.priority {
            let priorityEmoji: String
            switch priority {
            case .high: priorityEmoji = "🔴"
            case .medium: priorityEmoji = "🟡"
            case .low: priorityEmoji = "🟢"
            }
            title = "\(priorityEmoji) \(title)"
        }
        
        return title
    }
    
    // Форматирует заметки события (теги и другая информация)
    private func formatEventNotes(for task: Task) -> String {
        var notes: [String] = []
        
        // Добавляем теги
        if !task.tags.isEmpty {
            let tagsString = task.tags.map { "#\($0)" }.joined(separator: " ")
            notes.append("Tags: \(tagsString)")
        }
        
        // Добавляем приоритет текстом
        if let priority = task.priority {
            let priorityString: String
            switch priority {
            case .high: priorityString = "High"
            case .medium: priorityString = "Medium"
            case .low: priorityString = "Low"
            }
            notes.append("Priority: \(priorityString)")
        }
        
        return notes.joined(separator: "\n")
    }
}

enum CalendarError: Error {
    case accessDenied
    case calendarNotFound
    case saveFailed(Error)
    case deleteFailed(Error)
    
    var localizedDescription: String {
        switch self {
        case .accessDenied:
            return "Access to calendar was denied"
        case .calendarNotFound:
            return "Calendar not found"
        case .saveFailed(let error):
            return "Failed to save event: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete event: \(error.localizedDescription)"
        }
    }
}

