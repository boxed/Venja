//
//  VenjaWidget.swift
//  VenjaWidget
//
//  Created by Anders Hovmöller on 2025-06-08.
//

import WidgetKit
import SwiftUI
import SwiftData

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent(), tasks: [], isPlaceholder: true)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let tasks = await fetchActiveTasks()
        return SimpleEntry(date: Date(), configuration: configuration, tasks: tasks)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let currentDate = Date()
        let calendar = Calendar.current

        // Fetch current tasks
        let allTasks = await fetchAllTasks()
        let activeTasks = allTasks.filter { task in
            task.isActiveForDate(currentDate)
        }.sorted { task1, task2 in
            // Sort by missed count (descending), then by next due date (ascending)
            if task1.missedCount != task2.missedCount {
                return task1.missedCount > task2.missedCount
            }
            return task1.nextDueDate < task2.nextDueDate
        }

        // Create single entry for current state
        let entry = SimpleEntry(date: currentDate, configuration: configuration, tasks: activeTasks)

        // Calculate when to reload the timeline
        let startOfTomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: currentDate)!)

        // Find the next task that will become due (for intra-day scheduling)
        let nextTaskDueDate = allTasks
            .filter { !$0.isActiveForDate(currentDate) }
            .map { $0.nextDueDate }
            .filter { $0 > currentDate }
            .min()

        // Reload timeline at: next task due time, midnight, or in 4 hours - whichever comes first
        var nextUpdate = min(startOfTomorrow, currentDate.addingTimeInterval(4 * 3600))
        if let nextDue = nextTaskDueDate {
            nextUpdate = min(nextUpdate, nextDue)
        }

        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

//    func relevances() async -> WidgetRelevances<ConfigurationAppIntent> {
//        // Generate a list containing the contexts this widget is relevant in.
//    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let tasks: [WidgetTaskData]
    var isPlaceholder: Bool = false
}

struct WidgetTaskData: Codable {
    let name: String
    let missedCount: Int
    let schedulePeriod: Int
    let scheduleUnit: String
    let creationDate: Date
    let lastCompletedDate: Date?
    let isRepeating: Bool
    let totalPoints: Int
    let scheduledHour: Int

    var nextDueDate: Date {
        let calendar = Calendar.current

        if !isRepeating {
            let baseDate = lastCompletedDate != nil ? Date.distantFuture : creationDate
            var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
            components.hour = scheduledHour
            components.minute = 0
            components.second = 0
            return calendar.date(from: components) ?? baseDate
        }

        let referenceDate = lastCompletedDate ?? creationDate

        let component: Calendar.Component
        switch scheduleUnit {
        case "Days":
            component = .day
        case "Weeks":
            component = .weekOfYear
        case "Months":
            component = .month
        case "Years":
            component = .year
        default:
            component = .day
        }

        guard let nextDate = calendar.date(byAdding: component, value: schedulePeriod, to: referenceDate) else {
            return referenceDate
        }

        var components = calendar.dateComponents([.year, .month, .day], from: nextDate)
        components.hour = scheduledHour
        components.minute = 0
        components.second = 0

        guard var result = calendar.date(from: components) else {
            return nextDate
        }

        // If setting the hour caused the date to be before or equal to the reference date,
        // advance by another period to ensure we're always moving forward
        while result <= referenceDate {
            guard let advanced = calendar.date(byAdding: component, value: schedulePeriod, to: result) else {
                break
            }
            result = advanced
        }

        return result
    }
    
    var isOverdue: Bool {
        if !isRepeating && lastCompletedDate != nil {
            return false
        }
        return nextDueDate < Date()
    }
    
    func isActiveForDate(_ date: Date) -> Bool {
        if !isRepeating && lastCompletedDate != nil {
            return false
        }
        // Task is active if its due date has passed (respects scheduledHour for intra-day scheduling)
        return nextDueDate <= date
    }
}

struct VenjaWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var widgetFamily
    @Environment(\.colorScheme) var colorScheme
    
    var maxTasksToShow: Int {
        switch widgetFamily {
        case .systemSmall:
            return 4
        case .systemMedium:
            return 5
        case .systemLarge:
            return 12
        default:
            return 3
        }
    }
    
    var textColor: Color {
        return if colorScheme == ColorScheme.dark {
            Color.black
        } else {
            Color.white
        }
    }

    var body: some View {
        if entry.isPlaceholder {
            Color.clear
        } else if !entry.tasks.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(entry.tasks.prefix(maxTasksToShow).enumerated()), id: \.offset) { index, task in
                    HStack(spacing: 4) {
                        if task.missedCount > 0 {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(widgetFamily == .systemSmall ? .footnote : .body)
                                .foregroundColor(textColor)
                        }
                        
                        Text(task.name)
                            .font(widgetFamily == .systemSmall ? .body : .title3)
                            .foregroundColor(textColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                if entry.tasks.count > maxTasksToShow {
                    Text("+\(entry.tasks.count - maxTasksToShow) more")
                        .font(.footnote)
                        .foregroundColor(textColor)
                        .minimumScaleFactor(0.7)
                }
                
                Spacer(minLength: 0)
            }
            .padding(0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            GeometryReader { geometry in
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.4))
                        .foregroundColor(.green)
                    Text("Done!")
                        .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.2))
                        .foregroundColor(.green)
                        .minimumScaleFactor(0.5)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct VenjaWidget: Widget {
    let kind: String = "VenjaWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            VenjaWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    if entry.tasks.contains(where: { $0.missedCount > 0 }) {
                        Color.red
                    }
                    else if entry.tasks.isEmpty {
                        RoundedRectangle(cornerRadius: 21)
                            .stroke(.green, lineWidth: 4)
                    }
                    else {
                        Color.orange
                    }
                }
        }
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}


extension Provider {
    func fetchAllTasks() async -> [WidgetTaskData] {
        // Read task data from UserDefaults shared between app and widget
        let userDefaults = UserDefaults(suiteName: "group.net.kodare.Venja") ?? UserDefaults.standard
        
        // Try new key first, fall back to old key for backward compatibility
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
        
        // Filter for active tasks based on the current date
        let currentDate = Date()
        let activeTasks = tasks.filter { task in
            task.isActiveForDate(currentDate)
        }.sorted { task1, task2 in
            // Sort by missed count (descending), then by next due date (ascending)
            if task1.missedCount != task2.missedCount {
                return task1.missedCount > task2.missedCount
            }
            return task1.nextDueDate < task2.nextDueDate
        }
        
        return activeTasks
    }
}

#Preview(as: .systemSmall) {
    VenjaWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), tasks: [
        WidgetTaskData(name: "Take vitamins", missedCount: 0, schedulePeriod: 1, scheduleUnit: "Days", 
                      creationDate: Date(), lastCompletedDate: nil, isRepeating: true, totalPoints: 25, scheduledHour: 0),
        WidgetTaskData(name: "Water plants in the living room and check soil moisture", missedCount: 2, 
                      schedulePeriod: 3, scheduleUnit: "Days", creationDate: Date().addingTimeInterval(-86400 * 10), 
                      lastCompletedDate: nil, isRepeating: true, totalPoints: 15, scheduledHour: 0),
        WidgetTaskData(name: "Clean bathroom", missedCount: 0, schedulePeriod: 1, scheduleUnit: "Weeks", 
                      creationDate: Date(), lastCompletedDate: nil, isRepeating: true, totalPoints: 10, scheduledHour: 0),
        WidgetTaskData(name: "Clean bathroom", missedCount: 0, schedulePeriod: 1, scheduleUnit: "Weeks",
                      creationDate: Date(), lastCompletedDate: nil, isRepeating: true, totalPoints: 10, scheduledHour: 0),
        WidgetTaskData(name: "Clean bathroom", missedCount: 0, schedulePeriod: 1, scheduleUnit: "Weeks",
                      creationDate: Date(), lastCompletedDate: nil, isRepeating: true, totalPoints: 10, scheduledHour: 0)
    ])
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), tasks: [
        WidgetTaskData(name: "Take vitamins with a long title", missedCount: 0, schedulePeriod: 1, 
                      scheduleUnit: "Days", creationDate: Date(), lastCompletedDate: nil, isRepeating: true, totalPoints: 20, scheduledHour: 0),
        WidgetTaskData(name: "Water plants in the living room and check soil moisture", missedCount: 2, 
                      schedulePeriod: 3, scheduleUnit: "Days", creationDate: Date().addingTimeInterval(-86400 * 10), 
                      lastCompletedDate: nil, isRepeating: true, totalPoints: 15, scheduledHour: 0),
        WidgetTaskData(name: "Clean bathroom", missedCount: 0, schedulePeriod: 1, scheduleUnit: "Weeks", 
                      creationDate: Date(), lastCompletedDate: nil, isRepeating: true, totalPoints: 10, scheduledHour: 0)
    ])
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), tasks: [
        WidgetTaskData(name: "Take vitamins", missedCount: 0, schedulePeriod: 1, scheduleUnit: "Days", 
                      creationDate: Date(), lastCompletedDate: nil, isRepeating: true, totalPoints: 25, scheduledHour: 0)
    ])
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), tasks: [])
}
