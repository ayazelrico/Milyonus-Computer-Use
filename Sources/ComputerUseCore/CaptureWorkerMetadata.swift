import Foundation
import ComputerUseContracts

/// Values only: no pixels, path, native handle or authority to use coordinates.
package struct CaptureWorkerMetadata: Codable, Sendable, Equatable {
    package let windowID: UInt32
    package let pixelWidth: Int
    package let pixelHeight: Int
    package let pngBytes: Int
    package let sha256: String
    package let bounds: Rect
    package let capturedAt: Date
    package let screenRecordingGranted: Bool

    package init(windowID: UInt32, pixelWidth: Int, pixelHeight: Int, pngBytes: Int,
                 sha256: String, bounds: Rect, capturedAt: Date, screenRecordingGranted: Bool) {
        self.windowID = windowID; self.pixelWidth = pixelWidth; self.pixelHeight = pixelHeight
        self.pngBytes = pngBytes; self.sha256 = sha256; self.bounds = bounds
        self.capturedAt = capturedAt; self.screenRecordingGranted = screenRecordingGranted
    }

    package func validate(target: ReadWorkerTarget) throws {
        guard target.windowID == windowID, windowID > 0, screenRecordingGranted,
              (1...2048).contains(pixelWidth), (1...2048).contains(pixelHeight),
              (1...(8 * 1024 * 1024)).contains(pngBytes), bounds.isValid,
              capturedAt.timeIntervalSince1970.isFinite,
              sha256.utf8.count == 64, sha256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
            throw HarnessError.protocolMismatch
        }
        _ = try CaptureGeometry(bounds: bounds)
    }
}

package struct CaptureWorkerReply: Sendable {
    package let ticket: ReadWorkerTicket
    package let metadata: CaptureWorkerMetadata
    package let elapsed: Duration
    package init(ticket: ReadWorkerTicket, metadata: CaptureWorkerMetadata, elapsed: Duration) {
        self.ticket = ticket; self.metadata = metadata; self.elapsed = elapsed
    }
}
