#!/bin/sh
# launchd runs this every five seconds, and once on boot.
set -eu
deadline=$1
session_boot=$2
current_boot=$(/usr/sbin/sysctl -n kern.bootsessionuuid)
now=$(/bin/date +%s)
if [ "$current_boot" = "$session_boot" ] && [ "$now" -lt "$deadline" ]; then
    exit 0
fi

# If restoration fails, leave the job installed so launchd retries.
/usr/bin/pmset -a disablesleep 0
/bin/rm -f /Library/LaunchDaemons/io.github.stay-awake.timer.plist
/bin/launchctl bootout system/io.github.stay-awake.timer
