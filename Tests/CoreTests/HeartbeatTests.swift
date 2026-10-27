import Foundation
import ComputerUseContracts
import ComputerUseCore

@MainActor
final class HeartbeatTests: TestCase {
    func testMissingHeartbeatPausesAndInvalidatesOnce() throws {
        var now = 0.0
        let sessions = SessionController(heartbeatTimeout: 15, monotonic: { now })
        let session = try sessions.open(bundleID: SessionController.fixtureBundleID)
        try sessions.approveFromNativeUI()
        now = 15
        expectEqual(sessions.current()?.state, .paused)
        expectEqual(sessions.current()?.pauseReason, .heartbeatLost)
        expectEqual(sessions.current()?.generation, 2)
        expectThrows(try sessions.requireReady(session.id))
        expectThrows(try sessions.heartbeat(session.id, generation: 1))
        expectEqual(sessions.current()?.generation, 2)
    }
    func testHeartbeatRenewsButDoesNotExtendSessionLifetime() throws {
        var now = 0.0
        let sessions = SessionController(heartbeatTimeout: 15, monotonic: { now })
        let session = try sessions.open(bundleID: SessionController.fixtureBundleID)
        try sessions.approveFromNativeUI()
        for second in stride(from: 10, through: 290, by: 10) {
            now = Double(second)
            expectEqual(try sessions.heartbeat(session.id, generation: 1).state, .ready)
        }
        now = 300
        expectEqual(sessions.current()?.state, .expired)
        expectThrows(try sessions.heartbeat(session.id, generation: 1))
        expectEqual(sessions.current()?.generation, 2)
        sessions.cancel()
        expectEqual(sessions.current()?.state, .expired)
    }
    func testHeartbeatCannotApprovePendingSession() throws {
        let sessions = SessionController(heartbeatTimeout: 15)
        let session = try sessions.open(bundleID: SessionController.fixtureBundleID)
        expectThrows(try sessions.heartbeat(session.id, generation: 1))
        expectEqual(sessions.current()?.state, .awaitingApproval)
    }
    func testWrongGenerationCannotRenewLease() throws {
        var now = 0.0
        let sessions = SessionController(heartbeatTimeout: 15, monotonic: { now })
        let session = try sessions.open(bundleID: SessionController.fixtureBundleID)
        try sessions.approveFromNativeUI()
        now = 10
        expectThrows(try sessions.heartbeat(session.id, generation: 2))
        expectThrows(try sessions.heartbeat("other-session", generation: 1))
        now = 15
        expectEqual(sessions.current()?.state, .paused)
        expectEqual(sessions.current()?.pauseReason, .heartbeatLost)
    }
    func testResumeNeedsNativeApprovalAndFreshGeneration() throws {
        var now = 0.0
        let sessions = SessionController(heartbeatTimeout: 15, monotonic: { now })
        let session = try sessions.open(bundleID: SessionController.fixtureBundleID)
        try sessions.approveFromNativeUI()
        now = 15
        try sessions.requestResume(session.id)
        expectThrows(try sessions.requireReady(session.id))
        try sessions.approveFromNativeUI()
        expectThrows(try sessions.heartbeat(session.id, generation: 1))
        now = 25
        expectEqual(try sessions.heartbeat(session.id, generation: 3).state, .ready)
    }
    func testTerminalStateDoesNotChangeOnRepeatedReadsOrCancellation() throws {
        var now = 0.0
        let sessions = SessionController(monotonic: { now })
        let session = try sessions.open(bundleID: SessionController.fixtureBundleID)
        sessions.cancel(); sessions.cancel()
        now = 500
        expectThrows(try sessions.requireReady(session.id))
        expectEqual(sessions.current()?.state, .cancelled)
        expectEqual(sessions.current()?.generation, 2)
    }
    func testNativeOnlySessionDoesNotRequireClientHeartbeat() throws {
        var now = 0.0
        let sessions = SessionController(monotonic: { now })
        let session = try sessions.open(bundleID: SessionController.fixtureBundleID)
        try sessions.approveFromNativeUI()
        now = 100
        expectEqual(try sessions.requireReady(session.id).state, .ready)
    }
}
