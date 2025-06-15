//
//  UndoManager.swift
//  Venja
//
//  Created by Anders Hovmöller on 2025-06-08.
//

import Foundation

struct UndoAction {
    let task: VTask
    let previousDate: Date?
    let previousMissedCount: Int
    let timestamp: Date
}

@Observable
class TaskUndoManager {
    internal var undoStack: [UndoAction] = []
    private let maxUndoActions = 10
    
    var canUndo: Bool {
        !undoStack.isEmpty
    }
    
    func recordCompletion(task: VTask, previousDate: Date?, previousMissedCount: Int) {
        let action = UndoAction(
            task: task,
            previousDate: previousDate,
            previousMissedCount: previousMissedCount,
            timestamp: Date()
        )
        
        undoStack.append(action)
        
        // Keep only the most recent actions
        if undoStack.count > maxUndoActions {
            undoStack.removeFirst()
        }
    }
    
    func undo() -> UndoAction? {
        guard let action = undoStack.popLast() else { return nil }
        action.task.undoCompletion(previousDate: action.previousDate, previousMissedCount: action.previousMissedCount)
        return action
    }
    
    func clearHistory() {
        undoStack.removeAll()
    }
}