#!/bin/sh
set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
label=io.github.stay-awake.timer
plist=/Library/LaunchDaemons/$label.plist

if [ "$(/usr/bin/id -u)" -ne 0 ]; then
    echo 'Stay Awake needs administrator access to change lid sleep.' >&2
    exit 1
fi

case "${1:-}" in
    stop)
        /usr/bin/pmset -a disablesleep 0
        /bin/rm -f "$plist"
        /bin/launchctl bootout "system/$label" 2>/dev/null || true
        exit 0
        ;;
    start)
        seconds=${2:-}
        case "$seconds" in ''|*[!0-9]*) echo 'Invalid duration.' >&2; exit 1;; esac
        if [ "${#seconds}" -gt 6 ] || [ "$seconds" -lt 60 ] || [ "$seconds" -gt 604800 ]; then
            echo 'Choose between one minute and seven days.' >&2
            exit 1
        fi
        ;;
    *) echo 'Usage: controller.sh start SECONDS | stop' >&2; exit 1;;
esac

# Do not take ownership of a setting another app already changed.
if [ ! -f "$plist" ] && /usr/bin/pmset -g | /usr/bin/grep -Eq 'SleepDisabled[[:space:]]+1'; then
    echo 'Sleep is already disabled by another tool. Restore normal sleep first, then try again.' >&2
    exit 1
fi

deadline=$(( $(/bin/date +%s) + seconds ))
boot=$(/usr/sbin/sysctl -n kern.bootsessionuuid)
case "$boot" in ''|*[!A-Fa-f0-9-]*) echo 'Could not read the boot session.' >&2; exit 1;; esac

temporary=$(/usr/bin/mktemp /Library/LaunchDaemons/.stay-awake.XXXXXX)
cleanup() {
    result=$?
    trap - EXIT HUP INT TERM
    /bin/rm -f "$temporary"
    if [ "$result" -ne 0 ]; then
        /usr/bin/pmset -a disablesleep 0 || true
        /bin/rm -f "$plist"
        /bin/launchctl bootout "system/$label" 2>/dev/null || true
    fi
    exit "$result"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

# The build embeds an XML-escaped, fixed timer script here. Only the validated
# duration and boot UUID are substituted at runtime.
cat > "$temporary" <<PLIST
@@TIMER_PLIST@@
PLIST
/usr/bin/plutil -lint "$temporary" >/dev/null
/usr/sbin/chown root:wheel "$temporary"
/bin/chmod 644 "$temporary"

# End any previous session before installing its replacement.
/bin/launchctl bootout "system/$label" 2>/dev/null || true
/bin/mv -f "$temporary" "$plist"
/usr/bin/pmset -a disablesleep 1
/bin/launchctl bootstrap system "$plist"
/bin/launchctl print "system/$label" >/dev/null
/usr/bin/pmset -g | /usr/bin/grep -Eq 'SleepDisabled[[:space:]]+1'
