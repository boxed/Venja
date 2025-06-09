//
//  ContentView.swift
//  Venja
//
//  Created by Anders Hovmöller on 2025-06-08.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Task.creationDate) private var tasks: [Task]
    @State private var showingConfiguration = false
    
    var activeTasks: [Task] {
        tasks.filter { task in
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
                                            task.markCompleted()
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingConfiguration = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingConfiguration) {
                ConfigurationView()
            }
            .onAppear {
                updateMissedCounts()
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
    }
}

struct WidgetTaskData: Codable {
    let name: String
    let missedCount: Int
    let schedulePeriod: Int
    let scheduleUnit: String
}

struct TaskCard: View {
    let task: Task
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(.headline)
                Text("\(task.schedulePeriod) \(task.scheduleUnit.rawValue.lowercased())")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if task.isOverdue {
                    Text("Overdue by \(task.daysOverdue) days")
                        .font(.caption)
                        .foregroundColor(.red)
                }
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
            
            Image(systemName: "checkmark.circle")
                .font(.title2)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Task.self, inMemory: true)
}