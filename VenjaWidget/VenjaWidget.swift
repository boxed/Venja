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
        // Delegate to the shared scheduling logic in Task.swift (compiled into
        // this widget target) so the widget can never diverge from the app.
        computeNextDueDate(
            isRepeating: isRepeating,
            schedulePeriod: schedulePeriod,
            scheduleUnit: ScheduleUnit(rawValue: scheduleUnit) ?? .days,
            creationDate: creationDate,
            lastCompletedDate: lastCompletedDate,
            scheduledHour: scheduledHour
        )
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
    @Environment(\.widgetRenderingMode) var renderingMode
    
    var maxTasksToShow: Int {
        switch widgetFamily {
        case .systemSmall:
            return 4
        case .systemMedium, .systemLarge:
            return 5
        default:
            return 3
        }
    }
    
    var textColor: Color {
        // Outside full color (macOS desktop widgets go .vibrant when the desktop
        // isn't revealed, iOS tinting goes .accented) the system re-renders the
        // widget from luminance alone, so dark content vanishes into the plate.
        guard renderingMode == .fullColor else {
            return .white
        }
        // The colored plate (orange for missed) needs a fixed high-contrast
        // color; the neutral plate uses the standard label color.
        if missedTaskCount > 0 {
            return colorScheme == ColorScheme.dark ? Color.black : Color.white
        }
        return .primary
    }

    var doneColor: Color {
        renderingMode == .fullColor ? Color(red: 0x70 / 255, green: 0x8F / 255, blue: 0xA8 / 255) : .white
    }

    var missedTaskCount: Int {
        entry.tasks.filter { $0.missedCount > 0 }.count
    }

    // Content margins are disabled on the configuration; the system defaults
    // are too generous for a list widget, so the plate padding lives here.
    var contentPadding: CGFloat {
        16
    }

    var body: some View {
        if entry.isPlaceholder {
            Color.clear
        } else if !entry.tasks.isEmpty {
            if widgetFamily == .systemMedium || widgetFamily == .systemLarge {
                bigNumberLayout
                    .padding(contentPadding)
            } else {
                taskList
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(contentPadding)
            }
        } else {
            GeometryReader { geometry in
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.38))
                    .foregroundColor(doneColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// Poster-scale count as the hero, with the task list beside it.
    var bigNumberLayout: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(missedTaskCount > 0 ? missedTaskCount : entry.tasks.count)")
                    .font(.system(size: widgetFamily == .systemLarge ? 130 : 88, weight: .heavy))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                Text(missedTaskCount > 0 ? "MISSED" : "to do")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(missedTaskCount > 0 ? 0.8 : 0)
                    .foregroundColor(textColor.opacity(0.8))
            }
            .fixedSize(horizontal: true, vertical: false)

            Rectangle()
                .fill(textColor.opacity(0.35))
                .frame(width: 1.5)
                .padding(.vertical, 6)

            taskList
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    var taskList: some View {
        VStack(alignment: .leading, spacing: 7) {
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
                        // Long names should truncate with an ellipsis, not
                        // shrink into unreadably tiny text.
                        .minimumScaleFactor(0.9)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if entry.tasks.count > maxTasksToShow {
                Text("+\(entry.tasks.count - maxTasksToShow) more")
                    .font(.footnote)
                    .foregroundColor(textColor)
            }

            if widgetFamily == .systemSmall {
                Spacer(minLength: 0)
            }
        }
    }
}

/// The widget's plate. Saturated fills only work in `.fullColor`; in `.vibrant`
/// and `.accented` the system collapses them to a single flat tone (a solid
/// #262626 blob on the macOS desktop), hiding the task list entirely. In those
/// modes we hand over to the system material and let the text carry the content.
struct VenjaWidgetBackground: View {
    let hasMissed: Bool
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        if renderingMode == .fullColor {
            if hasMissed {
                Color.orange
            }
            else {
                Rectangle()
                    .fill(.background)
            }
        }
        else {
            Rectangle()
                .fill(.fill.tertiary)
        }
    }
}

struct VenjaWidget: Widget {
    let kind: String = "VenjaWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            VenjaWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    VenjaWidgetBackground(
                        hasMissed: entry.tasks.contains(where: { $0.missedCount > 0 })
                    )
                }
        }
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
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
