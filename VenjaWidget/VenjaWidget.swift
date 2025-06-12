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

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let task = await fetchFirstActiveTask()
            let entry = SimpleEntry(date: entryDate, configuration: configuration, task: task)
            entries.append(entry)
        }

        return Timeline(entries: entries, policy: .atEnd)
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
//                .containerBackground(entry.task?.missedCount ?? 0 > 0 ? Color.red : Color(UIColor.tertiarySystemFill), for: .widget)
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
