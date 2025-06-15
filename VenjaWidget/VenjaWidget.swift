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
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent(), task: nil)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let task = await fetchFirstActiveTask()
        return SimpleEntry(date: Date(), configuration: configuration, task: task)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []
        
        let currentDate = Date()
        let calendar = Calendar.current
        
        // Create entries for the next 24 hours at specific intervals
        // First entry is immediate
        let task = await fetchFirstActiveTask()
        entries.append(SimpleEntry(date: currentDate, configuration: configuration, task: task))
        
        // Add entries every 30 minutes for the next 4 hours
        for halfHourOffset in 1...8 {
            if let entryDate = calendar.date(byAdding: .minute, value: halfHourOffset * 30, to: currentDate) {
                let task = await fetchFirstActiveTask()
                entries.append(SimpleEntry(date: entryDate, configuration: configuration, task: task))
            }
        }
        
        // Add an entry at midnight to refresh for the new day
        if let tomorrow = calendar.dateInterval(of: .day, for: currentDate)?.end {
            let task = await fetchFirstActiveTask()
            entries.append(SimpleEntry(date: tomorrow, configuration: configuration, task: task))
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
    let task: WidgetTaskData?
}

struct WidgetTaskData: Codable {
    let name: String
    let missedCount: Int
    let schedulePeriod: Int
    let scheduleUnit: String
}

struct VenjaWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        if let task = entry.task {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(.headline)
                    .foregroundColor(task.missedCount > 0 ? .white : .primary)
                    .lineLimit(2)
                
                if task.missedCount > 0 {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                        Text("Missed \(task.missedCount)")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.green)
                Text("Done!")
                    .font(.headline)
                    .foregroundColor(.green)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct VenjaWidget: Widget {
    let kind: String = "VenjaWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            VenjaWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    if let _ = entry.task {
                        Color.red
                    }
                    else {
                        RoundedRectangle(cornerRadius: 21)
                            .stroke(.green, lineWidth: 4)
                    }
                }
        }
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}


extension Provider {
    func fetchFirstActiveTask() async -> WidgetTaskData? {
        // Read task data from UserDefaults shared between app and widget
        let userDefaults = UserDefaults(suiteName: "group.net.kodare.Venja") ?? UserDefaults.standard
        
        guard let taskData = userDefaults.data(forKey: "currentTask"),
              let task = try? JSONDecoder().decode(WidgetTaskData.self, from: taskData) else {
            return nil
        }
        
        return task
    }
}

#Preview(as: .systemSmall) {
    VenjaWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), task: WidgetTaskData(name: "Take vitamins", missedCount: 0, schedulePeriod: 1, scheduleUnit: "Days"))
    SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), task: nil)
}
