# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Venja is a SwiftUI application for tracking chores, habits, and maintenance tasks with a scheduler system. It supports both iOS and macOS platforms with CloudKit syncing.

## Build Commands

```bash
# Build for iOS Simulator
xcodebuild -project Venja.xcodeproj -scheme Venja -sdk iphonesimulator build

# Build for macOS
xcodebuild -project Venja.xcodeproj -scheme Venja -sdk macosx build

# Clean build
xcodebuild -project Venja.xcodeproj -scheme Venja clean build

# Open in Xcode
open Venja.xcodeproj
```

## Testing Commands

```bash
# Run all tests
xcodebuild test -project Venja.xcodeproj -scheme Venja -destination 'platform=iOS Simulator,name=iPhone 15'

# Run unit tests only
xcodebuild test -project Venja.xcodeproj -scheme Venja -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:VenjaTests

# Run UI tests only
xcodebuild test -project Venja.xcodeproj -scheme Venja -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:VenjaUITests
```

## Architecture

The project uses SwiftUI with SwiftData for persistence:

- **VenjaApp.swift**: App entry point, configures SwiftData ModelContainer
- **ContentView.swift**: Main UI with NavigationSplitView, handles platform-specific UI
- **Item.swift**: SwiftData model (currently just a timestamp placeholder)

Key patterns:
- SwiftData `@Model` for data persistence with CloudKit sync
- SwiftUI `@Query` for reactive data fetching
- Platform-specific code using `#if os(macOS)` and `#if os(iOS)`
- Environment injection for ModelContext

## Important Notes

- Unit tests use Swift Testing framework (`@Test`, `#expect`)
- UI tests use XCTest framework
- CloudKit and push notifications are configured in entitlements
- Requires Apple Developer account for full functionality
- Minimum iOS 17 / macOS 14 (SwiftData requirement)


**After completing a change**, build and run the app on Anders iPhone:

```bash
xcodebuild -workspace calvetica.xcworkspace -scheme calvetica -destination "name=Anders Hovmöller's iPhone" build
```