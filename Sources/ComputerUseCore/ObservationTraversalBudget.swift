import ComputerUseContracts

/// Admission limits for the fixture AX traversal, not a hard AX-call timeout.
package struct ObservationTraversalBudget {
    private let deadline: ContinuousClock.Instant
    private var visitedCount = 0
    private var textBytes = 0
    package private(set) var truncated = false

    package init(start: ContinuousClock.Instant = .now) {
        deadline = start.advanced(by: .milliseconds(500))
    }
    package mutating func visit(depth: Int, at now: ContinuousClock.Instant = .now) -> Bool {
        guard depth >= 0, depth <= 20, visitedCount < 300, now < deadline else {
            truncated = true
            return false
        }
        visitedCount += 1
        return true
    }
    package mutating func admitText(bytes: Int, at now: ContinuousClock.Instant = .now) -> Bool {
        // Subtraction avoids overflowing on malformed or unexpectedly large counts.
        guard bytes >= 0, bytes < 48_000 - textBytes, now < deadline else {
            truncated = true
            return false
        }
        textBytes += bytes
        return true
    }
    package mutating func finish(at now: ContinuousClock.Instant = .now) -> Bool {
        if now >= deadline { truncated = true }
        return !truncated
    }
}
