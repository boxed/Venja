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
        
        // Fetch ALL tasks once, not just currently active
        let allTasks = await fetchAllTasks()
        
        // Helper function to get active tasks for a specific date
        func getActiveTasksForDate(_ date: Date) -> [WidgetTaskData] {
            return allTasks.filter { task in
                task.isActiveForDate(date)
            }.sorted { task1, task2 in
                // Sort by missed count (descending), then by next due date (ascending)
                if task1.missedCount != task2.missedCount {
                    return task1.missedCount > task2.missedCount
                }
                return task1.nextDueDate < task2.nextDueDate
            }
        }
        
        // First entry is immediate with current tasks
        let currentTasks = getActiveTasksForDate(currentDate)
        entries.append(SimpleEntry(date: currentDate, configuration: configuration, tasks: currentTasks))
        
        // Calculate midnight for today and tomorrow
        let startOfToday = calendar.startOfDay(for: currentDate)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        
        // If we haven't passed midnight yet today, add an entry for midnight
        if currentDate < startOfTomorrow {
            // Add an entry 1 second after midnight to ensure new day calculation
            let justAfterMidnight = startOfTomorrow.addingTimeInterval(1)
            let midnightTasks = getActiveTasksForDate(justAfterMidnight)
            entries.append(SimpleEntry(date: justAfterMidnight, configuration: configuration, tasks: midnightTasks))
        }
        
        // Add entries for the next few midnights (up to 3 days)
        for dayOffset in 1...3 {
            if let futureDay = calendar.date(byAdding: .day, value: dayOffset, to: startOfTomorrow) {
                let justAfterMidnight = futureDay.addingTimeInterval(1)
                let futureTasks = getActiveTasksForDate(justAfterMidnight)
                entries.append(SimpleEntry(date: justAfterMidnight, configuration: configuration, tasks: futureTasks))
            }
        }
        
        // Also add some entries during the day for responsiveness
        // Add entries every 2 hours for today
        var nextUpdate = currentDate
        while nextUpdate < startOfTomorrow {
            nextUpdate = calendar.date(byAdding: .hour, value: 2, to: nextUpdate) ?? startOfTomorrow
            if nextUpdate < startOfTomorrow {
                let updateTasks = getActiveTasksForDate(nextUpdate)
                entries.append(SimpleEntry(date: nextUpdate, configuration: configuration, tasks: updateTasks))
            }
        }
        
        // Sort entries by date and remove duplicates
        entries.sort { $0.date < $1.date }
        entries = entries.reduce(into: [SimpleEntry]()) { result, entry in
            if result.isEmpty || abs(result.last!.date.timeIntervalSince(entry.date)) > 60 {
                result.append(entry)
            }
        }
        
        // Use atEnd policy to ensure we get called again when entries run out
        return Timeline(entries: entries, policy: .atEnd)
    }

//    func relevances() async -> WidgetRelevances<ConfigurationAppIntent> {
//        // Generate a list containing the contexts this widget is relevant in.
//    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let tasks: [WidgetTaskData]
}

struct WidgetTaskData: Codable {
    let name: String
    let missedCount: Int
    let schedulePeriod: Int
    let scheduleUnit: String
    let creationDate: Date
    let lastCompletedDate: Date?
    let isRepeating: Bool
    
    var nextDueDate: Date {
        if !isRepeating {
            return lastCompletedDate != nil ? Date.distantFuture : creationDate
        }
        
        let referenceDate = lastCompletedDate ?? creationDate
        let calendar = Calendar.current
        
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
        
        return calendar.date(byAdding: component, value: schedulePeriod, to: referenceDate) ?? referenceDate
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
        let calendar = Calendar.current
        return calendar.isDate(nextDueDate, inSameDayAs: date) || (nextDueDate < date)
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
        if !entry.tasks.isEmpty {
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
                      creationDate: Date(), lastCompletedDate: nil, isRepeating: true),
        WidgetTaskData(name: "Water plants in the living room and check soil moisture", missedCount: 2, 
                      schedulePeriod: 3, scheduleUnit: "Days", creationDate: Date().addingTimeInterval(-86400 * 10), 
                      lastCompletedDate: nil, isRepeating: true),
        WidgetTaskData(name: "Clean bathroom", missedCount: 0, schedulePeriod: 1, scheduleUnit: "Weeks", 
                      creationDate: Date(), lastCompletedDate: nil, isRepeating: true),
        WidgetTaskData(name: "Clean bathroom", missedCount: 0, schedulePeriod: 1, scheduleUnit: "Weeks",
                      creationDate: Date(), lastCompletedDate: nil, isRepeating: true),
        WidgetTaskData(name: "Clean bathroom", missedCount: 0, schedulePeriod: 1, scheduleUnit: "Weeks",
                      creationDate: Date(), lastCompletedDate: nil, isRepeating: true)
    ])
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), tasks: [
        WidgetTaskData(name: "Take vitamins with a long title", missedCount: 0, schedulePeriod: 1, 
                      scheduleUnit: "Days", creationDate: Date(), lastCompletedDate: nil, isRepeating: true),
        WidgetTaskData(name: "Water plants in the living room and check soil moisture", missedCount: 2, 
                      schedulePeriod: 3, scheduleUnit: "Days", creationDate: Date().addingTimeInterval(-86400 * 10), 
                      lastCompletedDate: nil, isRepeating: true),
        WidgetTaskData(name: "Clean bathroom", missedCount: 0, schedulePeriod: 1, scheduleUnit: "Weeks", 
                      creationDate: Date(), lastCompletedDate: nil, isRepeating: true)
    ])
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), tasks: [
        WidgetTaskData(name: "Take vitamins", missedCount: 0, schedulePeriod: 1, scheduleUnit: "Days", 
                      creationDate: Date(), lastCompletedDate: nil, isRepeating: true)
    ])
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), tasks: [])
}
