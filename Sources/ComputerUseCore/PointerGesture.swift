import Foundation
import ComputerUseContracts

/// Internal sequence construction, never an authorization grant. The caller must resolve
/// fresh target geometry and authorize every event through InputSequenceExecutor.
public enum PointerGesture {
    public struct Point: Sendable, Equatable {
        public let x: Double
        public let y: Double
        public init(x: Double, y: Double) { self.x = x; self.y = y }
    }
    public struct Region: Sendable {
        public let origin: Point
        public let width: Double
        public let height: Double
        public init(origin: Point, width: Double, height: Double) {
            self.origin = origin; self.width = width; self.height = height
        }
        fileprivate func contains(_ point: Point) -> Bool {
            let values = [origin.x, origin.y, width, height, point.x, point.y,
                          origin.x + width, origin.y + height]
            return values.allSatisfy { $0.isFinite && abs($0) <= 100_000 }
                && width > 0 && height > 0
                && point.x >= origin.x && point.x < origin.x + width
                && point.y >= origin.y && point.y < origin.y + height
        }
    }

    /// Straight-line interpolation stays within the convex target region. Duration is
    /// distributed exactly across segments; the last release has no additional delay.
    public static func drag(from: Point, to: Point, within region: Region,
                            durationMilliseconds: Int = 300, segments: Int = 20) throws -> [InputStep] {
        guard region.contains(from), region.contains(to), from != to else { throw HarnessError.invalidRequest }
        guard (1...120).contains(segments), (1...2000).contains(durationMilliseconds),
              durationMilliseconds >= segments, durationMilliseconds <= segments * 1000 else { throw HarnessError.resourceLimit }
        var steps = [InputStep(.move(x: from.x, y: from.y)), InputStep(.mouseDown(x: from.x, y: from.y))]
        for index in 1...segments {
            let fraction = Double(index) / Double(segments)
            let point = index == segments ? to : Point(x: from.x + (to.x - from.x) * fraction,
                                                      y: from.y + (to.y - from.y) * fraction)
            guard region.contains(point) else { throw HarnessError.invalidRequest }
            steps.append(InputStep(.drag(x: point.x, y: point.y),
                                   delayAfterMilliseconds: durationMilliseconds / segments
                                    + (index <= durationMilliseconds % segments ? 1 : 0)))
        }
        steps.append(InputStep(.mouseUp(x: to.x, y: to.y)))
        return steps
    }

    /// Split signed pixel deltas into bounded chunks while preserving exact totals.
    public static func scroll(at point: Point, within region: Region,
                              vertical: Int32, horizontal: Int32) throws -> [InputStep] {
        guard region.contains(point), vertical != 0 || horizontal != 0 else { throw HarnessError.invalidRequest }
        let magnitude = max(abs(Int64(vertical)), abs(Int64(horizontal)))
        guard magnitude <= 2000 else { throw HarnessError.resourceLimit }
        let chunks = Int32((magnitude + 99) / 100)
        var steps = [InputStep(.move(x: point.x, y: point.y), delayAfterMilliseconds: 10)]
        func portion(_ total: Int32, _ index: Int32) -> Int32 {
            total / chunks + (index < abs(total % chunks) ? (total < 0 ? -1 : 1) : 0)
        }
        for index in 0..<chunks {
            steps.append(InputStep(.scroll(vertical: portion(vertical, index), horizontal: portion(horizontal, index)),
                                   delayAfterMilliseconds: 10))
        }
        return steps
    }
}
