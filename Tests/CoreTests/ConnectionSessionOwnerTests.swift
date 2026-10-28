import Foundation
import ComputerUseCore
import ComputerUseContracts

private final class ConnectionLiveness: @unchecked Sendable {
    private let lock = NSLock()
    private var connected = true
    func read() -> Bool { lock.lock(); defer { lock.unlock() }; return connected }
    func disconnect() { lock.lock(); connected = false; lock.unlock() }
}

@MainActor
final class ConnectionSessionOwnerTests: TestCase {
    func testDisconnectedOwnerCancelsBeforeDelayedCallback() throws {
        let sessions = SessionController(heartbeatTimeout: 15)
        var invalidations = 0
        let owner = ConnectionSessionOwner(sessions: sessions) { invalidations += 1 }
        let connection = UUID(), live = ConnectionLiveness()
        let session = try owner.open(connectionID: connection, isConnected: { live.read() })
        expectEqual(session.state, .awaitingApproval)
        // Only test code simulates the native button. Ownership itself has no approval method.
        try sessions.approveFromNativeUI()
        live.disconnect()
        expectThrows(try owner.requireOwnership(connectionID: connection, sessionID: session.id))
        expectEqual(sessions.current()?.state, .cancelled)
        expectEqual(sessions.current()?.generation, session.generation + 1)
        expectEqual(invalidations, 1)
        owner.disconnect(connection)
        expectEqual(invalidations, 1)
    }

    func testReplacementCannotInheritGrantOrBeCancelledByOldPeer() throws {
        let sessions = SessionController()
        var invalidations = 0
        let owner = ConnectionSessionOwner(sessions: sessions) { invalidations += 1 }
        let firstID = UUID(), nextID = UUID()
        let first = try owner.open(connectionID: firstID, isConnected: { true })
        try sessions.approveFromNativeUI()
        expectThrows(try owner.requireOwnership(connectionID: nextID, sessionID: first.id))
        expectThrows(try owner.open(connectionID: nextID, isConnected: { true }))
        try owner.requireOwnership(connectionID: firstID, sessionID: first.id)
        owner.disconnect(firstID)
        let next = try owner.open(connectionID: nextID, isConnected: { true })
        expectEqual(next.state, .awaitingApproval)
        expectFalse(next.id == first.id)
        owner.disconnect(firstID)
        expectEqual(sessions.current()?.id, next.id)
        expectEqual(sessions.current()?.state, .awaitingApproval)
        expectEqual(invalidations, 1)
        expectThrows(try owner.requireOwnership(connectionID: nextID, sessionID: first.id))
        try owner.requireOwnership(connectionID: nextID, sessionID: next.id)
    }

    func testDisconnectDoesNotCancelNativeReplacement() throws {
        let sessions = SessionController()
        var invalidations = 0
        let owner = ConnectionSessionOwner(sessions: sessions) { invalidations += 1 }
        let connection = UUID()
        _ = try owner.open(connectionID: connection, isConnected: { true })
        sessions.cancel()
        let native = try sessions.open(bundleID: SessionController.fixtureBundleID)
        owner.disconnect(connection)
        expectEqual(sessions.current()?.id, native.id)
        expectEqual(sessions.current()?.state, .awaitingApproval)
        expectEqual(invalidations, 0)
        expectThrows(try owner.open(connectionID: UUID(), isConnected: { false }))
        expectEqual(sessions.current()?.id, native.id)
    }
}
