#!/usr/bin/osascript

on run
    set projectPath to "/Users/boxed/Projects/Venja/Venja.xcodeproj"
    
    tell application "Xcode"
        activate
        
        -- Open the project if not already open
        if not (exists (every workspace document whose path is projectPath)) then
            open projectPath
            delay 2 -- Wait for project to load
        end if
        
        -- Make sure Xcode is frontmost
        activate
        delay 0.5
        
        -- Run the project with Cmd+R
        tell application "System Events"
            tell process "Xcode"
                keystroke "r" using {command down}
            end tell
        end tell
    end tell
end run