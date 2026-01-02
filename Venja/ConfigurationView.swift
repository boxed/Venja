//
//  ConfigurationView.swift
//  Venja
//
//  Created by Anders Hovmöller on 2025-06-08.
//

import SwiftUI
import SwiftData
import WidgetKit

struct ConfigurationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \VTask.name) private var tasks: [VTask]
    @State private var showingAddTask = false
    @State private var taskToEdit: VTask?
    @State private var taskToShowHistory: VTask?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(tasks) { task in
                    Button(action: {
                        taskToEdit = task
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.name)
                                    .font(.headline)
                                if task.isRepeating {
                                    Text("Every \(task.schedulePeriod) \(task.scheduleUnit.rawValue.lowercased())")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("One-time task")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if let lastCompleted = task.lastCompletedDate {
                                    Text("Last completed: \(lastCompleted.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                if task.isRepeating || task.lastCompletedDate == nil {
                                    Text("Next due: \(task.nextDueDate.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption2)
                                        .foregroundColor(task.missedCount > 0 ? .red : (task.isOverdue ? .orange : .blue))
                                }
                            }
                            Spacer()
                            
                            Button(action: {
                                taskToShowHistory = task
                            }) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: deleteTasks)
            }
            .navigationTitle("Tasks")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTask = true }) {
                        Image(systemName: "plus")
                    }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddTask = true }) {
                        Image(systemName: "plus")
                    }
                }
                #endif
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView()
            }
            .sheet(item: $taskToEdit) { task in
                EditTaskView(task: task)
            }
            .sheet(item: $taskToShowHistory) { task in
                TaskHistoryView(task: task)
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 500)
        #endif
    }
    
    private func deleteTasks(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(tasks[index])
            }
            saveTasksForWidget()
        }
    }
    
    private func saveTasksForWidget() {
        let userDefaults = UserDefaults(suiteName: "group.net.kodare.Venja") ?? UserDefaults.standard
        
        // Save all tasks for the widget
        let tasksData = tasks.map { task in
            WidgetTaskData(
                name: task.name,
                missedCount: task.missedCount,
                schedulePeriod: task.schedulePeriod,
                scheduleUnit: task.scheduleUnit.rawValue,
                creationDate: task.creationDate,
                lastCompletedDate: task.lastCompletedDate,
                isRepeating: task.isRepeating,
                totalPoints: task.totalPoints,
                scheduledHour: task.scheduledHour
            )
        }
        
        if let encoded = try? JSONEncoder().encode(tasksData) {
            userDefaults.set(encoded, forKey: "allTasks")
            userDefaults.synchronize() // Force synchronization
        }
        
        // Reload widget timelines
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var taskName = ""
    @State private var schedulePeriod = 1
    @State private var scheduleUnit = ScheduleUnit.days
    @State private var creationDate = Date()
    @State private var isRepeating = true
    @State private var scheduledHour = 0
    @State private var targetWeekday = Calendar.current.component(.weekday, from: Date())
    @State private var targetDayOfMonth = Calendar.current.component(.day, from: Date())
    @State private var targetMonth = Calendar.current.component(.month, from: Date())
    @State private var targetDayOfYear = Calendar.current.component(.day, from: Date())
    @FocusState private var isTaskNameFocused: Bool

    private static let weekdaySymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.weekdaySymbols
    }()

    private static let monthSymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.monthSymbols
    }()

    private func daysInMonth(_ month: Int) -> Int {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = calendar.component(.year, from: Date())
        components.month = month
        if let date = calendar.date(from: components),
           let range = calendar.range(of: .day, in: .month, for: date) {
            return range.count
        }
        return 31
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Task Name", text: $taskName)
                        .focused($isTaskNameFocused)
                }

                Section("Schedule") {
                    Toggle("Repeating Task", isOn: $isRepeating)

                    if isRepeating {
                        Picker("Repeat every", selection: $schedulePeriod) {
                            ForEach(1...365, id: \.self) { number in
                                Text("\(number)")
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Unit", selection: $scheduleUnit) {
                            ForEach(ScheduleUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)

                        // Target pickers based on schedule unit
                        if scheduleUnit == .weeks {
                            Picker("Target day", selection: $targetWeekday) {
                                ForEach(1...7, id: \.self) { weekday in
                                    Text(Self.weekdaySymbols[weekday - 1])
                                }
                            }
                            .pickerStyle(.menu)
                        } else if scheduleUnit == .months {
                            Picker("Target day of month", selection: $targetDayOfMonth) {
                                ForEach(1...31, id: \.self) { day in
                                    Text("\(day)")
                                }
                            }
                            .pickerStyle(.menu)
                        } else if scheduleUnit == .years {
                            Picker("Target month", selection: $targetMonth) {
                                ForEach(1...12, id: \.self) { month in
                                    Text(Self.monthSymbols[month - 1])
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("Target day", selection: $targetDayOfYear) {
                                ForEach(1...daysInMonth(targetMonth), id: \.self) { day in
                                    Text("\(day)")
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: targetMonth) { _, newMonth in
                                let maxDays = daysInMonth(newMonth)
                                if targetDayOfYear > maxDays {
                                    targetDayOfYear = maxDays
                                }
                            }
                        }
                    }

                    Picker("Time of day", selection: $scheduledHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d:00", hour))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("New Task")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addTask()
                    }
                    .disabled(taskName.isEmpty)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add") {
                        addTask()
                    }
                    .disabled(taskName.isEmpty)
                }
                #endif
            }
            .onAppear {
                isTaskNameFocused = true
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 400)
        #endif
    }
    
    private func computeCreationDate() -> Date {
        let calendar = Calendar.current
        let now = Date()

        guard isRepeating else {
            return now
        }

        switch scheduleUnit {
        case .days:
            // For days, creation date is now
            return now
        case .weeks:
            // Compute a creation date that, when schedulePeriod weeks are added, lands on targetWeekday
            // Find the most recent occurrence of targetWeekday
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear, .weekday], from: now)
            components.weekday = targetWeekday
            if let targetDate = calendar.date(from: components) {
                // Go back schedulePeriod weeks from that target
                return calendar.date(byAdding: .weekOfYear, value: -schedulePeriod, to: targetDate) ?? now
            }
            return now
        case .months:
            // Compute a creation date that, when schedulePeriod months are added, lands on targetDayOfMonth
            var components = calendar.dateComponents([.year, .month], from: now)
            components.day = targetDayOfMonth
            if let targetDate = calendar.date(from: components) {
                // Go back schedulePeriod months from that target
                return calendar.date(byAdding: .month, value: -schedulePeriod, to: targetDate) ?? now
            }
            return now
        case .years:
            // Compute a creation date that, when schedulePeriod years are added, lands on targetMonth/targetDayOfYear
            var components = calendar.dateComponents([.year], from: now)
            components.month = targetMonth
            components.day = targetDayOfYear
            if let targetDate = calendar.date(from: components) {
                // Go back schedulePeriod years from that target
                return calendar.date(byAdding: .year, value: -schedulePeriod, to: targetDate) ?? now
            }
            return now
        }
    }

    private func addTask() {
        let computedCreationDate = computeCreationDate()
        let newTask = VTask(name: taskName, schedulePeriod: schedulePeriod, scheduleUnit: scheduleUnit, creationDate: computedCreationDate, isRepeating: isRepeating, scheduledHour: scheduledHour)
        modelContext.insert(newTask)
        saveTasksForWidget()
        dismiss()
    }
    
    private func saveTasksForWidget() {
        let userDefaults = UserDefaults(suiteName: "group.net.kodare.Venja") ?? UserDefaults.standard
        
        // Fetch all tasks to save for widget
        let descriptor = FetchDescriptor<VTask>()
        let allTasks = (try? modelContext.fetch(descriptor)) ?? []
        
        let tasksData = allTasks.map { task in
            WidgetTaskData(
                name: task.name,
                missedCount: task.missedCount,
                schedulePeriod: task.schedulePeriod,
                scheduleUnit: task.scheduleUnit.rawValue,
                creationDate: task.creationDate,
                lastCompletedDate: task.lastCompletedDate,
                isRepeating: task.isRepeating,
                totalPoints: task.totalPoints,
                scheduledHour: task.scheduledHour
            )
        }
        
        if let encoded = try? JSONEncoder().encode(tasksData) {
            userDefaults.set(encoded, forKey: "allTasks")
            userDefaults.synchronize() // Force synchronization
        }
        
        // Reload widget timelines
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct EditTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var task: VTask

    @State private var taskName: String
    @State private var schedulePeriod: Int
    @State private var scheduleUnit: ScheduleUnit
    @State private var isRepeating: Bool
    @State private var scheduledHour: Int
    @State private var targetWeekday: Int
    @State private var targetDayOfMonth: Int
    @State private var targetMonth: Int
    @State private var targetDayOfYear: Int
    @FocusState private var isTaskNameFocused: Bool

    private static let weekdaySymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.weekdaySymbols
    }()

    private static let monthSymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.monthSymbols
    }()

    private func daysInMonth(_ month: Int) -> Int {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = calendar.component(.year, from: Date())
        components.month = month
        if let date = calendar.date(from: components),
           let range = calendar.range(of: .day, in: .month, for: date) {
            return range.count
        }
        return 31
    }

    init(task: VTask) {
        self.task = task
        _taskName = State(initialValue: task.name)
        _schedulePeriod = State(initialValue: task.schedulePeriod)
        _scheduleUnit = State(initialValue: task.scheduleUnit)
        _isRepeating = State(initialValue: task.isRepeating)
        _scheduledHour = State(initialValue: task.scheduledHour)

        // Derive target values from the task's next due date
        let calendar = Calendar.current
        let dueDate = task.nextDueDate
        _targetWeekday = State(initialValue: calendar.component(.weekday, from: dueDate))
        _targetDayOfMonth = State(initialValue: calendar.component(.day, from: dueDate))
        _targetMonth = State(initialValue: calendar.component(.month, from: dueDate))
        _targetDayOfYear = State(initialValue: calendar.component(.day, from: dueDate))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Task Name", text: $taskName)
                        .focused($isTaskNameFocused)
                }

                Section("Schedule") {
                    Toggle("Repeating Task", isOn: $isRepeating)

                    if isRepeating {
                        Picker("Repeat every", selection: $schedulePeriod) {
                            ForEach(1...365, id: \.self) { number in
                                Text("\(number)")
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Unit", selection: $scheduleUnit) {
                            ForEach(ScheduleUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)

                        // Target pickers based on schedule unit
                        if scheduleUnit == .weeks {
                            Picker("Target day", selection: $targetWeekday) {
                                ForEach(1...7, id: \.self) { weekday in
                                    Text(Self.weekdaySymbols[weekday - 1])
                                }
                            }
                            .pickerStyle(.menu)
                        } else if scheduleUnit == .months {
                            Picker("Target day of month", selection: $targetDayOfMonth) {
                                ForEach(1...31, id: \.self) { day in
                                    Text("\(day)")
                                }
                            }
                            .pickerStyle(.menu)
                        } else if scheduleUnit == .years {
                            Picker("Target month", selection: $targetMonth) {
                                ForEach(1...12, id: \.self) { month in
                                    Text(Self.monthSymbols[month - 1])
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("Target day", selection: $targetDayOfYear) {
                                ForEach(1...daysInMonth(targetMonth), id: \.self) { day in
                                    Text("\(day)")
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: targetMonth) { _, newMonth in
                                let maxDays = daysInMonth(newMonth)
                                if targetDayOfYear > maxDays {
                                    targetDayOfYear = maxDays
                                }
                            }
                        }
                    }

                    Picker("Time of day", selection: $scheduledHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d:00", hour))
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Completion History") {
                    if let history = task.completionHistory, !history.isEmpty {
                        ForEach(history.sorted(by: { $0.completionDate > $1.completionDate })) { entry in
                            HStack {
                                Text(entry.completionDate, style: .date)
                                Text(entry.completionDate, style: .time)
                                Spacer()
                                if entry.missedCountAtCompletion > 0 {
                                    Text("(missed: \(entry.missedCountAtCompletion))")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }
                        }
                    } else {
                        Text("No completions yet")
                            .foregroundColor(.secondary)
                    }

                    if let lastCompleted = task.lastCompletedDate {
                        HStack {
                            Text("Last completed:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(lastCompleted, style: .date)
                            Text(lastCompleted, style: .time)
                        }
                        .font(.caption)
                    }
                }
            }
            .navigationTitle("Edit Task")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTask()
                    }
                    .disabled(taskName.isEmpty)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        saveTask()
                    }
                    .disabled(taskName.isEmpty)
                }
                #endif
            }
            .onAppear {
                isTaskNameFocused = true
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 400)
        #endif
    }
    
    private func computeCreationDate() -> Date {
        let calendar = Calendar.current
        let now = Date()

        guard isRepeating else {
            return task.creationDate  // Keep original for non-repeating
        }

        switch scheduleUnit {
        case .days:
            // For days, keep the original creation date
            return task.creationDate
        case .weeks:
            // Compute a creation date that, when schedulePeriod weeks are added, lands on targetWeekday
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear, .weekday], from: now)
            components.weekday = targetWeekday
            if let targetDate = calendar.date(from: components) {
                return calendar.date(byAdding: .weekOfYear, value: -schedulePeriod, to: targetDate) ?? task.creationDate
            }
            return task.creationDate
        case .months:
            // Compute a creation date that, when schedulePeriod months are added, lands on targetDayOfMonth
            var components = calendar.dateComponents([.year, .month], from: now)
            components.day = targetDayOfMonth
            if let targetDate = calendar.date(from: components) {
                return calendar.date(byAdding: .month, value: -schedulePeriod, to: targetDate) ?? task.creationDate
            }
            return task.creationDate
        case .years:
            // Compute a creation date that, when schedulePeriod years are added, lands on targetMonth/targetDayOfYear
            var components = calendar.dateComponents([.year], from: now)
            components.month = targetMonth
            components.day = targetDayOfYear
            if let targetDate = calendar.date(from: components) {
                return calendar.date(byAdding: .year, value: -schedulePeriod, to: targetDate) ?? task.creationDate
            }
            return task.creationDate
        }
    }

    private func saveTask() {
        task.name = taskName
        task.schedulePeriod = schedulePeriod
        task.scheduleUnit = scheduleUnit
        task.creationDate = computeCreationDate()
        task.isRepeating = isRepeating
        task.scheduledHour = scheduledHour
        saveTasksForWidget()
        dismiss()
    }
    
    private func saveTasksForWidget() {
        let userDefaults = UserDefaults(suiteName: "group.net.kodare.Venja") ?? UserDefaults.standard
        
        // Fetch all tasks to save for widget
        let descriptor = FetchDescriptor<VTask>()
        let allTasks = (try? modelContext.fetch(descriptor)) ?? []
        
        let tasksData = allTasks.map { task in
            WidgetTaskData(
                name: task.name,
                missedCount: task.missedCount,
                schedulePeriod: task.schedulePeriod,
                scheduleUnit: task.scheduleUnit.rawValue,
                creationDate: task.creationDate,
                lastCompletedDate: task.lastCompletedDate,
                isRepeating: task.isRepeating,
                totalPoints: task.totalPoints,
                scheduledHour: task.scheduledHour
            )
        }
        
        if let encoded = try? JSONEncoder().encode(tasksData) {
            userDefaults.set(encoded, forKey: "allTasks")
            userDefaults.synchronize() // Force synchronization
        }
        
        // Reload widget timelines
        WidgetCenter.shared.reloadAllTimelines()
    }
}

#Preview {
    ConfigurationView()
        .modelContainer(for: VTask.self, inMemory: true)
}
