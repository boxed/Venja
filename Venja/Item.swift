//
//  Item.swift
//  Venja
//
//  Created by Anders Hovmöller on 2025-06-08.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
