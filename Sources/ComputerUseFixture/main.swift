import AppKit

@MainActor
final class FixtureDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let input = NSTextField(string: "")
    let status = NSTextField(labelWithString: "Not saved")
    var saves = 0
    func applicationDidFinishLaunching(_ notification: Notification) {
        let gestures = CommandLine.arguments.contains("--gesture-fixture")
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
    }
    @objc func saveValue() {
        saves += 1
        status.stringValue = "Saved \(saves): \(input.stringValue)"
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = FixtureDelegate()
app.delegate = delegate
app.run()
