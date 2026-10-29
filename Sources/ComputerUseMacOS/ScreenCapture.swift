import AppKit
import ScreenCaptureKit
import ComputerUseContracts
import ComputerUseCore

public struct CapturedFrame: Sendable {
    public let png: Data
    public let transform: FrameTransform
    public let windowID: UInt32
    public let capturedAt: Date
}

@MainActor
public enum ScreenCapture {
    public static func fixtureWindowInventory() async throws -> [[String: String]] {
        let deadline = try CaptureDeadline()
        try deadline.check()
        guard CGPreflightScreenCaptureAccess() else { throw HarnessError.permissionRequired }
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
        try deadline.check()
        var result: [[String: String]] = []
        for window in content.windows where window.owningApplication?.bundleIdentifier == "com.milyonus.computeruse.fixture" {
            try deadline.check()
            guard result.count < 100 else { throw HarnessError.resourceLimit }
            var item: [String: String] = [:]
            item["id"] = String(window.windowID)
            item["title"] = window.title ?? ""
            item["layer"] = String(window.windowLayer)
            item["onScreen"] = String(window.isOnScreen)
            item["width"] = String(Double(window.frame.width))
            item["height"] = String(Double(window.frame.height))
            result.append(item)
        }
        try deadline.check()
        guard CGPreflightScreenCaptureAccess() else { throw HarnessError.permissionRevoked }
        return result
    }
    /// Raw frames stay in memory. Callers must separately authorize model egress.
    public static func captureFixture() async throws -> CapturedFrame {
        let deadline = try CaptureDeadline()
        try deadline.check()
        _ = NSApplication.shared // Initialize AppKit/WindowServer when called from the diagnostic CLI.
        guard CGPreflightScreenCaptureAccess() else { throw HarnessError.permissionRequired }
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
        try deadline.check()
        let snapshots = content.windows.map(snapshot)
        let selected = try FixtureCaptureSelection.selectIndex(in: snapshots)
        let window = content.windows[selected]
        let expected = snapshots[selected]
        let bounds = expected.bounds
        let geometry = try CaptureGeometry(bounds: bounds)
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        configuration.width = geometry.pixelWidth
        configuration.height = geometry.pixelHeight
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        configuration.capturesAudio = false
        configuration.colorSpaceName = CGColorSpace.sRGB
        try deadline.check()
        let captureStartedAt = Date()
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        try deadline.check()
        guard image.width > 0, image.height > 0, image.width <= 2048, image.height <= 2048 else {
            throw HarnessError.resourceLimit
        }
        guard CGPreflightScreenCaptureAccess() else { throw HarnessError.permissionRevoked }
        // A moved/resized/replaced window must not yield a frame with an old transform.
        let current = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
        try deadline.check()
        guard CGPreflightScreenCaptureAccess() else { throw HarnessError.permissionRevoked }
        try FixtureCaptureSelection.validateCurrent(current.windows.map(snapshot), expected: expected)
        try deadline.check()
        let representation = NSBitmapImageRep(cgImage: image)
        guard let png = representation.representation(using: .png, properties: [:]), png.count <= 8 * 1024 * 1024 else {
            throw HarnessError.resourceLimit
        }
        try deadline.check()
        guard CGPreflightScreenCaptureAccess() else { throw HarnessError.permissionRevoked }
        return CapturedFrame(png: png, transform: FrameTransform(
            desktopBounds: bounds,
            pixelWidth: image.width, pixelHeight: image.height), windowID: window.windowID, capturedAt: captureStartedAt)
    }
    private static func snapshot(_ window: SCWindow) -> FixtureCaptureWindow {
        FixtureCaptureWindow(windowID: window.windowID,
            processID: window.owningApplication?.processID,
            bundleIdentifier: window.owningApplication?.bundleIdentifier,
            title: window.title, layer: window.windowLayer,
            bounds: Rect(x: window.frame.minX, y: window.frame.minY,
                width: window.frame.width, height: window.frame.height))
    }

}
