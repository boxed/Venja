//
//  VenjaApp.swift
//  Venja
//
//  Created by Anders Hovmöller on 2025-06-08.
//

import SwiftUI
import SwiftData
#if os(iOS)
import BackgroundTasks
#endif
import WidgetKit

@main
struct VenjaApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            VTask.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        #if os(iOS)
        registerBackgroundTasks()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .background:
                #if os(iOS)
                scheduleAppRefresh()
                #endif
                // Update widget when app goes to background
                WidgetCenter.shared.reloadAllTimelines()
            case .active:
                #if os(iOS)
                // Cancel pending background tasks when app becomes active
                BGTaskScheduler.shared.cancelAllTaskRequests()
                #endif
            default:
                break
            }
        }
    }
    
    #if os(iOS)
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "net.kodare.Venja.refresh",
            using: nil
        ) { task in
            handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "net.kodare.Venja.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule the next background refresh
        scheduleAppRefresh()
        
        // Create a task to update widget data
        let refreshTask = Task {
            do {
                let context = sharedModelContainer.mainContext
                let descriptor = FetchDescriptor<VTask>(sortBy: [SortDescriptor(\.creationDate)])
                let tasks = try context.fetch(descriptor)
                
                // Update missed counts
                for venjaTask in tasks {
                    venjaTask.updateMissedCount()
                }
                
                // Update widget data
                updateWidgetData(tasks: tasks)
                
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
        
        // Ensure the background task doesn't run forever
        task.expirationHandler = {
            refreshTask.cancel()
        }
    }
    #endif
    
    private func updateWidgetData(tasks: [VTask]) {
        let userDefaults = UserDefaults(suiteName: "group.net.kodare.Venja") ?? UserDefaults.standard
        let calendar = Calendar.current
        
        let activeTasks = tasks.filter { task in
            calendar.isDateInToday(task.nextDueDate) || task.isOverdue
        }.sorted { 
            if $0.missedCount != $1.missedCount {
                return $0.missedCount > $1.missedCount
            }
            return $0.nextDueDate < $1.nextDueDate
        }
        
        if let firstTask = activeTasks.first {
            let taskData = WidgetTaskData(
                name: firstTask.name,
                missedCount: firstTask.missedCount,
                schedulePeriod: firstTask.schedulePeriod,
                scheduleUnit: firstTask.scheduleUnit.rawValue
            )
            
            if let encoded = try? JSONEncoder().encode(taskData) {
                userDefaults.set(encoded, forKey: "currentTask")
            }
        } else {
            userDefaults.removeObject(forKey: "currentTask")
        }
        
        // Reload widget timelines
        WidgetCenter.shared.reloadAllTimelines()
    }
}
