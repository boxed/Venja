//
//  VenjaLockScreenWidget.swift
//  VenjaWidget
//
//  Lock screen widget for Venja
//

// The accessory widget families only exist on iOS.
#if os(iOS)

import WidgetKit
import SwiftUI

struct VenjaLockScreenWidgetCircularView: View {
    var entry: SimpleEntry

    private func circlePosition(for index: Int, total: Int, radius: CGFloat) -> CGPoint {
        let angle = (2 * .pi / CGFloat(total)) * CGFloat(index) - .pi / 2
        let x = radius * cos(angle)
        let y = radius * sin(angle)
        return CGPoint(x: x, y: y)
    }

    var body: some View {
        if entry.isPlaceholder || entry.tasks.isEmpty {
            Color.clear
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
        if entry.isPlaceholder || entry.tasks.isEmpty {
            Color.clear
        } else {
            let missedCount = entry.tasks.filter { $0.missedCount > 0 }.count
            HStack(spacing: 8) {
                Text("\(missedCount > 0 ? missedCount : entry.tasks.count)")
                    .font(.system(size: 40, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Rectangle()
                    .frame(width: 1)
                    .opacity(0.4)
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 0) {
                    if missedCount > 0 {
                        Text("MISSED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .opacity(0.8)
                    }

                    ForEach(Array(entry.tasks.prefix(missedCount > 0 ? 2 : 3).enumerated()), id: \.offset) { _, task in
                        Text(task.name)
                            .font(.caption2)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .widgetAccentable()
        }
    }
}

struct VenjaLockScreenWidgetInlineView: View {
    var entry: SimpleEntry

    var body: some View {
        if entry.isPlaceholder || entry.tasks.isEmpty {
            Color.clear
        } else {
            let missedCount = entry.tasks.filter { $0.missedCount > 0 }.count
            let firstName = entry.tasks.first?.name ?? ""
            if missedCount > 0 {
                Label {
                    Text("\(missedCount) missed · \(firstName)")
                } icon: {
                    Image(systemName: "exclamationmark.circle.fill")
                }
            } else if entry.tasks.count == 1 {
                Text(firstName)
            } else {
                Text("\(entry.tasks.count) · \(firstName)")
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
        // Uses the same Provider as the home screen widget: it reads the task
        // snapshot the app writes to the shared app group UserDefaults. A
        // SwiftData container opened inside the widget extension would see the
        // extension's own (empty) store, not the app's.
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            VenjaLockScreenWidgetEntryView(entry: entry)
        }
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
        .configurationDisplayName("Venja Tasks")
        .description("View your pending tasks on the lock screen")
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

#endif
