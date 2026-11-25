on run
	try
		set requestedDuration to "2h"
		repeat
			set answer to display dialog "How long should your Mac stay awake?" & return & return & "Try 30m, 2h, or 1h 30m. Numbers alone mean minutes." default answer requestedDuration buttons {"Cancel", "Stop", "Start"} default button "Start" cancel button "Cancel" with title "Stay Awake"
			if button returned of answer is "Stop" then
				my runController("stop")
				display dialog "Normal sleep is back on." buttons {"OK"} default button "OK" with title "Stay Awake"
				return
			end if
			set requestedDuration to text returned of answer
			try
				set parserPath to POSIX path of (path to resource "duration.awk")
				set durationSeconds to (do shell script "/usr/bin/printf '%s' " & quoted form of requestedDuration & " | /usr/bin/awk -f " & quoted form of parserPath) as integer
				exit repeat
			on error
				display dialog "Try 30m, 2h, or 1h 30m. Full words like 30 minutes work too." & return & return & "Choose between 1 minute and 7 days." buttons {"OK"} default button "OK" with title "Stay Awake"
			end try
		end repeat
		my runController("start " & (durationSeconds as integer as text))
		set endTime to (current date) + durationSeconds
		display dialog "Your Mac will stay awake until " & (time string of endTime) & " on " & (date string of endTime) & "." & return & return & "Sleep will turn back on automatically. Open Stay Awake again to change the duration or stop early." buttons {"OK"} default button "OK" with title "Stay Awake"
	on error messageText number errorNumber
		if errorNumber is not -128 then display dialog messageText buttons {"OK"} default button "OK" with title "Stay Awake" with icon caution
	end try
end run

on runController(arguments)
	set scriptPath to POSIX path of (path to resource "controller.sh")
	do shell script "/bin/sh " & quoted form of scriptPath & " " & arguments with administrator privileges
end runController
