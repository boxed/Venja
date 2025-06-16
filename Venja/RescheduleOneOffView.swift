import SwiftUI
import SwiftData

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
    }
    
    private func rescheduleTask(_ task: VTask) {
        task.lastCompletedDate = nil
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to reschedule task: \(error)")
        }
    }
}

#Preview {
    RescheduleOneOffView()
        .modelContainer(for: VTask.self, inMemory: true)
}