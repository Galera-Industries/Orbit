import SwiftUI

struct CreateTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var context: ModuleContext
    
    @State private var title: String = ""
    @State private var selectedPriority: TaskPriority? = nil
    @State private var tags: [String] = []
    @State private var currentTag: String = ""
    @State private var dueDate: Date? = nil
    @State private var showDatePicker: Bool = false
    @State private var selectedDate: Date = Date()
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Create New Task")
                    .font(.system(size: 22, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Название задачи
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Task Title")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextField("Enter task title", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.05)))
                            .onSubmit {
                                if !title.isEmpty {
                                    createTask()
                                }
                            }
                    }
                    
                    // Приоритет
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Priority")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            PriorityButton(
                                title: "High",
                                emoji: "🔴",
                                isSelected: selectedPriority == .high
                            ) {
                                selectedPriority = selectedPriority == .high ? nil : .high
                            }
                            
                            PriorityButton(
                                title: "Medium",
                                emoji: "🟡",
                                isSelected: selectedPriority == .medium
                            ) {
                                selectedPriority = selectedPriority == .medium ? nil : .medium
                            }
                            
                            PriorityButton(
                                title: "Low",
                                emoji: "🟢",
                                isSelected: selectedPriority == .low
                            ) {
                                selectedPriority = selectedPriority == .low ? nil : .low
                            }
                        }
                    }
                    
                    // Теги
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        // Поле ввода тега
                        HStack {
                            TextField("Add tag (press Enter)", text: $currentTag)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14))
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.05)))
                                .onSubmit {
                                    addTag()
                                }
                            
                            Button(action: addTag) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(.plain)
                            .disabled(currentTag.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        
                        // Список добавленных тегов
                        if !tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(tags, id: \.self) { tag in
                                        TagView(tag: tag) {
                                            tags.removeAll { $0 == tag }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    // Дедлайн
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Due Date")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            let isToday = dueDate != nil && Calendar.current.isDateInToday(dueDate!)
                            let isTomorrow = dueDate != nil && Calendar.current.isDateInTomorrow(dueDate!)
                            let isCustomDate = dueDate != nil && !isToday && !isTomorrow
                            
                            Button(action: {
                                dueDate = Calendar.current.startOfDay(for: Date())
                                showDatePicker = false
                            }) {
                                Text("Today")
                                    .font(.system(size: 13))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(RoundedRectangle(cornerRadius: 6)
                                        .fill(isToday ? Color.blue.opacity(0.2) : Color.black.opacity(0.05)))
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())){
                                    dueDate = tomorrow
                                    showDatePicker = false
                                }
                            }) {
                                Text("Tomorrow")
                                    .font(.system(size: 13))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(RoundedRectangle(cornerRadius: 6)
                                        .fill(isTomorrow ? Color.blue.opacity(0.2) : Color.black.opacity(0.05)))
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                showDatePicker.toggle()
                                if showDatePicker && selectedDate == Date() && dueDate == nil {
                                    selectedDate = Date()
                                } else if showDatePicker && dueDate != nil {
                                    if let dueDate = dueDate{
                                        selectedDate = dueDate
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "calendar")
                                    Text(dueDate == nil ? "Select date" : formatDate(dueDate))
                                        .font(.system(size: 13))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 6)
                                    .fill((isCustomDate || showDatePicker) ? Color.blue.opacity(0.2) : Color.black.opacity(0.05)))
                            }
                            .buttonStyle(.plain)
                            
                            if dueDate != nil {
                                Button(action: {
                                    dueDate = nil
                                    showDatePicker = false
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 16))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        if showDatePicker {
                            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .onChange(of: selectedDate) { newDate in
                                    let selectedDay = Calendar.current.startOfDay(for: newDate)
                                    let today = Calendar.current.startOfDay(for: Date())
                                    guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) else {
                                        return
                                    }

                                    if Calendar.current.isDate(selectedDay, inSameDayAs: today) {
                                        dueDate = today
                                    } else if Calendar.current.isDate(selectedDay, inSameDayAs: tomorrow) {
                                        dueDate = tomorrow
                                    } else {
                                        dueDate = selectedDay
                                    }
                                    showDatePicker = false
                                }
                                .padding(.top, 4)
                        }
                    }

                    Spacer()
                        .frame(height: 20)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
            
            Divider()

            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.05)))
                }
                .buttonStyle(.plain)
                
                Button(action: createTask) {
                    Text("Create Task")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(title.isEmpty ? Color.gray : Color.blue))
                }
                .buttonStyle(.plain)
                .disabled(title.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 500, height: 450)
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
    }
    
    private func addTag() {
        let trimmedTag = currentTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty,
              !tags.contains(trimmedTag) else { return }
        
        tags.append(trimmedTag)
        currentTag = ""
    }
    
    private func createTask() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let task = Task(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: tags,
            priority: selectedPriority,
            dueDate: dueDate,
            completed: false
        )
        
        context.tasksRepository.add(task)
        dismiss()
    }
    
    private func formatDate(_ date: Date?) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        guard let date else { return "" }
        return formatter.string(from: date)
    }
}

struct PriorityButton: View {
    let title: String
    let emoji: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.2) : Color.black.opacity(0.05)))
        }
        .buttonStyle(.plain)
    }
}

struct TagView: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text("#\(tag)")
                .font(.system(size: 12, weight: .medium))
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.blue.opacity(0.15)))
    }
}


