//
//  CompletionHistory.swift
//  Venja
//
//  Created by Claude on 2025-08-18.
//

import Foundation
import SwiftData

@Model
final class CompletionHistory {
    var completionDate: Date
    var missedCountAtCompletion: Int
    var task: VTask?
    
    init(completionDate: Date = Date(), missedCountAtCompletion: Int = 0) {
        self.completionDate = completionDate
        self.missedCountAtCompletion = missedCountAtCompletion
    }
    
    var points: Int {
        switch missedCountAtCompletion {
        case 0:
            return 5
        case 1..<3:
            return 4
        case 3..<5:
            return 3
        case 5..<7:
            return 2
        default:
            return 1
        }
    }
}