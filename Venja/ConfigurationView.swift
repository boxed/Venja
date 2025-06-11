//
//  ConfigurationView.swift
//  Venja
//
//  Created by Anders Hovmöller on 2025-06-08.
//

import SwiftUI
import SwiftData

struct ConfigurationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Task.name) private var tasks: [Task]
    @State private var showingAddTask = false
    @State private var taskToEdit: Task?
    @State private var showingEditTask = false
    
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
                                Text("Every \(task.schedulePeriod) \(task.scheduleUnit.rawValue.lowercased())")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if let lastCompleted = task.lastCompletedDate {
                                    Text("Last completed: \(lastCompleted.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
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
        }
    }
}

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var taskName = ""
    @State private var schedulePeriod = 1
    @State private var scheduleUnit = ScheduleUnit.days
    @State private var creationDate = Date()
    @FocusState private var isTaskNameFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Task Name", text: $taskName)
                        .focused($isTaskNameFocused)
                }
                
                Section("Schedule") {
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
        let newTask = Task(name: taskName, schedulePeriod: schedulePeriod, scheduleUnit: scheduleUnit, creationDate: creationDate)
        modelContext.insert(newTask)
        dismiss()
    }
}

struct EditTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var task: Task
    
    @State private var taskName: String
    @State private var schedulePeriod: Int
    @State private var scheduleUnit: ScheduleUnit
    @State private var creationDate: Date
    @FocusState private var isTaskNameFocused: Bool
    
    init(task: Task) {
        self.task = task
        _taskName = State(initialValue: task.name)
        _schedulePeriod = State(initialValue: task.schedulePeriod)
        _scheduleUnit = State(initialValue: task.scheduleUnit)
        _creationDate = State(initialValue: task.creationDate)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Task Name", text: $taskName)
                        .focused($isTaskNameFocused)
                }
                
                Section("Schedule") {
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
        dismiss()
    }
}

#Preview {
    ConfigurationView()
        .modelContainer(for: Task.self, inMemory: true)
}