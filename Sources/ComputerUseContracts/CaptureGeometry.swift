import Foundation

/// Bounded single-window raster dimensions. Uniform scaling avoids independently
/// stretching each axis when a wide/tall window exceeds the capture limit.
public struct CaptureGeometry: Sendable, Equatable {
    public let pixelWidth: Int
    public let pixelHeight: Int
    public init(bounds: Rect, maximumEdge: Int = 2048, preferredScale: Double = 2) throws {
        guard bounds.isValid, (1...2048).contains(maximumEdge),
              preferredScale.isFinite, preferredScale > 0, preferredScale <= 2 else {
            throw HarnessError.invalidRequest
        }
        let scale = min(preferredScale, Double(maximumEdge) / max(bounds.width, bounds.height))
        let width = max(1, min(Double(maximumEdge), (bounds.width * scale).rounded(.up)))
        let height = max(1, min(Double(maximumEdge), (bounds.height * scale).rounded(.up)))
        guard width.isFinite, height.isFinite else { throw HarnessError.invalidRequest }
        pixelWidth = Int(width); pixelHeight = Int(height)
    }
}
