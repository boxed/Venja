//
//  OpenVenjaIntent.swift
//  Venja
//
//  Shared between the app and the widget extension so the control's
//  open-app handoff can be routed by the main app process.
//

import AppIntents

struct OpenVenjaIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Venja"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
