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
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(tasks) { task in
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
        }
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
    }
    
    private func addTask() {
        let newTask = Task(name: taskName, schedulePeriod: schedulePeriod, scheduleUnit: scheduleUnit)
        modelContext.insert(newTask)
        dismiss()
    }
}

#Preview {
    ConfigurationView()
        .modelContainer(for: Task.self, inMemory: true)
}