//
//  Task.swift
//  Venja
//
//  Created by Anders Hovmöller on 2025-06-08.
//

import Foundation
import SwiftData

enum ScheduleUnit: String, Codable, CaseIterable {
    case days = "Days"
    case weeks = "Weeks"
    case months = "Months"
    case years = "Years"
    
    var calendarComponent: Calendar.Component {
        switch self {
        case .days:
            return .day
        case .weeks:
            return .weekOfYear
        case .months:
            return .month
        case .years:
            return .year
        }
    }
}

@Model
final class VTask {
    var name: String = ""
    var schedulePeriod: Int = 0
    private var scheduleUnitRawValue: String = ScheduleUnit.days.rawValue
    var creationDate: Date = Date()
    var lastCompletedDate: Date? = nil
    var missedCount: Int = 0
    var isRepeating: Bool = true
    var scheduledHour: Int = 0  // Hour of day (0-23) when task is scheduled, default midnight
    @Relationship(deleteRule: .cascade, inverse: \CompletionHistory.task)
    var completionHistory: [CompletionHistory]? = []
    
    var scheduleUnit: ScheduleUnit {
        get {
            ScheduleUnit(rawValue: scheduleUnitRawValue) ?? .days
        }
        set {
            scheduleUnitRawValue = newValue.rawValue
        }
    }
    
    init(name: String, schedulePeriod: Int, scheduleUnit: ScheduleUnit, creationDate: Date = Date(), isRepeating: Bool = true, scheduledHour: Int = 0) {
        self.name = name
        self.schedulePeriod = schedulePeriod
        self.scheduleUnitRawValue = scheduleUnit.rawValue
        self.creationDate = creationDate
        self.lastCompletedDate = nil
        self.missedCount = 0
        self.isRepeating = isRepeating
        self.scheduledHour = scheduledHour
    }
    
    var nextDueDate: Date {
        let calendar = Calendar.current

        if !isRepeating {
            // For non-repeating tasks, they're due on creation date if not completed
            let baseDate = lastCompletedDate != nil ? Date.distantFuture : creationDate
            // Set the hour to scheduledHour
            var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
            components.hour = scheduledHour
            components.minute = 0
            components.second = 0
            return calendar.date(from: components) ?? baseDate
        }

        let referenceDate = lastCompletedDate ?? creationDate

        switch scheduleUnit {
        case .days:
            // For days, advance from reference date
            var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
            components.hour = scheduledHour
            components.minute = 0
            components.second = 0

            guard var result = calendar.date(from: components) else {
                return referenceDate
            }

            while result <= referenceDate {
                guard let advanced = calendar.date(byAdding: .day, value: schedulePeriod, to: result) else {
                    break
                }
                result = advanced
            }

            return result

        case .weeks:
            // For weeks, respect the target weekday encoded in creationDate
            let targetWeekday = calendar.component(.weekday, from: creationDate)

            // Get the week containing the reference date and set to target weekday
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: referenceDate)
            components.weekday = targetWeekday
            components.hour = scheduledHour
            components.minute = 0
            components.second = 0

            guard var result = calendar.date(from: components) else {
                return referenceDate
            }

            // Advance by schedulePeriod weeks until we're past the reference date
            while result <= referenceDate {
                guard let advanced = calendar.date(byAdding: .weekOfYear, value: schedulePeriod, to: result) else {
                    break
                }
                result = advanced
            }

            return result

        case .months:
            // For months, respect the target day-of-month encoded in creationDate
            let targetDay = calendar.component(.day, from: creationDate)

            var components = calendar.dateComponents([.year, .month], from: referenceDate)
            // Handle months with fewer days than target
            let maxDay = calendar.range(of: .day, in: .month, for: referenceDate)?.count ?? 28
            components.day = min(targetDay, maxDay)
            components.hour = scheduledHour
            components.minute = 0
            components.second = 0

            guard var result = calendar.date(from: components) else {
                return referenceDate
            }

            while result <= referenceDate {
                guard let advanced = calendar.date(byAdding: .month, value: schedulePeriod, to: result) else {
                    break
                }
                // Re-adjust day for the new month's length
                let advancedMaxDay = calendar.range(of: .day, in: .month, for: advanced)?.count ?? 28
                var newComponents = calendar.dateComponents([.year, .month], from: advanced)
                newComponents.day = min(targetDay, advancedMaxDay)
                newComponents.hour = scheduledHour
                newComponents.minute = 0
                newComponents.second = 0
                result = calendar.date(from: newComponents) ?? advanced
            }

            return result

        case .years:
            // For years, respect the target month and day encoded in creationDate
            let targetMonth = calendar.component(.month, from: creationDate)
            let targetDay = calendar.component(.day, from: creationDate)

            var components = calendar.dateComponents([.year], from: referenceDate)
            components.month = targetMonth
            components.day = targetDay
            components.hour = scheduledHour
            components.minute = 0
            components.second = 0

            guard var result = calendar.date(from: components) else {
                return referenceDate
            }

            while result <= referenceDate {
                guard let advanced = calendar.date(byAdding: .year, value: schedulePeriod, to: result) else {
                    break
                }
                result = advanced
            }

            return result
        }
    }
    
    var isOverdue: Bool {
        if !isRepeating && lastCompletedDate != nil {
            // Completed non-repeating tasks are never overdue
            return false
        }
        return nextDueDate < Date()
    }
    
    var daysOverdue: Int {
        guard isOverdue else { return 0 }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: nextDueDate, to: Date())
        return components.day ?? 0
    }
    
    func markCompleted(at date: Date = Date()) {
        let historyEntry = CompletionHistory(
            completionDate: date,
            missedCountAtCompletion: missedCount
        )
        completionHistory!.append(historyEntry)
        
        lastCompletedDate = date
        missedCount = 0
    }
    
    func undoCompletion(previousDate: Date?, previousMissedCount: Int) {
        if !completionHistory!.isEmpty {
            completionHistory!.removeLast()
        }
        lastCompletedDate = previousDate
        missedCount = previousMissedCount
    }
    
    func updateMissedCount(currentDate: Date = Date()) {
        // Non-repeating tasks don't have missed counts
        if !isRepeating {
            missedCount = 0
            return
        }

        let dueDate = nextDueDate
        guard dueDate < currentDate else {
            missedCount = 0
            return
        }

        let calendar = Calendar.current

        // Calculate based on the schedule unit - from due date, not reference date
        let unitsElapsed: Int
        switch scheduleUnit {
        case .days:
            let components = calendar.dateComponents([.day], from: dueDate, to: currentDate)
            unitsElapsed = components.day ?? 0
        case .weeks:
            let components = calendar.dateComponents([.day], from: dueDate, to: currentDate)
            let days = components.day ?? 0
            unitsElapsed = days / 7
        case .months:
            let components = calendar.dateComponents([.month], from: dueDate, to: currentDate)
            unitsElapsed = components.month ?? 0
        case .years:
            let components = calendar.dateComponents([.year], from: dueDate, to: currentDate)
            unitsElapsed = components.year ?? 0
        }

        // Missed count is how many complete periods have passed since due date
        missedCount = max(0, unitsElapsed / schedulePeriod)
    }
    
    var totalPoints: Int {
        completionHistory!.reduce(0) { $0 + $1.points }
    }
    
    var averagePoints: Double {
        guard !completionHistory!.isEmpty else { return 0 }
        return Double(totalPoints) / Double(completionHistory!.count)
    }
}
