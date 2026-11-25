import AppKit

@MainActor
final class DurationComponent: NSStackView, NSTextFieldDelegate {
    let field = NSTextField()
    let stepper = NSStepper()
    var onChange: (() -> Void)?

    init(label: String, maximum: Int, initial: Int) {
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = 7

        let caption = NSTextField(labelWithString: label)
        caption.font = .systemFont(ofSize: 12)
        caption.textColor = .secondaryLabelColor
        addArrangedSubview(caption)

        field.font = .monospacedDigitSystemFont(ofSize: 24, weight: .regular)
        field.alignment = .center
        field.bezelStyle = .roundedBezel
        field.intValue = Int32(initial)
        field.delegate = self
        field.setAccessibilityLabel(label)
        field.widthAnchor.constraint(equalToConstant: 88).isActive = true
        field.heightAnchor.constraint(equalToConstant: 40).isActive = true

        stepper.minValue = 0
        stepper.maxValue = Double(maximum)
        stepper.increment = 1
        stepper.integerValue = initial
        stepper.valueWraps = false
        stepper.autorepeat = true
        stepper.target = self
        stepper.action = #selector(stepped)
        stepper.setAccessibilityLabel(label)

        let row = NSStackView(views: [field, stepper])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 4
        addArrangedSubview(row)
    }

    required init?(coder: NSCoder) { fatalError("Not used") }

    var value: Int? {
        guard let number = Int(field.stringValue), number >= 0,
              number <= Int(stepper.maxValue) else { return nil }
        return number
    }

    func setValue(_ value: Int) {
        field.integerValue = value
        stepper.integerValue = value
    }

    @objc private func stepped() {
        field.integerValue = stepper.integerValue
        onChange?()
    }

    func controlTextDidChange(_ notification: Notification) {
        if let value { stepper.integerValue = value }
        onChange?()
    }

    func control(_ control: NSControl, textView: NSTextView,
                 doCommandBy commandSelector: Selector) -> Bool {
        let change: Int
        switch commandSelector {
        case #selector(NSResponder.moveUp(_:)): change = 1
        case #selector(NSResponder.moveDown(_:)): change = -1
        default: return false
        }
        setValue(min(Int(stepper.maxValue), max(0, (value ?? 0) + change)))
        onChange?()
        return true
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    let hours = DurationComponent(label: "Hours", maximum: 168, initial: 2)
    let minutes = DurationComponent(label: "Minutes", maximum: 59, initial: 0)
    let startButton = NSButton(title: "Start", target: nil, action: nil)
    let status = NSTextField(wrappingLabelWithString: "Sleep will turn back on automatically.")

    var durationSeconds: Int? {
        guard let h = hours.value, let m = minutes.value else { return nil }
        let seconds = h * 3600 + m * 60
        return (60...604800).contains(seconds) ? seconds : nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Stay Awake", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let editMenu = NSMenu(title: "Edit")
        for (title, action, key) in [("Cut", "cut:", "x"), ("Copy", "copy:", "c"),
                                     ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            editMenu.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        let editItem = NSMenuItem()
        editItem.submenu = editMenu
        menu.addItem(editItem)
        NSApp.mainMenu = menu

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 282),
                          styleMask: [.titled, .closable, .miniaturizable],
                          backing: .buffered, defer: false)
        window.title = "Stay Awake"
        window.isReleasedWhenClosed = false
        window.delegate = self
        let content = window.contentView!

        let title = NSTextField(labelWithString: "Keep your Mac awake for")
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        let subtitle = NSTextField(labelWithString: "Keep working, even with the lid closed.")
        subtitle.textColor = .secondaryLabelColor
        let duration = NSStackView(views: [hours, minutes])
        duration.orientation = .horizontal
        duration.spacing = 24
        duration.alignment = .top
        status.font = .systemFont(ofSize: 12)
        status.textColor = .secondaryLabelColor
        status.preferredMaxLayoutWidth = 352

        let stopButton = NSButton(title: "Stop", target: self, action: #selector(stop))
        stopButton.bezelStyle = .rounded
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        startButton.bezelStyle = .rounded
        startButton.target = self
        startButton.action = #selector(start)
        startButton.keyEquivalent = "\r"
        startButton.widthAnchor.constraint(equalToConstant: 80).isActive = true
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttons = NSStackView(views: [stopButton, spacer, cancelButton, startButton])
        buttons.orientation = .horizontal
        buttons.spacing = 8

        for view in [title, subtitle, duration, status, buttons] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            title.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            duration.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            duration.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 24),
            status.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            status.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            status.topAnchor.constraint(equalTo: duration.bottomAnchor, constant: 18),
            buttons.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
        ])
        hours.onChange = { [weak self] in self?.durationChanged() }
        minutes.onChange = { [weak self] in self?.durationChanged() }
        durationChanged()
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(hours.field)
        NSApp.activate(ignoringOtherApps: true)
    }

    func durationChanged() {
        let atMaximum = hours.value == 168
        minutes.stepper.maxValue = atMaximum ? 0 : 59
        if atMaximum { minutes.setValue(0) }
        minutes.field.isEnabled = !atMaximum
        minutes.stepper.isEnabled = !atMaximum
        startButton.isEnabled = durationSeconds != nil
        status.stringValue = durationSeconds == nil
            ? "Choose a duration between 1 minute and 7 days."
            : "Sleep will turn back on automatically."
    }

    @objc private func start() {
        guard window.makeFirstResponder(nil), let seconds = durationSeconds else { return }
        guard runController("start \(seconds)") else { return }
        let end = Date().addingTimeInterval(TimeInterval(seconds))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        status.stringValue = "Awake until \(formatter.string(from: end)). You can close this window."
    }

    @objc private func stop() {
        if runController("stop") { status.stringValue = "Normal sleep is back on." }
    }

    @objc private func cancel() { NSApp.terminate(nil) }

    private func runController(_ arguments: String) -> Bool {
        guard let path = Bundle.main.path(forResource: "controller", ofType: "sh") else {
            showError("The app is missing its timer controller. Please reinstall Stay Awake.")
            return false
        }
        let quotedPath = "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let command = "/bin/sh \(quotedPath) \(arguments)"
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        guard let script = NSAppleScript(source: "do shell script \"\(escaped)\" with administrator privileges") else {
            showError("Could not request administrator access.")
            return false
        }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error {
            if (error[NSAppleScript.errorNumber] as? Int) != -128 {
                showError(error[NSAppleScript.errorMessage] as? String ?? "Could not change the sleep setting.")
            }
            return false
        }
        return true
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Couldn’t update sleep settings"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.beginSheetModal(for: window)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window.makeKeyAndOrderFront(nil)
        return true
    }
}

MainActor.assumeIsolated {
    let application = NSApplication.shared
    application.setActivationPolicy(.regular)
    let delegate = AppDelegate()
    application.delegate = delegate
#if UI_SMOKE_TEST
    application.finishLaunching()
    if delegate.window == nil {
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    }
    runUISmokeTests(delegate)
#else
    withExtendedLifetime(delegate) { application.run() }
#endif
}
