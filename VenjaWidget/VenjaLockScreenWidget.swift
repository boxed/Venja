//
//  VenjaLockScreenWidget.swift
//  VenjaWidget
//
//  Lock screen widget for Venja
//

import WidgetKit
import SwiftUI

struct LockScreenProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent(), tasks: [])
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let tasks = await fetchActiveTasks()
        return SimpleEntry(date: Date(), configuration: configuration, tasks: tasks)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []
        
        let currentDate = Date()
        let calendar = Calendar.current
        
        let allTasks = await fetchAllTasks()
        
        func getActiveTasksForDate(_ date: Date) -> [WidgetTaskData] {
            return allTasks.filter { task in
                task.isActiveForDate(date)
            }.sorted { task1, task2 in
                if task1.missedCount != task2.missedCount {
                    return task1.missedCount > task2.missedCount
                }
                return task1.nextDueDate < task2.nextDueDate
            }
        }
        
        let currentTasks = getActiveTasksForDate(currentDate)
        entries.append(SimpleEntry(date: currentDate, configuration: configuration, tasks: currentTasks))
        
        let startOfToday = calendar.startOfDay(for: currentDate)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        
        if currentDate < startOfTomorrow {
            let justAfterMidnight = startOfTomorrow.addingTimeInterval(1)
            let midnightTasks = getActiveTasksForDate(justAfterMidnight)
            entries.append(SimpleEntry(date: justAfterMidnight, configuration: configuration, tasks: midnightTasks))
        }
        
        for dayOffset in 1...3 {
            if let futureDay = calendar.date(byAdding: .day, value: dayOffset, to: startOfTomorrow) {
                let justAfterMidnight = futureDay.addingTimeInterval(1)
                let futureTasks = getActiveTasksForDate(justAfterMidnight)
                entries.append(SimpleEntry(date: justAfterMidnight, configuration: configuration, tasks: futureTasks))
            }
        }
        
        var nextUpdate = currentDate
        while nextUpdate < startOfTomorrow {
            nextUpdate = calendar.date(byAdding: .hour, value: 2, to: nextUpdate) ?? startOfTomorrow
            if nextUpdate < startOfTomorrow {
                let updateTasks = getActiveTasksForDate(nextUpdate)
                entries.append(SimpleEntry(date: nextUpdate, configuration: configuration, tasks: updateTasks))
            }
        }
        
        entries.sort { $0.date < $1.date }
        entries = entries.reduce(into: [SimpleEntry]()) { result, entry in
            if result.isEmpty || abs(result.last!.date.timeIntervalSince(entry.date)) > 60 {
                result.append(entry)
            }
        }
        
        return Timeline(entries: entries, policy: .atEnd)
    }
}

struct VenjaLockScreenWidgetCircularView: View {
    var entry: SimpleEntry
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            if entry.tasks.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .widgetAccentable()
            } else {
                VStack(spacing: 2) {
                    if let firstTask = entry.tasks.first {
                        if firstTask.missedCount > 0 {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption)
                        }
                        Text("\(entry.tasks.count)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("tasks")
                            .font(.caption2)
                    }
                }
                .widgetAccentable()
            }
        }
    }
}

struct VenjaLockScreenWidgetRectangularView: View {
    var entry: SimpleEntry
    
    var body: some View {
        if entry.tasks.isEmpty {
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
        if entry.tasks.isEmpty {
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
    func fetchAllTasks() async -> [WidgetTaskData] {
        let userDefaults = UserDefaults(suiteName: "group.net.kodare.Venja") ?? UserDefaults.standard
        
        let tasksData: Data?
        if let allTasksData = userDefaults.data(forKey: "allTasks") {
            tasksData = allTasksData
        } else {
            tasksData = userDefaults.data(forKey: "activeTasks")
        }
        
        guard let data = tasksData,
              let tasks = try? JSONDecoder().decode([WidgetTaskData].self, from: data) else {
            return []
        }
        
        return tasks
    }
    
    func fetchActiveTasks() async -> [WidgetTaskData] {
        let tasks = await fetchAllTasks()
        
        let currentDate = Date()
        let activeTasks = tasks.filter { task in
            task.isActiveForDate(currentDate)
        }.sorted { task1, task2 in
            if task1.missedCount != task2.missedCount {
                return task1.missedCount > task2.missedCount
            }
            return task1.nextDueDate < task2.nextDueDate
        }
        
        return activeTasks
    }
}

#Preview("Circular", as: .accessoryCircular) {
    VenjaLockScreenWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), tasks: [
        WidgetTaskData(name: "Take vitamins", missedCount: 0, schedulePeriod: 1, scheduleUnit: "Days", 
                      creationDate: Date(), lastCompletedDate: nil, isRepeating: true),
        WidgetTaskData(name: "Water plants", missedCount: 2, schedulePeriod: 3, scheduleUnit: "Days", 
                      creationDate: Date().addingTimeInterval(-86400 * 10), lastCompletedDate: nil, isRepeating: true)
    ])
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), tasks: [])
}

#Preview("Rectangular", as: .accessoryRectangular) {
    VenjaLockScreenWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), tasks: [
        WidgetTaskData(name: "Take vitamins", missedCount: 0, schedulePeriod: 1, scheduleUnit: "Days", 
                      creationDate: Date(), lastCompletedDate: nil, isRepeating: true),
        WidgetTaskData(name: "Water plants in the living room", missedCount: 2, schedulePeriod: 3, scheduleUnit: "Days", 
                      creationDate: Date().addingTimeInterval(-86400 * 10), lastCompletedDate: nil, isRepeating: true)
    ])
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), tasks: [])
}

#Preview("Inline", as: .accessoryInline) {
    VenjaLockScreenWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), tasks: [
        WidgetTaskData(name: "Take vitamins", missedCount: 1, schedulePeriod: 1, scheduleUnit: "Days", 
                      creationDate: Date(), lastCompletedDate: nil, isRepeating: true)
    ])
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), tasks: [])
}