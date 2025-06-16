//
//  ContentView.swift
//  Venja
//
//  Created by Anders Hovmöller on 2025-06-08.
//

import SwiftUI
import SwiftData
import WidgetKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VTask.creationDate) private var tasks: [VTask]
    @State private var showingConfiguration = false
    @State private var undoManager = TaskUndoManager()
    @State private var showingUndoAlert = false
    @State private var lastUndoAction: UndoAction?
    
    var activeTasks: [VTask] {
        tasks.filter { task in
            // Exclude completed non-repeating tasks
            if !task.isRepeating && task.lastCompletedDate != nil {
                return false
            }
            let calendar = Calendar.current
            return calendar.isDateInToday(task.nextDueDate) || task.isOverdue
        }.sorted { 
            // Sort by missed count (descending), then by next due date (ascending)
            if $0.missedCount != $1.missedCount {
                return $0.missedCount > $1.missedCount
            }
            return $0.nextDueDate < $1.nextDueDate
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if activeTasks.isEmpty {
                    Spacer()
                    Text("Done!")
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Text("All tasks completed for today")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(activeTasks) { task in
                                TaskCard(task: task)
                                    .onTapGesture {
                                        withAnimation {
                                            let previousDate = task.lastCompletedDate
                                            let previousMissedCount = task.missedCount
                                            task.markCompleted()
                                            undoManager.recordCompletion(
                                                task: task,
                                                previousDate: previousDate,
                                                previousMissedCount: previousMissedCount
                                            )
                                            saveCurrentTaskForWidget()
                                        }
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Venja")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingConfiguration = true }) {
                        Image(systemName: "gear")
                    }
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingConfiguration = true }) {
                        Image(systemName: "gear")
                    }
                }
                #endif
            }
            .sheet(isPresented: $showingConfiguration) {
                ConfigurationView()
            }
            .onAppear {
                updateMissedCounts()
                #if os(iOS)
                NotificationCenter.default.addObserver(
                    forName: .deviceDidShake,
                    object: nil,
                    queue: .main
                ) { _ in
                    handleShake()
                }
                #endif
            }
            .alert("Undo Action", isPresented: $showingUndoAlert) {
                Button("Undo") {
                    if let action = lastUndoAction {
                        withAnimation {
                            _ = undoManager.undo()
                            saveCurrentTaskForWidget()
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let action = lastUndoAction {
                    Text("Undo completion of '\(action.task.name)'?")
                }
            }
        }
    }
    
    private func updateMissedCounts() {
        for task in tasks {
            task.updateMissedCount()
        }
        
        // Update widget data
        saveCurrentTaskForWidget()
    }
    
    private func handleShake() {
        guard undoManager.canUndo else { return }
        
        // Get the most recent action without removing it from the stack
        if let recentAction = undoManager.undoStack.last {
            lastUndoAction = recentAction
            showingUndoAlert = true
        }
    }
    
    private func saveCurrentTaskForWidget() {
        let userDefaults = UserDefaults(suiteName: "group.net.kodare.Venja") ?? UserDefaults.standard
        
        if let firstTask = activeTasks.first {
            let taskData = WidgetTaskData(
                name: firstTask.name,
                missedCount: firstTask.missedCount,
                schedulePeriod: firstTask.schedulePeriod,
                scheduleUnit: firstTask.scheduleUnit.rawValue
            )
            
            if let encoded = try? JSONEncoder().encode(taskData) {
                userDefaults.set(encoded, forKey: "currentTask")
            }
        } else {
            userDefaults.removeObject(forKey: "currentTask")
        }
        
        // Reload widget timelines
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct WidgetTaskData: Codable {
    let name: String
    let missedCount: Int
    let schedulePeriod: Int
    let scheduleUnit: String
}

struct TaskCard: View {
    let task: VTask
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(.headline)
            }
            
            Spacer()
            
            if task.missedCount > 0 {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 30, height: 30)
                    Text("\(task.missedCount)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        #if os(iOS)
        .background(
            Color(UIColor.secondarySystemBackground)
        )
        #else
        .background(
            Color(NSColor.controlBackgroundColor)
        )
        #endif
        .cornerRadius(12)
    }
}

#Preview {
    let container = try! ModelContainer(for: VTask.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext
    
    let twoWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -2, to: Date())!
    
    let task1 = VTask(name: "Water plants", schedulePeriod: 3, scheduleUnit: .days, creationDate: twoWeeksAgo)
    let task2 = VTask(name: "Clean bathroom", schedulePeriod: 1, scheduleUnit: .weeks, creationDate: twoWeeksAgo)
    let task3 = VTask(name: "Check smoke detectors", schedulePeriod: 1, scheduleUnit: .months, creationDate: twoWeeksAgo)
    
    context.insert(task1)
    context.insert(task2)
    context.insert(task3)
    
    return ContentView()
        .modelContainer(container)
}
