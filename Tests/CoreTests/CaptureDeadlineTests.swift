import Foundation
import ComputerUseContracts
import ComputerUseCore

@MainActor
final class CaptureDeadlineTests: TestCase {
    func testExactBoundaryAndDelayedResultRejected() throws {
        let start = ContinuousClock.now
        let deadline = try CaptureDeadline(start: start, timeout: .seconds(10))
        try deadline.check(at: start)
        try deadline.check(at: start.advanced(by: .seconds(9)))
        for elapsed in [Duration.seconds(10), .seconds(11), .seconds(1000)] {
            expectThrows(try deadline.check(at: start.advanced(by: elapsed))) {
                expectEqual($0 as? HarnessError, .timeout)
            }
        }
    }
    func testRepeatedChecksCannotExtendDeadline() throws {
        let start = ContinuousClock.now
        let deadline = try CaptureDeadline(start: start, timeout: .seconds(2))
        for milliseconds in [1, 100, 500, 1000, 1999] {
            try deadline.check(at: start.advanced(by: .milliseconds(milliseconds)))
        }
        expectThrows(try deadline.check(at: start.advanced(by: .seconds(2)))) {
            expectEqual($0 as? HarnessError, .timeout)
        }
    }
    func testInvalidBudgetsRejected() {
        for timeout in [Duration.zero, .seconds(-1), .seconds(11)] {
            expectThrows(try CaptureDeadline(timeout: timeout)) {
                expectEqual($0 as? HarnessError, .invalidRequest)
            }
        }
    }
    func testCancellationRejectsEvenBeforeExpiry() async throws {
        let task = Task {
            let deadline = try CaptureDeadline()
            withUnsafeCurrentTask { $0?.cancel() }
            try deadline.check()
        }
        do { try await task.value; fail("Cancelled capture admitted") }
        catch { expectEqual(error is CancellationError, true) }
    }
}
