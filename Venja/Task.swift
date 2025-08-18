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
    @Relationship(deleteRule: .cascade, inverse: \CompletionHistory.task)
    var completionHistory: [CompletionHistory] = []
    
    var scheduleUnit: ScheduleUnit {
        get {
            ScheduleUnit(rawValue: scheduleUnitRawValue) ?? .days
        }
        set {
            scheduleUnitRawValue = newValue.rawValue
        }
    }
    
    init(name: String, schedulePeriod: Int, scheduleUnit: ScheduleUnit, creationDate: Date = Date(), isRepeating: Bool = true) {
        self.name = name
        self.schedulePeriod = schedulePeriod
        self.scheduleUnitRawValue = scheduleUnit.rawValue
        self.creationDate = creationDate
        self.lastCompletedDate = nil
        self.missedCount = 0
        self.isRepeating = isRepeating
    }
    
    var nextDueDate: Date {
        if !isRepeating {
            // For non-repeating tasks, they're due on creation date if not completed
            return lastCompletedDate != nil ? Date.distantFuture : creationDate
        }
        
        let referenceDate = lastCompletedDate ?? creationDate
        let calendar = Calendar.current
        
        return calendar.date(byAdding: scheduleUnit.calendarComponent, value: schedulePeriod, to: referenceDate) ?? referenceDate
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
    
    func markCompleted() {
        let historyEntry = CompletionHistory(
            completionDate: Date(),
            missedCountAtCompletion: missedCount
        )
        completionHistory.append(historyEntry)
        
        lastCompletedDate = Date()
        missedCount = 0
    }
    
    func undoCompletion(previousDate: Date?, previousMissedCount: Int) {
        if !completionHistory.isEmpty {
            completionHistory.removeLast()
        }
        lastCompletedDate = previousDate
        missedCount = previousMissedCount
    }
    
    func updateMissedCount() {
        // Non-repeating tasks don't have missed counts
        if !isRepeating {
            missedCount = 0
            return
        }
        
        guard isOverdue else {
            missedCount = 0
            return
        }
        
        // For daily tasks, calculate based on days overdue
        if scheduleUnit == .days {
            if schedulePeriod == 1 {
                // For single-day tasks, if we're overdue but daysOverdue is 0 (less than 24h), count it as 1
                missedCount = daysOverdue == 0 ? 1 : daysOverdue
            } else {
                missedCount = daysOverdue / schedulePeriod
            }
            return
        }
        
        // Calculate the time units between nextDueDate and now
        let calendar = Calendar.current
        let components = calendar.dateComponents([scheduleUnit.calendarComponent], from: nextDueDate, to: Date())
        
        let unitsOverdue: Int
        switch scheduleUnit {
        case .days:
            unitsOverdue = components.day ?? 0
        case .weeks:
            unitsOverdue = components.weekOfYear ?? 0
        case .months:
            unitsOverdue = components.month ?? 0
        case .years:
            unitsOverdue = components.year ?? 0
        }
        
        // For weekly/monthly/yearly or multi-day periods:
        // If we're 0 units overdue but still overdue, we've missed 1 period
        // Otherwise, count complete periods plus the current one
        if unitsOverdue == 0 {
            missedCount = 1
        } else {
            missedCount = (unitsOverdue / schedulePeriod) + 1
        }
    }
    
    var totalPoints: Int {
        completionHistory.reduce(0) { $0 + $1.points }
    }
    
    var averagePoints: Double {
        guard !completionHistory.isEmpty else { return 0 }
        return Double(totalPoints) / Double(completionHistory.count)
    }
}
