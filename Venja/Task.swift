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
        
        switch scheduleUnit {
        case .days:
            return calendar.date(byAdding: .day, value: schedulePeriod, to: referenceDate) ?? referenceDate
        case .weeks:
            return calendar.date(byAdding: .weekOfYear, value: schedulePeriod, to: referenceDate) ?? referenceDate
        case .months:
            return calendar.date(byAdding: .month, value: schedulePeriod, to: referenceDate) ?? referenceDate
        case .years:
            return calendar.date(byAdding: .year, value: schedulePeriod, to: referenceDate) ?? referenceDate
        }
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
    
    func updateMissedCount() {
        if schedulePeriod == 1 && scheduleUnit == .days && isOverdue {
            missedCount = daysOverdue
        }
    }
}