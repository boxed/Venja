//
//  VenjaLockScreenWidget.swift
//  VenjaWidget
//
//  Lock screen widget for Venja
//

import WidgetKit
import SwiftUI
import SwiftData

struct LockScreenProvider: AppIntentTimelineProvider {
    private var modelContainer: ModelContainer = {
        let schema = Schema([
            VTask.self,
            CompletionHistory.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent(), tasks: [], isPlaceholder: true)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let tasks = fetchTasksSync()
        return SimpleEntry(date: Date(), configuration: configuration, tasks: tasks)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let currentDate = Date()
        let calendar = Calendar.current

        // Fetch current tasks directly from SwiftData
        let activeTasks = fetchTasksSync()
        let allTasks = fetchAllTasksSync()

        // Create single entry for current state
        let entry = SimpleEntry(date: currentDate, configuration: configuration, tasks: activeTasks)

        // Calculate when to reload the timeline
        let startOfTomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: currentDate)!)

        // Find the next task that will become due (for intra-day scheduling)
        let nextTaskDueDate = allTasks
            .filter { $0.nextDueDate > currentDate }
            .map { $0.nextDueDate }
            .min()

        // Reload timeline at: next task due time, midnight, or in 4 hours - whichever comes first
        var nextUpdate = min(startOfTomorrow, currentDate.addingTimeInterval(4 * 3600))
        if let nextDue = nextTaskDueDate {
            nextUpdate = min(nextUpdate, nextDue)
        }

        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

struct VenjaLockScreenWidgetCircularView: View {
    var entry: SimpleEntry

    private func circlePosition(for index: Int, total: Int, radius: CGFloat) -> CGPoint {
        let angle = (2 * .pi / CGFloat(total)) * CGFloat(index) - .pi / 2
        let x = radius * cos(angle)
        let y = radius * sin(angle)
        return CGPoint(x: x, y: y)
    }

    var body: some View {
        if entry.isPlaceholder {
            Color.clear
        } else if entry.tasks.isEmpty {
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .widgetAccentable()
        } else {
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                let center = CGPoint(x: size / 2, y: size / 2)
                let radius = size * 0.35
                let circleSize = size * 0.15
                let maxTasks = 12
                let tasksToShow = Array(entry.tasks.prefix(maxTasks))

                ZStack {
                    ForEach(0..<tasksToShow.count, id: \.self) { index in
                        let task = tasksToShow[index]
                        let position = circlePosition(for: index, total: tasksToShow.count, radius: radius)

                        Circle()
                            .fill(task.missedCount > 0 ? Color.primary : Color.clear)
                            .stroke(Color.primary, lineWidth: 1.5)
                            .frame(width: circleSize, height: circleSize)
                            .position(x: center.x + position.x, y: center.y + position.y)
                    }
                }
            }
            .widgetAccentable()
        }
    }
}

struct VenjaLockScreenWidgetRectangularView: View {
    var entry: SimpleEntry

    var body: some View {
        if entry.isPlaceholder {
            Color.clear
        } else if entry.tasks.isEmpty {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                Text("All done!")
                    .font(.headline)
            }
            .widgetAccentable()
        } else {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if entry.tasks.contains(where: { $0.missedCount > 0 }) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                    }
                    Text("\(entry.tasks.count) task\(entry.tasks.count == 1 ? "" : "s") due")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                
                if let firstTask = entry.tasks.first {
                    Text(firstTask.name)
                        .font(.caption2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                
                if entry.tasks.count > 1, let secondTask = entry.tasks.dropFirst().first {
                    Text(secondTask.name)
                        .font(.caption2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .widgetAccentable()
        }
    }
}

struct VenjaLockScreenWidgetInlineView: View {
    var entry: SimpleEntry

    var body: some View {
        if entry.isPlaceholder {
            Color.clear
        } else if entry.tasks.isEmpty {
            Label("All done!", systemImage: "checkmark.circle.fill")
        } else {
            let hasMissed = entry.tasks.contains(where: { $0.missedCount > 0 })
            Label {
                Text("\(entry.tasks.count) task\(entry.tasks.count == 1 ? "" : "s")")
            } icon: {
                Image(systemName: hasMissed ? "exclamationmark.circle.fill" : "circle.fill")
            }
        }
    }
}

struct VenjaLockScreenWidgetEntryView: View {
    var entry: SimpleEntry
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        switch widgetFamily {
        case .accessoryCircular:
            VenjaLockScreenWidgetCircularView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        case .accessoryRectangular:
            VenjaLockScreenWidgetRectangularView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        case .accessoryInline:
            VenjaLockScreenWidgetInlineView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        default:
            EmptyView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

struct VenjaLockScreenWidget: Widget {
    let kind: String = "VenjaLockScreenWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: LockScreenProvider()) { entry in
            VenjaLockScreenWidgetEntryView(entry: entry)
        }
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
        .configurationDisplayName("Venja Tasks")
        .description("View your pending tasks on the lock screen")
    }
}

extension LockScreenProvider {
    func fetchAllTasksSync() -> [VTask] {
        let context = ModelContext(modelContainer)

        do {
            let descriptor = FetchDescriptor<VTask>()
            return try context.fetch(descriptor)
        } catch {
            print("Failed to fetch tasks: \(error)")
            return []
        }
    }

    func fetchTasksSync() -> [WidgetTaskData] {
        let context = ModelContext(modelContainer)
        
        do {
            let descriptor = FetchDescriptor<VTask>()
            let tasks = try context.fetch(descriptor)
            
            // Update missed counts for all tasks
            for task in tasks {
                task.updateMissedCount()
            }
            
            let activeTasks = tasks.filter { task in
                // Check if task is active (due date has passed, respecting scheduledHour)
                if task.isRepeating {
                    return task.nextDueDate <= Date()
                } else {
                    // Non-repeating tasks are active if not completed and due
                    return task.lastCompletedDate == nil && task.nextDueDate <= Date()
                }
            }.sorted { task1, task2 in
                if task1.missedCount != task2.missedCount {
                    return task1.missedCount > task2.missedCount
                }
                return task1.nextDueDate < task2.nextDueDate
            }.map { task in
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
            
            return activeTasks
        } catch {
            print("Failed to fetch tasks: \(error)")
            return []
        }
    }
}

#Preview("Circular", as: .accessoryCircular) {
    VenjaLockScreenWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), tasks: [
        WidgetTaskData(name: "Take vitamins", missedCount: 0, schedulePeriod: 1, scheduleUnit: "Days", 
                      creationDate: Date(), lastCompletedDate: nil, isRepeating: true, totalPoints: 25, scheduledHour: 0),
        WidgetTaskData(name: "Take vitamins", missedCount: 0, schedulePeriod: 1, scheduleUnit: "Days",
                      creationDate: Date(), lastCompletedDate: nil, isRepeating: true, totalPoints: 20, scheduledHour: 0),
        WidgetTaskData(name: "Take vitamins", missedCount: 0, schedulePeriod: 1, scheduleUnit: "Days",
                      creationDate: Date(), lastCompletedDate: nil, isRepeating: true, totalPoints: 15, scheduledHour: 0),
        WidgetTaskData(name: "Take vitamins", missedCount: 0, schedulePeriod: 1, scheduleUnit: "Days",
                      creationDate: Date(), lastCompletedDate: nil, isRepeating: true, totalPoints: 10, scheduledHour: 0),
        WidgetTaskData(name: "Take vitamins", missedCount: 0, schedulePeriod: 1, scheduleUnit: "Days",
                      creationDate: Date(), lastCompletedDate: nil, isRepeating: true, totalPoints: 5, scheduledHour: 0),
        WidgetTaskData(name: "Take vitamins", missedCount: 0, schedulePeriod: 1, scheduleUnit: "Days",
                      creationDate: Date(), lastCompletedDate: nil, isRepeating: true, totalPoints: 10, scheduledHour: 0),
        WidgetTaskData(name: "Water plants", missedCount: 2, schedulePeriod: 3, scheduleUnit: "Days", 
                      creationDate: Date().addingTimeInterval(-86400 * 10), lastCompletedDate: nil, isRepeating: true, totalPoints: 8, scheduledHour: 0)
    ])
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), tasks: [])
}

#Preview("Rectangular", as: .accessoryRectangular) {
    VenjaLockScreenWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), tasks: [
        WidgetTaskData(name: "Take vitamins", missedCount: 0, schedulePeriod: 1, scheduleUnit: "Days", 
                      creationDate: Date(), lastCompletedDate: nil, isRepeating: true, totalPoints: 25, scheduledHour: 0),
        WidgetTaskData(name: "Water plants in the living room", missedCount: 2, schedulePeriod: 3, scheduleUnit: "Days", 
                      creationDate: Date().addingTimeInterval(-86400 * 10), lastCompletedDate: nil, isRepeating: true, totalPoints: 15, scheduledHour: 0)
    ])
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), tasks: [])
}

#Preview("Inline", as: .accessoryInline) {
    VenjaLockScreenWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), tasks: [
        WidgetTaskData(name: "Take vitamins", missedCount: 1, schedulePeriod: 1, scheduleUnit: "Days", 
                      creationDate: Date(), lastCompletedDate: nil, isRepeating: true, totalPoints: 20, scheduledHour: 0)
    ])
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), tasks: [])
}
