import ComputerUseCore

@MainActor
final class ObservationTraversalBudgetTests: TestCase {
    func testDeadlineIncludesFinalReadAndDoesNotRenew() {
        let start = ContinuousClock.now
        var budget = ObservationTraversalBudget(start: start)
        expectEqual(budget.visit(depth: 0, at: start), true)
        expectEqual(budget.admitText(bytes: 10, at: start.advanced(by: .milliseconds(499))), true)
        expectFalse(budget.finish(at: start.advanced(by: .milliseconds(500))))
        expectEqual(budget.truncated, true)
        expectFalse(budget.finish(at: start.advanced(by: .seconds(2))))
        var lateNode = ObservationTraversalBudget(start: start)
        expectFalse(lateNode.visit(depth: 0, at: start.advanced(by: .milliseconds(500))))
        var lateText = ObservationTraversalBudget(start: start)
        expectFalse(lateText.admitText(bytes: 0, at: start.advanced(by: .milliseconds(500))))
    }
    func testVisitedNodesIncludeNodesWithoutExportedText() {
        let start = ContinuousClock.now
        var budget = ObservationTraversalBudget(start: start)
        for _ in 0..<300 { expectEqual(budget.visit(depth: 0, at: start), true) }
        expectEqual(budget.finish(at: start), true)
        expectFalse(budget.visit(depth: 0, at: start))
        expectFalse(budget.finish(at: start))
    }
    func testDepthAndTextBoundsLatchTruncationWithoutOverflow() {
        let start = ContinuousClock.now
        for depth in [-1, 21, Int.max] {
            var budget = ObservationTraversalBudget(start: start)
            expectFalse(budget.visit(depth: depth, at: start))
            expectFalse(budget.finish(at: start))
        }
        var budget = ObservationTraversalBudget(start: start)
        expectEqual(budget.visit(depth: 20, at: start), true)
        expectEqual(budget.admitText(bytes: 47_999, at: start), true)
        expectEqual(budget.admitText(bytes: 0, at: start), true)
        expectFalse(budget.admitText(bytes: 1, at: start))
        expectFalse(budget.finish(at: start))
        for count in [-1, 48_000, Int.max] {
            var invalid = ObservationTraversalBudget(start: start)
            expectFalse(invalid.admitText(bytes: count, at: start))
            expectFalse(invalid.finish(at: start))
        }
    }
}
