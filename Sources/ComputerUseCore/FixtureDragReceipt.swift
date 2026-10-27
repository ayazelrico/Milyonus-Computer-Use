import Foundation
import ComputerUseContracts

/// Parses independent fixture state. Neither parsing nor matching authorizes input.
public struct FixtureDragReceipt: Sendable {
    public let count: Int
    public let fromX: Int
    public let fromY: Int
    public let toX: Int
    public let toY: Int
    public init(_ value: String) throws {
        guard value.utf8.count <= 128, value.hasPrefix("Drag completed ") else { throw HarnessError.verificationFailed }
        let fields = value.dropFirst("Drag completed ".count).components(separatedBy: ": ")
        guard fields.count == 2, let count = Int(fields[0]), count > 0, count < Int.max else { throw HarnessError.verificationFailed }
        let points = fields[1].components(separatedBy: " to ")
        guard points.count == 2 else { throw HarnessError.verificationFailed }
        let pairs = points.map { $0.components(separatedBy: ",") }
        guard pairs.allSatisfy({ $0.count == 2 }) else { throw HarnessError.verificationFailed }
        let components = pairs.flatMap { $0 }
        guard components.count == 4 else { throw HarnessError.verificationFailed }
        let coordinates = components.compactMap(Int.init)
        guard coordinates.count == 4, coordinates.allSatisfy({ (0...100_000).contains($0) }) else { throw HarnessError.verificationFailed }
        self.count = count; fromX = coordinates[0]; fromY = coordinates[1]; toX = coordinates[2]; toY = coordinates[3]
    }
    public static func previousCount(_ value: String) throws -> Int {
        if value == "No drag completed" { return 0 }
        return try Self(value).count
    }
    public func matches(previousCount: Int, width: Double, height: Double) -> Bool {
        guard previousCount >= 0, previousCount < Int.max, count == previousCount + 1,
              width.isFinite, height.isFinite, width >= 40, width <= 100_000,
              height >= 20, height <= 100_000 else { return false }
        // Integer fixture coordinates may round by a point during native conversion.
        return abs(Double(fromX) - width / 4) <= 2 && abs(Double(toX) - width * 3 / 4) <= 2
            && abs(Double(fromY) - height / 2) <= 2 && abs(Double(toY) - height / 2) <= 2
    }
}
