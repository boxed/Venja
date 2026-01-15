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
    
    private func createTestTask(name: String, schedulePeriod: Int, scheduleUnit: ScheduleUnit) -> VTask {
        let container = try! ModelContainer(for: VTask.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        
        let task = VTask(name: name, schedulePeriod: schedulePeriod, scheduleUnit: scheduleUnit)
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
        // Set to 14 days ago to ensure it's been at least 1 complete week since the due date
        task.lastCompletedDate = Calendar.current.date(byAdding: .day, value: -14, to: Date())

        task.updateMissedCount()

        #expect(task.missedCount == 1)
    }
    
    @Test("Bi-weekly task - multiple weeks overdue")
    func testBiWeeklyTask() {
        let task = createTestTask(name: "Bi-weekly Task", schedulePeriod: 2, scheduleUnit: .weeks)
        // Set to 28 days ago to ensure at least 1 complete 2-week period overdue
        task.lastCompletedDate = Calendar.current.date(byAdding: .day, value: -28, to: Date())

        task.updateMissedCount()

        #expect(task.missedCount == 1)
    }
    
    @Test("Monthly task - multiple months overdue")
    func testMonthlyTask() {
        let task = createTestTask(name: "Monthly Task", schedulePeriod: 1, scheduleUnit: .months)
        // Set to 100 days ago to ensure at least 2 complete months overdue
        task.lastCompletedDate = Calendar.current.date(byAdding: .day, value: -100, to: Date())

        task.updateMissedCount()

        #expect(task.missedCount >= 2)
    }
    
    @Test("Quarterly task (every 3 months)")
    func testQuarterlyTask() {
        let task = createTestTask(name: "Quarterly Task", schedulePeriod: 3, scheduleUnit: .months)
        // Set to 9 months ago to ensure 2 complete 3-month periods overdue
        task.lastCompletedDate = Calendar.current.date(byAdding: .month, value: -9, to: Date())

        task.updateMissedCount()

        #expect(task.missedCount == 2)
    }
    
    @Test("Annual task - overdue by 1 year")
    func testAnnualTask() {
        let task = createTestTask(name: "Annual Task", schedulePeriod: 1, scheduleUnit: .years)
        // Set to 24 months ago to ensure 1 complete year overdue
        task.lastCompletedDate = Calendar.current.date(byAdding: .month, value: -24, to: Date())

        task.updateMissedCount()

        #expect(task.missedCount == 1)
    }
    
    @Test("Bi-annual task (every 2 years)")
    func testBiAnnualTask() {
        let task = createTestTask(name: "Bi-annual Task", schedulePeriod: 2, scheduleUnit: .years)
        // Set to 6 years ago to ensure 2 complete 2-year periods overdue
        task.lastCompletedDate = Calendar.current.date(byAdding: .year, value: -6, to: Date())

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
        // Set to 2 days ago to ensure it's been overdue for 1 complete day
        task.lastCompletedDate = calendar.date(byAdding: .day, value: -2, to: Date())!

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

    @Test("Task scheduled for specific hour has correct hour in nextDueDate")
    func testScheduledHourInNextDueDate() {
        let calendar = Calendar.current

        let task = createTestTask(name: "Evening Task", schedulePeriod: 1, scheduleUnit: .days)
        task.scheduledHour = 17  // 5 PM

        // Set last completion to a specific date (after the scheduled hour)
        let lastCompletion = calendar.date(from: DateComponents(year: 2025, month: 6, day: 15, hour: 18))!
        task.lastCompletedDate = lastCompletion

        // Next due date should be June 16, 2025 at 17:00 (next day since we completed after 5 PM)
        let nextDue = task.nextDueDate
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextDue)

        #expect(components.year == 2025)
        #expect(components.month == 6)
        #expect(components.day == 16)
        #expect(components.hour == 17)
        #expect(components.minute == 0)
    }

    @Test("Task scheduled for morning hour is not overdue before that hour")
    func testTaskScheduledForMorningNotOverdueBeforeThatHour() {
        let calendar = Calendar.current

        // Create task scheduled for 10 AM
        let task = createTestTask(name: "Morning Task", schedulePeriod: 1, scheduleUnit: .days)
        task.scheduledHour = 10

        // Last completed yesterday at 5 PM
        let lastCompletion = calendar.date(from: DateComponents(year: 2025, month: 6, day: 15, hour: 17))!
        task.lastCompletedDate = lastCompletion

        // Next due date should be June 16, 2025 at 10:00
        let nextDue = task.nextDueDate

        // Current time is June 16, 2025 at 8:00 AM (before scheduled time)
        let currentTime = calendar.date(from: DateComponents(year: 2025, month: 6, day: 16, hour: 8))!

        // Task should NOT be overdue since current time is before scheduled time
        #expect(nextDue > currentTime)
    }

    @Test("Task scheduled for morning hour is overdue after that hour")
    func testTaskScheduledForMorningIsOverdueAfterThatHour() {
        let calendar = Calendar.current

        // Create task scheduled for 10 AM
        let task = createTestTask(name: "Morning Task", schedulePeriod: 1, scheduleUnit: .days)
        task.scheduledHour = 10

        // Last completed yesterday at 5 PM
        let lastCompletion = calendar.date(from: DateComponents(year: 2025, month: 6, day: 15, hour: 17))!
        task.lastCompletedDate = lastCompletion

        // Next due date should be June 16, 2025 at 10:00
        let nextDue = task.nextDueDate

        // Current time is June 16, 2025 at 2:00 PM (after scheduled time)
        let currentTime = calendar.date(from: DateComponents(year: 2025, month: 6, day: 16, hour: 14))!

        // Task should be overdue since current time is after scheduled time
        #expect(nextDue < currentTime)
    }

    @Test("Task scheduled for evening maintains correct next due date")
    func testTaskScheduledForEveningNextDueDate() {
        let calendar = Calendar.current

        // Create task scheduled for 8 PM
        let task = createTestTask(name: "Evening Task", schedulePeriod: 1, scheduleUnit: .days)
        task.scheduledHour = 20

        // Last completed June 15 at 9 AM (before scheduled hour)
        let lastCompletion = calendar.date(from: DateComponents(year: 2025, month: 6, day: 15, hour: 9))!
        task.lastCompletedDate = lastCompletion

        // Next due should be June 15 at 8 PM (same day, since we completed before the scheduled hour)
        // The scheduler anchors to the scheduled time, not to the completion time
        let nextDue = task.nextDueDate
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: nextDue)

        #expect(components.year == 2025)
        #expect(components.month == 6)
        #expect(components.day == 15)
        #expect(components.hour == 20)
    }

    @Test("Weekly task with scheduled hour calculates next due date correctly")
    func testWeeklyTaskWithScheduledHour() {
        let calendar = Calendar.current

        // Create weekly task scheduled for 3 PM
        let task = createTestTask(name: "Weekly Task", schedulePeriod: 1, scheduleUnit: .weeks)
        task.scheduledHour = 15
        // Set creationDate to a Sunday (June 8, 2025) to establish Sunday as the target weekday
        task.creationDate = calendar.date(from: DateComponents(year: 2025, month: 6, day: 8, hour: 10))!

        // Last completed June 8, 2025 at 4 PM (Sunday)
        let lastCompletion = calendar.date(from: DateComponents(year: 2025, month: 6, day: 8, hour: 16))!
        task.lastCompletedDate = lastCompletion

        // Next due should be June 15, 2025 at 3 PM (next Sunday)
        let nextDue = task.nextDueDate
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: nextDue)

        #expect(components.year == 2025)
        #expect(components.month == 6)
        #expect(components.day == 15)
        #expect(components.hour == 15)
    }

    @Test("Weekly task with scheduled hour calculates next due date correctly, even if completion date is close to next time")
    func testWeeklyTaskWithScheduledHour2() {
        let calendar = Calendar.current

        // Create weekly task scheduled for 3 PM
        let task = createTestTask(name: "Weekly Task", schedulePeriod: 1, scheduleUnit: .weeks)
        task.scheduledHour = 15
        // Set creationDate to a Sunday (June 8, 2025) to establish Sunday as the target weekday
        task.creationDate = calendar.date(from: DateComponents(year: 2025, month: 6, day: 8, hour: 10))!

        // Last completed June 15, 2025 at 2 PM (Sunday, just before scheduled time)
        let lastCompletion = calendar.date(from: DateComponents(year: 2025, month: 6, day: 15, hour: 14))!
        task.lastCompletedDate = lastCompletion

        // Next due should be June 15, 2025 at 3 PM (same day since completion was before scheduled hour)
        let nextDue = task.nextDueDate
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: nextDue)

        #expect(components.year == 2025)
        #expect(components.month == 6)
        #expect(components.day == 15)
        #expect(components.hour == 15)
    }

    @Test("Weekly task preserves target weekday after completion on different day")
    func testWeeklyTaskPreservesTargetWeekdayAfterCompletion() {
        let calendar = Calendar.current

        // Create a weekly task that should be due on Saturdays (weekday 7)
        // We'll set creationDate to a Saturday so the target weekday is Saturday
        let saturdayCreationDate = calendar.date(from: DateComponents(year: 2025, month: 6, day: 7, hour: 10))! // Saturday June 7
        let task = createTestTask(name: "Saturday Task", schedulePeriod: 1, scheduleUnit: .weeks)
        task.creationDate = saturdayCreationDate
        task.scheduledHour = 10

        // Verify initial nextDueDate is on a Saturday
        let initialNextDue = task.nextDueDate
        let initialWeekday = calendar.component(.weekday, from: initialNextDue)
        #expect(initialWeekday == 7, "Initial next due should be Saturday (weekday 7), got \(initialWeekday)")

        // Now complete the task on a Wednesday (weekday 4)
        let wednesdayCompletion = calendar.date(from: DateComponents(year: 2025, month: 6, day: 11, hour: 15))! // Wednesday June 11
        task.lastCompletedDate = wednesdayCompletion

        // The next due date should STILL be on a Saturday, not on Wednesday!
        // This is the bug: currently it lands on Wednesday because nextDueDate
        // just advances from lastCompletedDate without respecting the target weekday
        let nextDueAfterCompletion = task.nextDueDate
        let weekdayAfterCompletion = calendar.component(.weekday, from: nextDueAfterCompletion)

        #expect(weekdayAfterCompletion == 7, "Next due after completion should be Saturday (weekday 7), but got \(weekdayAfterCompletion)")

        // Verify the date is the next Saturday after the Wednesday completion
        // Wednesday June 11 -> next Saturday should be June 14
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: nextDueAfterCompletion)
        #expect(components.year == 2025)
        #expect(components.month == 6)
        #expect(components.day == 14, "Should be June 14 (Saturday), got \(components.day ?? 0)")
        #expect(components.hour == 10)
    }

    @Test("Weekly task preserves target weekday when editing to different day")
    func testWeeklyTaskPreservesTargetWeekdayWhenEditing() {
        let calendar = Calendar.current

        // Create a weekly task originally scheduled for Saturday
        let saturdayCreationDate = calendar.date(from: DateComponents(year: 2025, month: 6, day: 7, hour: 10))! // Saturday June 7
        let task = createTestTask(name: "Weekend Task", schedulePeriod: 1, scheduleUnit: .weeks)
        task.creationDate = saturdayCreationDate
        task.scheduledHour = 10

        // Complete the task on Saturday June 14
        let saturdayCompletion = calendar.date(from: DateComponents(year: 2025, month: 6, day: 14, hour: 11))!
        task.lastCompletedDate = saturdayCompletion

        // Now simulate editing the task to change target day to Sunday (weekday 1)
        // This is what computeCreationDate() in EditTaskView does: create a new creationDate
        // that lands on the target weekday when advanced by schedulePeriod
        let sundayCreationDate = calendar.date(from: DateComponents(year: 2025, month: 6, day: 8, hour: 10))! // Sunday June 8
        task.creationDate = sundayCreationDate

        // After changing creationDate, nextDueDate should land on Sunday, not Saturday
        let nextDue = task.nextDueDate
        let weekday = calendar.component(.weekday, from: nextDue)

        #expect(weekday == 1, "Next due should be Sunday (weekday 1) after editing, but got \(weekday)")

        // The next Sunday after Saturday June 14 is June 15
        let components = calendar.dateComponents([.year, .month, .day], from: nextDue)
        #expect(components.day == 15, "Should be June 15 (Sunday), got \(components.day ?? 0)")
    }

    @Test("Task scheduled for midnight completed mid-day shows up at midnight with zero missed count")
    func testMidnightTaskCompletedMidDay() {
        let calendar = Calendar.current

        // Create daily task scheduled for midnight (default)
        let task = createTestTask(name: "Midnight Task", schedulePeriod: 1, scheduleUnit: .days)
        task.scheduledHour = 0  // Midnight

        // Completed yesterday at 12:05 PM
        let yesterday = calendar.date(from: DateComponents(year: 2025, month: 6, day: 15, hour: 12, minute: 5))!
        task.lastCompletedDate = yesterday

        // At midnight today (00:00), task should be due
        let midnightToday = calendar.date(from: DateComponents(year: 2025, month: 6, day: 16, hour: 0, minute: 0))!
        let nextDue = task.nextDueDate
        #expect(nextDue == midnightToday, "Task should be due at midnight today")

        // At 12:06 today, task should still show the same due date and have zero missed count
        // Since we haven't completed a full period since the task became due
        let todayAfternoon = calendar.date(from: DateComponents(year: 2025, month: 6, day: 16, hour: 12, minute: 6))!

        // Verify next due date is still midnight today
        #expect(task.nextDueDate == midnightToday, "Next due date should still be midnight today")

        // Verify task is overdue at 12:06
        #expect(task.nextDueDate < todayAfternoon, "Task should be overdue at 12:06")

        // Update missed count and verify it's zero
        // The task became due at midnight, but we're only 12 hours past due
        // We haven't missed a complete period yet
        task.updateMissedCount(currentDate: todayAfternoon)
        #expect(task.missedCount == 0, "Missed count should be zero - haven't completed a full period since due")
    }
}
