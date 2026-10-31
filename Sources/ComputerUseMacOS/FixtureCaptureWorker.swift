import AppKit
import CryptoKit
import ComputerUseContracts
import ComputerUseCore

/// Internal collector component; call only from an authenticated, scoped worker.
/// Native approval remains in the broker. This collector never requests permission.
@MainActor
package enum FixtureCaptureWorker {
    package static func collect(_ ticket: ReadWorkerTicket) async throws -> CaptureWorkerReply {
        try ReadWorkerWire.validate(ticket)
        guard ticket.target.windowID != nil else { throw HarnessError.invalidRequest }
        let start = ContinuousClock.now
        let frame = try await ScreenCapture.captureFixture(expectedTarget: ticket.target,
            timeout: ticket.timeout, beforeRevalidation: nil)
        try Task.checkCancellation()
        guard CGPreflightScreenCaptureAccess() else { throw HarnessError.permissionRevoked }
        let metadata = CaptureWorkerMetadata(windowID: frame.windowID,
            pixelWidth: frame.transform.pixelWidth, pixelHeight: frame.transform.pixelHeight,
            pngBytes: frame.png.count, sha256: SHA256.hash(data: frame.png).map { String(format: "%02x", $0) }.joined(),
            bounds: frame.transform.desktopBounds, capturedAt: frame.capturedAt, screenRecordingGranted: true)
        try metadata.validate(target: ticket.target)
        let elapsed = start.duration(to: .now)
        guard elapsed < ticket.timeout else { throw HarnessError.timeout }
        return CaptureWorkerReply(ticket: ticket, metadata: metadata, elapsed: elapsed)
    }
}
