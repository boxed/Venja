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
    @State private var showingEditTask = false
    @State private var taskToShowHistory: VTask?
    @State private var showingHistory = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(tasks) { task in
                    Button(action: {
                        taskToEdit = task
                        showingEditTask = true
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
                                if task.totalPoints > 0 {
                                    Text("\(task.totalPoints) total points")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                            }
                            Spacer()
                            
                            Button(action: {
                                taskToShowHistory = task
                                showingHistory = true
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
            .sheet(isPresented: $showingEditTask) {
                if let task = taskToEdit {
                    EditTaskView(task: task)
                }
            }
            .sheet(isPresented: $showingHistory) {
                if let task = taskToShowHistory {
                    TaskHistoryView(task: task)
                }
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
                totalPoints: task.totalPoints
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
    @FocusState private var isTaskNameFocused: Bool
    
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
                    }
                }
                
                Section("Creation Date") {
                    DatePicker("Created on", selection: $creationDate, displayedComponents: .date)
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
    
    private func addTask() {
        let newTask = VTask(name: taskName, schedulePeriod: schedulePeriod, scheduleUnit: scheduleUnit, creationDate: creationDate, isRepeating: isRepeating)
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
                totalPoints: task.totalPoints
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
    @State private var creationDate: Date
    @State private var isRepeating: Bool
    @FocusState private var isTaskNameFocused: Bool
    
    init(task: VTask) {
        self.task = task
        _taskName = State(initialValue: task.name)
        _schedulePeriod = State(initialValue: task.schedulePeriod)
        _scheduleUnit = State(initialValue: task.scheduleUnit)
        _creationDate = State(initialValue: task.creationDate)
        _isRepeating = State(initialValue: task.isRepeating)
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
                    }
                }
                
                Section("Creation Date") {
                    DatePicker("Created on", selection: $creationDate, displayedComponents: .date)
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
    
    private func saveTask() {
        task.name = taskName
        task.schedulePeriod = schedulePeriod
        task.scheduleUnit = scheduleUnit
        task.creationDate = creationDate
        task.isRepeating = isRepeating
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
                totalPoints: task.totalPoints
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
