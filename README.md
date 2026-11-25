# Stay Awake

A tiny Mac app that asks how long to keep your laptop running, even with the lid closed.

1. Open Spotlight and search **Stay Awake** or **caffeinate**.
2. Choose **Hours** and **Minutes** with the native up/down controls, then click **Start**. You can also use the arrow keys or enter numbers directly.
3. Approve the macOS administrator prompt.

Normal sleep returns automatically when time is up. Open the app again to change the duration or press **Stop** to end early. Closing the app does not cancel the timer. Restarting the Mac ends the session.

## Install

Download `Stay-Awake.zip` from [Releases](https://github.com/jsteinberg7/stay-awake/releases/latest), unzip it, and move **Stay Awake.app** to your Applications folder.

The app is ad-hoc signed, not Apple-notarized. macOS may require **System Settings → Privacy & Security → Open Anyway** on first launch. You can also build it yourself from the source below.

Requires macOS 12 or newer. Closed-lid behavior uses macOS's undocumented `pmset disablesleep` setting and may vary by hardware or macOS version. This prevents system sleep; the display can still turn off. Keep the laptop ventilated while it is running.

## Build

On a Mac with Python 3 and the Command Line Tools installed:

```sh
python3 scripts/build.py
cp -R 'dist/Stay Awake.app' ~/Applications/
```

There are no third-party dependencies, accounts, analytics, or network requests.

The build also creates `dist/Stay-Awake.zip` and checks that it preserves Spotlight search metadata.

## How it works

The native Swift/AppKit app validates the duration and asks macOS for administrator authorization. It enables `pmset -a disablesleep 1` and installs one root-owned LaunchDaemon at:

```
/Library/LaunchDaemons/io.github.stay-awake.timer.plist
```

Every five seconds, the daemon checks the deadline and boot session. At expiry or after a restart, it runs `pmset -a disablesleep 0`, removes its plist, and unloads itself. If restoring sleep fails, it retries. Starting another session replaces the previous timer. An existing sleep override from another tool is not replaced automatically.

The duration can be one minute to seven days. Expiry may take up to five extra seconds. The app needs administrator approval each time it changes the setting; it does not store your password or install a permanent privileged helper.

## Remove

Open Stay Awake and press **Stop**, then delete the app. If needed, restore sleep and remove the timer manually:

```sh
sudo pmset -a disablesleep 0
sudo rm -f /Library/LaunchDaemons/io.github.stay-awake.timer.plist
sudo launchctl bootout system/io.github.stay-awake.timer
```

The last command may report that the service is not found if the timer already finished.

## Tests

```sh
python3 -m unittest discover -s tests -v
python3 scripts/build.py --test-ui
```

The native UI checks exercise the hour/minute controls, validation, and duration limits without changing power settings. Release builds run on both Apple silicon and Intel Macs.

MIT licensed.
