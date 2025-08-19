import SwiftUI
import SwiftData
import WidgetKit

struct RescheduleOneOffView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var allTasks: [VTask]
    
    private var completedNonRepeatingTasks: [VTask] {
        allTasks.filter { task in
            !task.isRepeating && task.lastCompletedDate != nil
        }
        .sorted { $0.name < $1.name }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if completedNonRepeatingTasks.isEmpty {
                    ContentUnavailableView(
                        "No Completed One-Off Tasks",
                        systemImage: "checklist",
                        description: Text("Completed one-off tasks will appear here")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(completedNonRepeatingTasks) { task in
                        Button {
                            rescheduleTask(task)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(task.name)
                                        .font(.headline)
                                    if let completedDate = task.lastCompletedDate {
                                        Text("Completed \(completedDate, style: .relative)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "arrow.clockwise")
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Reschedule One-Off Task")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 300)
        #endif
    }
    
    private func rescheduleTask(_ task: VTask) {
        task.lastCompletedDate = nil
        do {
            try modelContext.save()
            saveTasksForWidget()
            dismiss()
        } catch {
            print("Failed to reschedule task: \(error)")
        }
    }
    
    private func saveTasksForWidget() {
        let userDefaults = UserDefaults(suiteName: "group.net.kodare.Venja") ?? UserDefaults.standard
        
        // Save all tasks for the widget
        let tasksData = allTasks.map { task in
            WidgetTaskData(
                name: task.name,
                missedCount: task.missedCount,
                schedulePeriod: task.schedulePeriod,
                scheduleUnit: task.scheduleUnit.rawValue,
                creationDate: task.creationDate,
                lastCompletedDate: task.lastCompletedDate,
                isRepeating: task.isRepeating
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
    RescheduleOneOffView()
        .modelContainer(for: VTask.self, inMemory: true)
}