import AppKit

/// Fixed local capture marker; enabled only by the capture acceptance launcher.
@MainActor
final class FixtureCaptureMarker: NSView {
    override var intrinsicContentSize: NSSize { NSSize(width: 120, height: 32) }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let colors = [NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1),
                      NSColor(srgbRed: 0, green: 1, blue: 0, alpha: 1),
                      NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)]
        for (index, color) in colors.enumerated() {
            color.setFill()
            NSRect(x: CGFloat(index * 40), y: 0, width: 40, height: 32).fill()
        }
    }
}
