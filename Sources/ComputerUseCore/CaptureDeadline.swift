import Foundation
import ComputerUseContracts

/// Monotonic admission deadline for capture results. This does not interrupt a
/// stalled framework call; callers check it before work and after each await.
public struct CaptureDeadline: Sendable {
    private let deadline: ContinuousClock.Instant
    public init(timeout: Duration = .seconds(10)) throws {
        try self.init(start: .now, timeout: timeout)
    }
    package init(start: ContinuousClock.Instant, timeout: Duration) throws {
        guard timeout > .zero, timeout <= .seconds(10) else { throw HarnessError.invalidRequest }
        deadline = start.advanced(by: timeout)
    }
    public func check() throws { try check(at: .now) }
    package func check(at now: ContinuousClock.Instant) throws {
        try Task.checkCancellation()
        guard now < deadline else { throw HarnessError.timeout }
    }
}
