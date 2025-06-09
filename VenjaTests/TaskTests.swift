//
//  TaskTests.swift
//  VenjaTests
//
//  Created by Claude on 2025-06-09.
//

import Testing
import Foundation
import SwiftData
@testable import Venja

struct TaskTests {
    
    private func createTestTask(name: String, schedulePeriod: Int, scheduleUnit: ScheduleUnit) -> Task {
        let container = try! ModelContainer(for: Task.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        
        let task = Task(name: name, schedulePeriod: schedulePeriod, scheduleUnit: scheduleUnit)
        context.insert(task)
        
        return task
    }
    
    @Test("Non-overdue task should have zero missed count")
    func testNonOverdueTask() {
        let task = createTestTask(name: "Test Task", schedulePeriod: 1, scheduleUnit: .days)
        task.lastCompletedDate = Date()
        
        task.updateMissedCount()
        
        #expect(task.missedCount == 0)
    }
    
    @Test("Daily task - single period overdue")
    func testDailyTaskSinglePeriod() {
        let task = createTestTask(name: "Daily Task", schedulePeriod: 1, scheduleUnit: .days)
        task.lastCompletedDate = Calendar.current.date(byAdding: .day, value: -6, to: Date())
        
        task.updateMissedCount()
        
        #expect(task.missedCount == 5)
    }
    
    @Test("Daily task - multiple period (every 3 days)")
    func testDailyTaskMultiplePeriod() {
        let task = createTestTask(name: "Every 3 Days Task", schedulePeriod: 3, scheduleUnit: .days)
        task.lastCompletedDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())
        
        task.updateMissedCount()
        
        #expect(task.missedCount == 2)
    }
    
    @Test("Weekly task - single week overdue")
    func testWeeklyTaskSinglePeriod() {
        let task = createTestTask(name: "Weekly Task", schedulePeriod: 1, scheduleUnit: .weeks)
        task.lastCompletedDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())
        
        task.updateMissedCount()
        
        #expect(task.missedCount == 1)
    }
    
    @Test("Bi-weekly task - multiple weeks overdue")
    func testBiWeeklyTask() {
        let task = createTestTask(name: "Bi-weekly Task", schedulePeriod: 2, scheduleUnit: .weeks)
        task.lastCompletedDate = Calendar.current.date(byAdding: .day, value: -25, to: Date())
        
        task.updateMissedCount()
        
        #expect(task.missedCount == 1)
    }
    
    @Test("Monthly task - multiple months overdue")
    func testMonthlyTask() {
        let task = createTestTask(name: "Monthly Task", schedulePeriod: 1, scheduleUnit: .months)
        task.lastCompletedDate = Calendar.current.date(byAdding: .day, value: -65, to: Date())
        
        task.updateMissedCount()
        
        #expect(task.missedCount >= 2)
    }
    
    @Test("Quarterly task (every 3 months)")
    func testQuarterlyTask() {
        let task = createTestTask(name: "Quarterly Task", schedulePeriod: 3, scheduleUnit: .months)
        task.lastCompletedDate = Calendar.current.date(byAdding: .month, value: -8, to: Date())
        
        task.updateMissedCount()
        
        #expect(task.missedCount == 2)
    }
    
    @Test("Annual task - overdue by 18 months")
    func testAnnualTask() {
        let task = createTestTask(name: "Annual Task", schedulePeriod: 1, scheduleUnit: .years)
        task.lastCompletedDate = Calendar.current.date(byAdding: .month, value: -18, to: Date())
        
        task.updateMissedCount()
        
        #expect(task.missedCount == 1)
    }
    
    @Test("Bi-annual task (every 2 years)")
    func testBiAnnualTask() {
        let task = createTestTask(name: "Bi-annual Task", schedulePeriod: 2, scheduleUnit: .years)
        task.lastCompletedDate = Calendar.current.date(byAdding: .year, value: -5, to: Date())
        
        task.updateMissedCount()
        
        #expect(task.missedCount == 2)
    }
    
    @Test("Task with no completion date uses creation date")
    func testTaskWithNoCompletionDate() {
        let task = createTestTask(name: "New Task", schedulePeriod: 1, scheduleUnit: .days)
        task.creationDate = Calendar.current.date(byAdding: .day, value: -4, to: Date())!
        task.lastCompletedDate = nil
        
        task.updateMissedCount()
        
        #expect(task.missedCount == 3)
    }
    
    @Test("Edge case - exactly on due date")
    func testExactlyOnDueDate() {
        let task = createTestTask(name: "On Time Task", schedulePeriod: 1, scheduleUnit: .days)
        task.lastCompletedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        
        task.updateMissedCount()
        
        #expect(task.missedCount == 0)
    }
    
    @Test("Edge case - just past due date")
    func testJustPastDueDate() {
        let task = createTestTask(name: "Just Late Task", schedulePeriod: 1, scheduleUnit: .days)
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let justPastDue = calendar.date(byAdding: .second, value: -1, to: yesterday)!
        task.lastCompletedDate = justPastDue
        
        task.updateMissedCount()
        
        #expect(task.missedCount == 1)
    }
    
    @Test("Marking completed resets missed count")
    func testMarkCompletedResetsMissedCount() {
        let task = createTestTask(name: "Overdue Task", schedulePeriod: 1, scheduleUnit: .days)
        task.lastCompletedDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())
        
        task.updateMissedCount()
        #expect(task.missedCount == 4)
        
        task.markCompleted()
        #expect(task.missedCount == 0)
    }
    
    @Test("Undo completion restores missed count")
    func testUndoCompletionRestoresMissedCount() {
        let task = createTestTask(name: "Task", schedulePeriod: 1, scheduleUnit: .days)
        let oldDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())
        task.lastCompletedDate = oldDate
        
        task.updateMissedCount()
        let oldMissedCount = task.missedCount
        
        task.markCompleted()
        task.undoCompletion(previousDate: oldDate, previousMissedCount: oldMissedCount)
        
        #expect(task.missedCount == oldMissedCount)
    }
}