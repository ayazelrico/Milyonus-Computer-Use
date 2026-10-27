import Foundation
import ComputerUseContracts

@MainActor
final class CaptureGeometryTests: TestCase {
    func testUniformScalingPreservesWideAndTallFrames() throws {
        let wide = try CaptureGeometry(bounds: Rect(x: -100, y: 0, width: 4000, height: 1000))
        expectEqual(wide.pixelWidth, 2048); expectEqual(wide.pixelHeight, 512)
        let tall = try CaptureGeometry(bounds: Rect(x: 0, y: -100, width: 1000, height: 4000))
        expectEqual(tall.pixelWidth, 512); expectEqual(tall.pixelHeight, 2048)
        let normal = try CaptureGeometry(bounds: Rect(x: 0, y: 0, width: 620, height: 380))
        expectEqual(normal.pixelWidth, 1240); expectEqual(normal.pixelHeight, 760)
    }
    func testMalformedAndOverflowingBoundsRefused() {
        for bounds in [Rect(x: 0, y: 0, width: .infinity, height: 1),
                       Rect(x: .nan, y: 0, width: 1, height: 1),
                       Rect(x: 0, y: 0, width: 0, height: 1),
                       Rect(x: 1e308, y: 0, width: 1e308, height: 1),
                       Rect(x: 1e308, y: 0, width: 1, height: 1)] {
            expectFalse(bounds.isValid)
            expectThrows(try CaptureGeometry(bounds: bounds))
        }
        let bounds = Rect(x: 0, y: 0, width: 1, height: 1)
        for limit in [0, -1, 2049, Int.max] { expectThrows(try CaptureGeometry(bounds: bounds, maximumEdge: limit)) }
        for scale in [0, -1, 3, Double.nan, .infinity] { expectThrows(try CaptureGeometry(bounds: bounds, preferredScale: scale)) }
    }
    func testHugeFiniteDimensionsDoNotTrapAndTransformsDoNotOverflow() throws {
        let bounds = Rect(x: 0, y: 0, width: 1e308, height: 1e308)
        let size = try CaptureGeometry(bounds: bounds)
        expectEqual(size.pixelWidth, 2048); expectEqual(size.pixelHeight, 2048)
        let transform = FrameTransform(desktopBounds: bounds, pixelWidth: 2048, pixelHeight: 2048)
        let point = try transform.desktopPoint(pixelX: 1024, pixelY: 1024)
        expectEqual(point.x, 5e307); expectEqual(point.y, 5e307)
    }
    func testFractionalAndExtremeAspectRatiosRemainBounded() throws {
        for (width, height) in [(0.1, 0.2), (100000.0, 1.0), (1.0, 100000.0), (1500.25, 900.75)] {
            let size = try CaptureGeometry(bounds: Rect(x: -10, y: -10, width: width, height: height))
            expectEqual((1...2048).contains(size.pixelWidth), true)
            expectEqual((1...2048).contains(size.pixelHeight), true)
            let scale = min(2, 2048 / max(width, height))
            expectEqual(abs(Double(size.pixelWidth) - width * scale) <= 1, true)
            expectEqual(abs(Double(size.pixelHeight) - height * scale) <= 1, true)
        }
    }
}
