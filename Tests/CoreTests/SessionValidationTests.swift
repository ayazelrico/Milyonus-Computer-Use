import Foundation
import ComputerUseContracts
import ComputerUseCore

@MainActor
final class SessionValidationTests: TestCase {
    func session(state: SessionState = .ready) -> Session {
        Session(id: "session", bundleId: "com.milyonus.computeruse.fixture", generation: 1,
                state: state, expiresAt: Date(timeIntervalSinceReferenceDate: 100))
    }
    func testPauseReasonBelongsOnlyToPausedState() throws {
        for state in [SessionState.awaitingApproval, .ready, .paused, .cancelled, .expired] {
            var value = session(state: state)
            try value.validate() // Missing optional reasons remain compatible.
            for reason in [SessionPauseReason.requested, .userInput, .environmentChanged, .heartbeatLost, .executionUncertain] {
                value.pauseReason = reason
                if state == .paused { try value.validate() }
                else { expectThrows(try value.validate()) { expectEqual($0 as? HarnessError, .protocolMismatch) } }
            }
        }
    }
    func testMetadataBoundsAndFiniteTime() throws {
        let changes: [(inout Session) -> Void] = [
            { $0.id = "" }, { $0.id = "../invalid" }, { $0.id = String(repeating: "x", count: 129) },
            { $0.bundleId = "" }, { $0.bundleId = "app\0suffix" }, { $0.bundleId = String(repeating: "😀", count: 64) },
            { $0.generation = 0 }, { $0.generation = -1 },
            { $0.expiresAt = Date(timeIntervalSinceReferenceDate: .infinity) },
            { $0.expiresAt = Date(timeIntervalSinceReferenceDate: .nan) }
        ]
        for change in changes {
            var value = session(); change(&value)
            expectThrows(try value.validate()) { expectEqual($0 as? HarnessError, .protocolMismatch) }
        }
        var boundary = session()
        boundary.id = String(repeating: "x", count: 128)
        boundary.bundleId = String(repeating: "a", count: 255)
        try boundary.validate() // Finite historical dates are diagnostic, not a lease check.
    }
    func testNativeControllerTransitionsRemainConsistent() throws {
        var now = 0.0
        let controller = SessionController(heartbeatTimeout: 15, monotonic: { now })
        let first = try controller.open(bundleID: SessionController.fixtureBundleID)
        try first.validate()
        try controller.approveFromNativeUI()
        try requireValue(controller.current()).validate()
        now = 15
        let paused = try requireValue(controller.current()); try paused.validate()
        expectEqual(paused.pauseReason, .heartbeatLost)
        try controller.requestResume(first.id)
        try requireValue(controller.current()).validate()
        try controller.approveFromNativeUI()
        let resumed = try requireValue(controller.current()); try resumed.validate()
        expectEqual(resumed.pauseReason, nil)
        controller.cancel()
        let cancelled = try requireValue(controller.current()); try cancelled.validate()
        expectEqual(cancelled.state, .cancelled)
        _ = try controller.open(bundleID: SessionController.fixtureBundleID)
        now = 315
        let expired = try requireValue(controller.current()); try expired.validate()
        expectEqual(expired.state, .expired)
    }
}
