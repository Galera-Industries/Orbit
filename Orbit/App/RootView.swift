//
//  RootView.swift
//  Orbit
//
//  Created by Tom Tim on 20.10.2025.
//

import SwiftUI
import AppKit
import Combine
internal import os

struct RootView: View {
    @EnvironmentObject var shell: ShellModel
    @EnvironmentObject var windowManager: WindowManager
    @FocusState private var isSearchFocused: Bool
    @State private var keyMonitor: KeyEventMonitor?
    @State private var selectedFilter: Filter = .all // текущий фильтр в clipboard history
    @State private var ids: [UInt32] = [] // нужно для удержания id локального hotkey
    @State private var showCreateTaskView = false
    @State private var showPomodoroView = false
    @State private var selectedPomodoroTask: Task?
    @State private var showStatsView = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
            GlassPanel {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        TextField("Type to search…", text: $shell.query, onCommit: {
                            shell.executeSelected()
                        })
                        .textFieldStyle(.plain)
                        .font(.system(size: 18, weight: .medium))
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.08)))
                        .focused($isSearchFocused)
                        
                        if shell.currentMode == .clipboard {
                            FilterMenu(selection: $selectedFilter)
                                .onChange(of: selectedFilter) { newFilter in
                                    shell.switchFilter(filter: newFilter)
                                }
                        }
                    }
                    .onChange(of: shell.query) { newQ in
                        L.search.info("query changed -> '\(newQ, privacy: .public)'")
                        
                        shell.resetSelection()
                        shell.performSearch()
                    }
                    
                    PreviewHStack()
                    
                    Spacer(minLength: 40)
                }
                .padding(16)
                .frame(minWidth: 720, minHeight: 420)
            }
            BottomPanel()
        }
        .onAppear {
            isSearchFocused = true
            keyMonitor = KeyEventMonitor { event in
                switch event.keyCode {
                case 126: shell.moveSelection(-1); return nil
                case 125: shell.moveSelection(1); return nil
                case 36, 76:
                    let alt = event.modifierFlags.contains(.shift)
                    shell.executeSelected(alternative: alt); return nil
                case 53: shell.handleEscape(); return nil
                default: return event
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSearchField)) { _ in
            L.window.info("focusSearchField notification")
            isSearchFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showPomodoroForTask)) { note in
            if let task = note.object as? Task {
                selectedPomodoroTask = task
                showPomodoroView = true
            }
        }
        .sheet(isPresented: $showPomodoroView) {
            if let task = selectedPomodoroTask {
                PomodoroTaskView(task: task, onBack: {
                    showPomodoroView = false
                    selectedPomodoroTask = nil
                })
            }
        }
        .onDisappear {
            keyMonitor = nil
            unregisterHotkeys()
        }
        .onChange(of: shell.currentMode) { _ in
            updateHotkeys()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showCreateTaskView)) { _ in
            showCreateTaskView = true
        }
        .sheet(isPresented: $showCreateTaskView) {
            CreateTaskView()
                .environmentObject(shell.context)
                .presentationBackground(.ultraThinMaterial)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showStatsView)) { _ in
            showStatsView = true
        }
        .sheet(isPresented: $showStatsView) {
            PomodoroStatsView(onClose: {
                showStatsView = false
            })
        }
    }
    
    private func updateHotkeys() {
        unregisterHotkeys()
        if shell.currentMode == .clipboard {
            ids = HotkeyBootstrap.registerClipboardHotkeys(shell: shell)
        }
    }
    
    private func unregisterHotkeys() {
        for id in ids {
            HotkeyService.shared.unregister(id: id)
        }
        ids.removeAll()
    }
}

struct PreviewHStack: View {
    @EnvironmentObject var shell: ShellModel
    
    var body: some View {
        HStack(spacing: 12) {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(shell.filteredItems.enumerated()), id: \.element.id) { index, item in
                        ResultRow(item: item, isSelected: index == shell.selectedIndex)
                            .onHover { hovering in if hovering { shell.selectedIndex = index } }
                            .onTapGesture { shell.selectedIndex = index; shell.executeSelected() }
                    }
                }
                .padding(6)
            }
            .scrollIndicators(.never)
            .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.06)))
            .frame(width: 320)
            
            if shell.query.isEmpty {
                // Список задач показываем только когда нет query
                TasksListView(context: shell.context)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                if let selectedItem = shell.selectedItem,
                   let clipItem = selectedItem.source as? ClipboardItem {
                    ClipboardPreviewView(item: clipItem)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}

struct TasksListView: View {
    @ObservedObject var context: ModuleContext
    @ObservedObject private var timer = TaskDeletionTimer.shared
    @State private var tasks: [Task] = []
    @State private var activePomodoroTask: Task? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Tasks")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("\(tasks.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.black.opacity(0.05))
                    )
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider()
            
            if let active = activePomodoroTask {
                PomodoroTaskView(task: active, onBack: {
                    activePomodoroTask = nil
                })
            } else {
                if tasks.isEmpty {
                    VStack(spacing: 8) {
                        Text("No tasks")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text("Create your first task using 'task <name> #tag !priority @due_date'")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(tasks) { task in
                                TaskRowView(task: task, context: context, onPomodoroStart: {
                                    activePomodoroTask = task
                                })
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .scrollIndicators(.never)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.06)))
        .onAppear {
            loadTasks()
        }
        .onReceive(NotificationCenter.default.publisher(for: .taskListChanged)) { _ in
            loadTasks()
        }
        .onReceive(timer.$activeTimers) { _ in
            loadTasks()
        }
    }
    
    private func loadTasks() {
        context.tasksRepository.load()
        var upcomingTasks = context.tasksRepository.getUpcomingSorted()
        
        let allTasks = context.tasksRepository.getAll()
        let timer = TaskDeletionTimer.shared
        for task in allTasks {
            if task.completed && timer.isTimerActive(for: task.id) {
                if !upcomingTasks.contains(where: { $0.id == task.id }) {
                    upcomingTasks.append(task)
                }
            }
        }
        
        tasks = upcomingTasks
    }
}

struct TaskRowView: View {
    let task: Task
    let context: ModuleContext
    var onPomodoroStart: (() -> Void)? = nil
    @ObservedObject private var timer = TaskDeletionTimer.shared
    @ObservedObject private var pomodoro = PomodoroManager.shared
    @State private var isHovered = false
    @State private var showPomodoro = false
    
    private var isTimerActive: Bool {
        timer.isTimerActive(for: task.id)
    }
    
    private var remainingSeconds: Int? {
        timer.remainingTime(for: task.id)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: {
                if isTimerActive {
                    timer.cancelTimer(for: task.id)
                    var updatedTask = task
                    updatedTask.completed = false
                    context.tasksRepository.update(updatedTask)
                    NotificationCenter.default.post(name: .taskListChanged, object: nil)
                } else if !task.completed {
                    var updatedTask = task
                    updatedTask.completed = true
                    context.tasksRepository.update(updatedTask)
                    
                    timer.startTimer(for: task.id) {
                        context.tasksRepository.delete(task)
                        NotificationCenter.default.post(name: .taskListChanged, object: nil)
                    }
                    
                    NotificationCenter.default.post(name: .taskListChanged, object: nil)
                } else {
                    var updatedTask = task
                    updatedTask.completed = false
                    context.tasksRepository.update(updatedTask)
                    NotificationCenter.default.post(name: .taskListChanged, object: nil)
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: (task.completed || isTimerActive) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor((task.completed || isTimerActive) ? .green : .secondary)
                        .font(.system(size: 16))
                    
                    if isTimerActive, let seconds = remainingSeconds {
                        Text("\(seconds)s")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.green)
                    }
                }
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 14, weight: (task.completed || isTimerActive) ? .regular : .medium))
                    .strikethrough(task.completed || isTimerActive)
                    .foregroundColor((task.completed || isTimerActive) ? .secondary : .primary)
                    .lineLimit(2)
                
                HStack(spacing: 6) {
                    // Приоритет
                    if let priority = task.priority {
                        let (emoji, color) = priorityInfo(priority)
                        HStack(spacing: 2) {
                            Text(emoji)
                                .font(.system(size: 10))
                            Text(priorityString(priority))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(color)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(color.opacity(0.15))
                        )
                    }
                    
                    // Теги
                    if !task.tags.isEmpty {
                        ForEach(task.tags.prefix(2), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.blue.opacity(0.15))
                                )
                        }
                    }
                    
                    // Дедлайн
                    if let dueDate = task.dueDate {
                        Text(formatDueDate(dueDate))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(dueDate < Date() ? .red : .orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill((dueDate < Date() ? Color.red : Color.orange).opacity(0.15))
                            )
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                pomodoro.start(for: task)
                onPomodoroStart?()
            }) {
                Image(systemName: "timer")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
                    .opacity(isHovered ? 1.0 : 0.7)
            }
            .buttonStyle(.plain)
            
            
            Button(action: {
                deleteTask()
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .opacity(isHovered ? 1.0 : 0.5)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.black.opacity(0.05) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func deleteTask() {
        if task.completed {
            // Если задача выполнена, то удаляем сразу без подтверждения
            timer.cancelTimer(for: task.id)
            context.tasksRepository.delete(task)
            NotificationCenter.default.post(name: .taskListChanged, object: nil)
        } else {
            // Если задача не выполнена, то показываем подтверждение
            showDeleteConfirmation()
        }
    }
    
    private func showDeleteConfirmation() {
        let alert = NSAlert()
        alert.messageText = "Delete Task"
        alert.informativeText = "Are you sure you want to delete \"\(task.title)\"? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        if let deleteButton = alert.buttons.first {
            deleteButton.hasDestructiveAction = true
        }
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            timer.cancelTimer(for: task.id)
            context.tasksRepository.delete(task)
            NotificationCenter.default.post(name: .taskListChanged, object: nil)
        }
    }
    
    private func priorityInfo(_ priority: TaskPriority) -> (String, Color) {
        switch priority {
        case .high: return ("🔴", .red)
        case .medium: return ("🟡", .orange)
        case .low: return ("🟢", .green)
        }
    }
    
    private func priorityString(_ priority: TaskPriority) -> String {
        switch priority {
        case .high: return "High"
        case .medium: return "Med"
        case .low: return "Low"
        }
    }
    
    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if date < now {
            let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

struct BottomPanel: View {
    @EnvironmentObject private var shell: ShellModel
    @State private var hoverOnActions = false
    @State private var isOpen = false
    
    private func getActions() -> [Action] {
        switch shell.currentMode {
        case .launcher:
            return [.deleteAll]
        case .clipboard:
            return [.pin, .deleteThis, .deleteAll]
        case .tasks:
            return []
        case .pomodoro:
            return []
        }
    }
    
    var body: some View {
        HStack {
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    shell.isActionsMenuOpen.toggle()
                }
            }) {
                ButtonLabel(hoverOnActions: $hoverOnActions)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $shell.isActionsMenuOpen, attachmentAnchor: .point(.topLeading), arrowEdge: .top) {
                ActionsListView(actions: getActions()) {
                    shell.isActionsMenuOpen = false
                }
                .frame(maxWidth: 260, maxHeight: 200)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.08))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        .padding(.bottom, 0)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.easeInOut(duration: 0.25), value: hoverOnActions)
    }
}

struct ButtonLabel: View {
    @Binding var hoverOnActions: Bool
    var body: some View {
        HStack(spacing: 4) {
            Key(key: "⌘")
            Key(key: "K")
            Text("Actions")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.white.opacity(0.06))
        )
        .onHover { inside in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoverOnActions = inside
            }
        }
        .opacity(hoverOnActions ? 0.95 : 0.8)
        .scaleEffect(hoverOnActions ? 1.02 : 1.0)
    }
}

extension ShellModel {
    var selectedItem: ResultItem? {
        guard selectedIndex >= 0 && selectedIndex < filteredItems.count else { return nil }
        return filteredItems[selectedIndex]
    }
}

extension Notification.Name {
    static let showPomodoroForTask = Notification.Name("showPomodoroForTask")
}

extension Notification.Name {
    static let showStatsView = Notification.Name("showStatsView")
}
