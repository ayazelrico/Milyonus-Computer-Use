import AppKit

/// Opt-in synthetic test material. Does not change the default edit/save fixture.
@MainActor
final class GestureCanvas: NSView {
    private var start: NSPoint?
    private var last: NSPoint?
    private var completed = 0
    let result: NSTextField
    init(result: NSTextField) {
        self.result = result
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityEnabled(true)
        setAccessibilityRole(.group)
        setAccessibilityIdentifier("fixture.drag.canvas")
        setAccessibilityLabel("Synthetic drag target")
    }
    required init?(coder: NSCoder) { nil }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill(); bounds.fill()
        NSColor.systemBlue.setStroke()
        if let start, let last {
            let path = NSBezierPath(); path.move(to: start); path.line(to: last)
            path.lineWidth = 3; path.stroke()
        }
    }
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        start = bounds.contains(point) ? point : nil
        last = start; needsDisplay = true
        result.stringValue = "Drag in progress"
    }
    override func mouseDragged(with event: NSEvent) {
        guard start != nil else { return }
        last = convert(event.locationInWindow, from: nil); needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        guard let start else { return }
        let end = convert(event.locationInWindow, from: nil)
        last = end; self.start = nil; needsDisplay = true
        guard bounds.contains(end), hypot(end.x - start.x, end.y - start.y) >= 10 else {
            result.stringValue = "Drag rejected"; return
        }
        completed += 1
        result.stringValue = "Drag completed \(completed): \(Int(start.x)),\(Int(start.y)) to \(Int(end.x)),\(Int(end.y))"
    }
}

@MainActor
func makeGestureFixture() -> NSView {
    let result = NSTextField(labelWithString: "No drag completed")
    result.setAccessibilityIdentifier("fixture.drag.status")
    let canvas = GestureCanvas(result: result)
    canvas.widthAnchor.constraint(equalToConstant: 480).isActive = true
    canvas.heightAnchor.constraint(equalToConstant: 100).isActive = true
    let scroll = NSScrollView()
    scroll.setAccessibilityIdentifier("fixture.scroll")
    scroll.hasVerticalScroller = true
    let rows = NSStackView(views: (1...30).map { index in
        let row = NSTextField(labelWithString: "Synthetic scroll row \(index)")
        row.setAccessibilityIdentifier("fixture.scroll.row.\(index)")
        return row
    })
    rows.orientation = .vertical; rows.spacing = 12
    rows.frame = NSRect(x: 0, y: 0, width: 460, height: 950)
    scroll.documentView = rows
    scroll.widthAnchor.constraint(equalToConstant: 480).isActive = true
    scroll.heightAnchor.constraint(equalToConstant: 110).isActive = true
    let stack = NSStackView(views: [canvas, result, scroll])
    stack.orientation = .vertical; stack.spacing = 8
    return stack
}
