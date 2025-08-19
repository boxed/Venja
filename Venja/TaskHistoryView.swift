//
//  TaskHistoryView.swift
//  Venja
//
//  Created by Claude on 2025-08-18.
//

import SwiftUI
import SwiftData

struct TaskHistoryView: View {
    let task: VTask
    @Environment(\.dismiss) private var dismiss
    
    var sortedHistory: [CompletionHistory] {
        task.completionHistory!.sorted { $0.completionDate > $1.completionDate }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if sortedHistory.isEmpty {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "clock",
                        description: Text("This task has not been completed yet")
                    )
                } else {
                    Section {
                        ForEach(sortedHistory, id: \.completionDate) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.completionDate.formatted(date: .abbreviated, time: .shortened))
                                        .font(.headline)
                                    if entry.missedCountAtCompletion > 0 {
                                        Label("\(entry.missedCountAtCompletion) \(entry.missedCountAtCompletion == 1 ? "repeat" : "repeats") at completion", 
                                              systemImage: "repeat.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    } else {
                                        Label("Completed on time", systemImage: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                                
                                Spacer()
                                
                                HStack(spacing: 8) {
                                    Text("\(entry.points) pts")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(pointsColor(for: entry.points))
                                    
                                    if entry.missedCountAtCompletion > 0 {
                                        ZStack {
                                            Circle()
                                                .fill(Color.orange.opacity(0.2))
                                                .frame(width: 30, height: 30)
                                            Text("\(entry.missedCountAtCompletion)")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        HStack {
                            Text("Completion History")
                            Spacer()
                            Text("Total: \(sortedHistory.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Section {
                        HStack {
                            Text("Total Points")
                            Spacer()
                            Text("\(task.totalPoints)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.blue)
                        }
                        
                        HStack {
                            Text("Average Points")
                            Spacer()
                            Text(String(format: "%.1f", task.averagePoints))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Average missed count")
                            Spacer()
                            Text(String(format: "%.1f", averageMissedCount))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("On-time completion rate")
                            Spacer()
                            Text("\(Int(onTimeRate * 100))%")
                                .foregroundColor(onTimeRate > 0.8 ? .green : .orange)
                        }
                    } header: {
                        Text("Statistics")
                    }
                }
            }
            .navigationTitle("\(task.name) History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var averageMissedCount: Double {
        guard !sortedHistory.isEmpty else { return 0 }
        let total = sortedHistory.reduce(0) { $0 + $1.missedCountAtCompletion }
        return Double(total) / Double(sortedHistory.count)
    }
    
    private var onTimeRate: Double {
        guard !sortedHistory.isEmpty else { return 0 }
        let onTimeCount = sortedHistory.filter { $0.missedCountAtCompletion == 0 }.count
        return Double(onTimeCount) / Double(sortedHistory.count)
    }
    
    private func pointsColor(for points: Int) -> Color {
        switch points {
        case 5:
            return .green
        case 4:
            return .blue
        case 3:
            return .orange
        case 2:
            return .orange.opacity(0.7)
        default:
            return .red
        }
    }
}
