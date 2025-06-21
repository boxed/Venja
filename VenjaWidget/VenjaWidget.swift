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
        
        // Create entries for the next 24 hours at specific intervals
        // First entry is immediate
        let tasks = await fetchActiveTasks()
        entries.append(SimpleEntry(date: currentDate, configuration: configuration, tasks: tasks))
        
        // Add entries every 30 minutes for the next 4 hours
        for halfHourOffset in 1...8 {
            if let entryDate = calendar.date(byAdding: .minute, value: halfHourOffset * 30, to: currentDate) {
                let tasks = await fetchActiveTasks()
                entries.append(SimpleEntry(date: entryDate, configuration: configuration, tasks: tasks))
            }
        }
        
        // Add an entry at midnight to refresh for the new day
        if let tomorrow = calendar.dateInterval(of: .day, for: currentDate)?.end {
            let tasks = await fetchActiveTasks()
            entries.append(SimpleEntry(date: tomorrow, configuration: configuration, tasks: tasks))
        }
        
        // Use after policy to refresh 30 minutes after the last entry
        let lastEntryDate = entries.last?.date ?? currentDate
        let refreshDate = calendar.date(byAdding: .minute, value: 30, to: lastEntryDate) ?? lastEntryDate
        
        return Timeline(entries: entries, policy: .after(refreshDate))
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
}

struct VenjaWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var widgetFamily
    
    var maxTasksToShow: Int {
        switch widgetFamily {
        case .systemSmall:
            return 3
        case .systemMedium:
            return 5
        case .systemLarge:
            return 12
        default:
            return 3
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
                                .foregroundColor(.white)
                        }
                        
                        Text(task.name)
                            .font(widgetFamily == .systemSmall ? .body : .title3)
                            .foregroundColor(task.missedCount > 0 ? .white : .primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                if entry.tasks.count > maxTasksToShow {
                    Text("+\(entry.tasks.count - maxTasksToShow) more")
                        .font(.footnote)
                        .foregroundColor(.secondary)
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
    func fetchActiveTasks() async -> [WidgetTaskData] {
        // Read task data from UserDefaults shared between app and widget
        let userDefaults = UserDefaults(suiteName: "group.net.kodare.Venja") ?? UserDefaults.standard
        
        guard let tasksData = userDefaults.data(forKey: "activeTasks"),
              let tasks = try? JSONDecoder().decode([WidgetTaskData].self, from: tasksData) else {
            return []
        }
        
        return tasks
    }
}

#Preview(as: .systemSmall) {
    VenjaWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), tasks: [
        WidgetTaskData(name: "Take vitamins", missedCount: 0, schedulePeriod: 1, scheduleUnit: "Days"),
        WidgetTaskData(name: "Water plants in the living room and check soil moisture", missedCount: 2, schedulePeriod: 3, scheduleUnit: "Days"),
        WidgetTaskData(name: "Clean bathroom", missedCount: 0, schedulePeriod: 1, scheduleUnit: "Weeks")
    ])
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), tasks: [
        WidgetTaskData(name: "Take vitamins with a long title", missedCount: 0, schedulePeriod: 1, scheduleUnit: "Days"),
        WidgetTaskData(name: "Water plants in the living room and check soil moisture", missedCount: 2, schedulePeriod: 3, scheduleUnit: "Days"),
        WidgetTaskData(name: "Clean bathroom", missedCount: 0, schedulePeriod: 1, scheduleUnit: "Weeks")
    ])
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), tasks: [
        WidgetTaskData(name: "Take vitamins", missedCount: 0, schedulePeriod: 1, scheduleUnit: "Days")
    ])
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), tasks: [])
}
