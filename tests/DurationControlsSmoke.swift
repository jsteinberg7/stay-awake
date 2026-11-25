import AppKit

@MainActor
func runUISmokeTests(_ app: AppDelegate) {
    func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError(message) }
    }
    func step(_ component: DurationComponent, to value: Int) {
        component.stepper.integerValue = value
        component.stepper.sendAction(component.stepper.action, to: component.stepper.target)
    }

    check(app.durationSeconds == 7200, "Default must be two hours")
    step(app.hours, to: 0)
    check(!app.startButton.isEnabled, "Zero duration must disable Start")
    step(app.minutes, to: 30)
    check(app.durationSeconds == 1800 && app.startButton.isEnabled, "Minute stepper must update duration")
    let editor = NSTextView()
    check(app.minutes.control(app.minutes.field, textView: editor,
                              doCommandBy: #selector(NSResponder.moveUp(_:))), "Up arrow must be handled")
    check(app.durationSeconds == 1860, "Up arrow must add a minute")
    _ = app.minutes.control(app.minutes.field, textView: editor,
                            doCommandBy: #selector(NSResponder.moveDown(_:)))
    check(app.durationSeconds == 1800, "Down arrow must remove a minute")
    step(app.hours, to: 1)
    check(app.durationSeconds == 5400, "Hour and minute values must combine")
    app.hours.field.stringValue = "abc"
    app.hours.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
    check(!app.startButton.isEnabled, "Invalid numeric edits must disable Start")
    app.hours.field.stringValue = "1.5"
    app.hours.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
    check(!app.startButton.isEnabled, "Fractional hours must not be accepted as whole hours")
    step(app.hours, to: 168)
    check(app.durationSeconds == 604800, "Maximum duration must be seven days")
    check(!app.minutes.stepper.isEnabled && app.minutes.value == 0, "Maximum hours must clamp minutes")
    step(app.hours, to: 0)
    check(app.minutes.stepper.isEnabled, "Minutes must re-enable below maximum")
    step(app.minutes, to: 1)
    check(app.durationSeconds == 60, "Minimum duration must be one minute")

    step(app.hours, to: 2)
    step(app.minutes, to: 0)
    app.window.makeFirstResponder(nil)
    NSApp.updateWindows()
    RunLoop.main.run(until: Date().addingTimeInterval(0.5))
    let view = app.window.contentView!
    view.layoutSubtreeIfNeeded()
    let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
    view.cacheDisplay(in: view.bounds, to: bitmap)
    if let path = ProcessInfo.processInfo.environment["STAY_AWAKE_PREVIEW"] {
        let capture = Process()
        capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        capture.arguments = ["-x", "-o", "-l", String(app.window.windowNumber), path]
        try! capture.run()
        capture.waitUntilExit()
        if capture.terminationStatus != 0 {
            try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
        }
    }
    print("Native duration controls: all checks passed; no power settings changed.")
}
