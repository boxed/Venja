//
//  VenjaWidgetControl.swift
//  VenjaWidget
//
//  Created by Anders Hovmöller on 2025-06-08.
//

// ControlWidget (Control Center / Lock Screen controls) is iOS-only.
#if os(iOS)

import AppIntents
import SwiftUI
import WidgetKit

struct VenjaWidgetControl: ControlWidget {
    static let kind: String = "net.kodare.Venja.VenjaWidget"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: Self.kind,
            provider: Provider()
        ) { value in
            ControlWidgetButton(action: OpenVenjaIntent()) {
                Label(value.label, systemImage: value.symbol)
            }
        }
        .displayName("Venja Tasks")
        .description("Shows how many tasks are due and opens Venja.")
    }
}

extension VenjaWidgetControl {
    struct Value {
        var dueCount: Int

        var label: String {
            dueCount == 0 ? "All done" : "\(dueCount) due"
        }

        /// A cluster-of-circles SF Symbol that evokes the accessory widget's ring,
        /// falling back to a checkmark when nothing is due.
        var symbol: String {
            dueCount == 0 ? "checkmark.circle" : "circle.hexagongrid.fill"
        }
    }

    struct Provider: ControlValueProvider {
        var previewValue: Value {
            Value(dueCount: 3)
        }

        func currentValue() async throws -> Value {
            let now = Date()
            let active = loadWidgetTasks().filter { $0.isActiveForDate(now) }
            return Value(dueCount: active.count)
        }
    }
}

/// Reads the shared task snapshot the main app writes to the app group.
private func loadWidgetTasks() -> [WidgetTaskData] {
    let userDefaults = UserDefaults(suiteName: "group.net.kodare.Venja") ?? UserDefaults.standard

    // Try new key first, fall back to old key for backward compatibility.
    let data = userDefaults.data(forKey: "allTasks") ?? userDefaults.data(forKey: "activeTasks")
    guard let data, let tasks = try? JSONDecoder().decode([WidgetTaskData].self, from: data) else {
        return []
    }
    return tasks
}

#endif
