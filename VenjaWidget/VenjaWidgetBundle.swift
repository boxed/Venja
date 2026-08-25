//
//  VenjaWidgetBundle.swift
//  VenjaWidget
//
//  Created by Anders Hovmöller on 2025-06-08.
//

import WidgetKit
import SwiftUI

@main
struct VenjaWidgetBundle: WidgetBundle {
    var body: some Widget {
        VenjaWidget()
#if os(iOS)
        VenjaWidgetControl()
        VenjaWidgetLiveActivity()
        VenjaLockScreenWidget()
#endif
    }
}
