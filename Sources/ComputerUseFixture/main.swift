import AppKit

@MainActor
final class FixtureDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let input: NSTextField = CommandLine.arguments.contains("--ax-stall-on-signal")
        ? FixtureAXTextField(string: "") : NSTextField(string: "")
    let status = NSTextField(labelWithString: "Not saved")
    var saves = 0
    private var closeSignal: DispatchSourceSignal?
    private var hideSignal: DispatchSourceSignal?
    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--ax-stall-on-signal") { FixtureAXStall.shared.install() }
        let gestures = CommandLine.arguments.contains("--gesture-fixture")
        if gestures { _ = FixtureEventTrace.shared }
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: gestures ? 680 : 380),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Computer Use Fixture"
        input.placeholderString = "Enter fixture text"
        input.setAccessibilityIdentifier("fixture.input")
        input.widthAnchor.constraint(equalToConstant: 480).isActive = true
        let save = NSButton(title: "Save fixture value", target: self, action: #selector(saveValue))
        save.setAccessibilityIdentifier("fixture.save")
        status.setAccessibilityIdentifier("fixture.status")
        let disabled = NSButton(title: "Disabled action", target: nil, action: nil)
        disabled.isEnabled = false
        let secure = NSSecureTextField(string: "synthetic-secret-never-export")
        secure.setAccessibilityIdentifier("fixture.secure")
        let stack = NSStackView(views: [NSTextField(labelWithString: "Local-only automation fixture"), input, save, status, disabled, secure])
        if gestures { stack.addArrangedSubview(makeGestureFixture()) }
        stack.orientation = .vertical; stack.spacing = 16; stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.centerXAnchor.constraint(equalTo: window.contentView!.centerXAnchor),
                                     stack.centerYAnchor.constraint(equalTo: window.contentView!.centerYAnchor)])
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        // Explicit test-only operator hook: close this fixture's own window without physical input.
        if CommandLine.arguments.contains("--close-on-test-signal") {
            signal(SIGUSR1, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
            source.setEventHandler { [weak self] in
                MainActor.assumeIsolated { self?.window.performClose(nil) }
            }
            closeSignal = source
            source.activate()
        }
        if CommandLine.arguments.contains("--hide-on-test-signal") {
            signal(SIGUSR2, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: SIGUSR2, queue: .main)
            source.setEventHandler {
                MainActor.assumeIsolated { NSApp.hide(nil) }
            }
            hideSignal = source
            source.activate()
        }
    }
    @objc func saveValue() {
        saves += 1
        status.stringValue = "Saved \(saves): \(input.stringValue)"
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
// File-admission probe exits before creating AppKit UI or installing signals.
if CommandLine.arguments.contains("--validate-ax-stall-trace") {
    let valid = FixtureAXStall.shared.available
    print(valid ? "{\"traceAvailable\":true,\"uiLaunched\":false}" : "{\"traceAvailable\":false,\"uiLaunched\":false}")
    exit(valid ? 0 : 1)
}
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = FixtureDelegate()
app.delegate = delegate
app.run()
