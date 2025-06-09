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
final class Task {
    var name: String
    var schedulePeriod: Int
    var scheduleUnit: ScheduleUnit
    var creationDate: Date
    var lastCompletedDate: Date?
    var missedCount: Int
    
    init(name: String, schedulePeriod: Int, scheduleUnit: ScheduleUnit) {
        self.name = name
        self.schedulePeriod = schedulePeriod
        self.scheduleUnit = scheduleUnit
        self.creationDate = Date()
        self.lastCompletedDate = nil
        self.missedCount = 0
    }
    
    var nextDueDate: Date {
        let referenceDate = lastCompletedDate ?? creationDate
        let calendar = Calendar.current
        
        return calendar.date(byAdding: scheduleUnit.calendarComponent, value: schedulePeriod, to: referenceDate) ?? referenceDate
    }
    
    var isOverdue: Bool {
        return nextDueDate < Date()
    }
    
    var daysOverdue: Int {
        guard isOverdue else { return 0 }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: nextDueDate, to: Date())
        return components.day ?? 0
    }
    
    func markCompleted() {
        lastCompletedDate = Date()
        missedCount = 0
    }
    
    func undoCompletion(previousDate: Date?, previousMissedCount: Int) {
        lastCompletedDate = previousDate
        missedCount = previousMissedCount
    }
    
    func updateMissedCount() {
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
}