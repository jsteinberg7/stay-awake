on run
	try
		repeat
			set answer to display dialog "How many hours should your Mac stay awake?" & return & return & "You can close the lid. Use 0.5 for 30 minutes." default answer "2" buttons {"Cancel", "Stop", "Start"} default button "Start" cancel button "Cancel" with title "Stay Awake"
			if button returned of answer is "Stop" then
				my runController("stop")
				display dialog "Normal sleep is back on." buttons {"OK"} default button "OK" with title "Stay Awake"
				return
			end if
			try
				set requestedHours to (text returned of answer) as real
				if requestedHours < (1 / 60) or requestedHours > 168 then error "Out of range"
				set durationSeconds to round (requestedHours * 3600)
				exit repeat
			on error
				display dialog "Enter a number from 0.017 to 168 hours." buttons {"OK"} default button "OK" with title "Stay Awake"
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
