#!/usr/bin/osascript

tell application "System Events"
	tell process "Xcode"
		if exists (window 1) then
			set allWindows to every window
			repeat with aWindow in allWindows
				try
					if exists (sheet 1 of aWindow) then
						set sheetElements to entire contents of sheet 1 of aWindow
						repeat with element in sheetElements
							if class of element is static text then
								if value of element contains "Lost connection to" then
									-- Try to find and click OK or dismiss button
									set buttonList to every button of sheet 1 of aWindow
									repeat with aButton in buttonList
										set buttonTitle to title of aButton
										if buttonTitle is "OK" or buttonTitle is "Dismiss" or buttonTitle is "Cancel" then
											click aButton
											return "Dialog dismissed"
										end if
									end repeat
								end if
							end if
						end repeat
					end if
				end try
			end repeat
		end if
	end tell
end tell

return "No matching dialog found"