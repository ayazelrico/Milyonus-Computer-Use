import Foundation
import ComputerUseContracts

/// This prototype deliberately restricts mutation to the supplied fixture application.
/// A broader app policy requires its own reviewed adapter and acceptance evidence.
@MainActor
public final class SessionController {
    public nonisolated static let fixtureBundleID = "com.milyonus.computeruse.fixture"
    public private(set) var session: Session?
    private var deadline: TimeInterval = 0
    private var heartbeatDeadline: TimeInterval = 0
    private let heartbeatTimeout: TimeInterval?
    private let monotonic: () -> TimeInterval
    public init(heartbeatTimeout: TimeInterval? = nil, monotonic: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.monotonic = monotonic
        self.heartbeatTimeout = heartbeatTimeout.map { $0.isFinite ? min(60, max(1, $0)) : 15 }
    }
    public func current() -> Session? {
        guard var value = session, ![.cancelled, .expired].contains(value.state) else { return session }
        let now = monotonic()
        if now >= deadline {
            value.state = .expired; value.pauseReason = nil; value.generation += 1; session = value
        } else if value.state == .ready, heartbeatTimeout != nil, now >= heartbeatDeadline {
            value.state = .paused; value.pauseReason = .heartbeatLost; value.generation += 1; session = value
        }
        return session
    }
    /// Heartbeats renew liveness only, never native approval or the overall session lifetime.
    public func heartbeat(_ id: String, generation: Int) throws -> Session {
        let value = try requireReady(id, generation: generation)
        if let heartbeatTimeout { heartbeatDeadline = min(deadline, monotonic() + heartbeatTimeout) }
        return value
    }
    public func open(bundleID: String) throws -> Session {
        _ = current()
        guard bundleID == Self.fixtureBundleID else { throw HarnessError.policyDenied }
        if let existing = session, [.ready, .awaitingApproval, .paused].contains(existing.state) {
            throw HarnessError.leaseBusy
        }
        let value = Session(id: UUID().uuidString, bundleId: bundleID, generation: 1,
                            state: .awaitingApproval, expiresAt: Date().addingTimeInterval(300))
        deadline = monotonic() + 300
        session = value
        return value
    }
    /// Call only from a native user control; never expose this through RPC.
    public func approveFromNativeUI() throws {
        guard var value = session, value.state == .awaitingApproval, monotonic() < deadline else {
            throw HarnessError.unauthorized
        }
        value.state = .ready; session = value
        if let heartbeatTimeout { heartbeatDeadline = min(deadline, monotonic() + heartbeatTimeout) }
    }
    public func requireReady(_ id: String, generation: Int? = nil) throws -> Session {
        guard let value = current(), value.id == id else { throw HarnessError.unauthorized }
        if value.state == .expired { throw HarnessError.timeout }
        guard value.state == .ready else { throw HarnessError.unauthorized }
        if let generation, generation != value.generation { throw HarnessError.staleObservation }
        return value
    }
    public func pause(reason: SessionPauseReason = .requested) {
        guard var value = current(), value.state == .ready else { return }
        value.state = .paused; value.pauseReason = reason; value.generation += 1; session = value
    }
    /// Resuming always requires a new native approval and invalidates old targets.
    public func requestResume(_ id: String) throws {
        guard var value = current(), value.id == id, value.state == .paused, monotonic() < deadline else {
            throw HarnessError.unauthorized
        }
        value.state = .awaitingApproval; value.pauseReason = nil; value.generation += 1; session = value
    }
    public func cancel() {
        guard var value = current(), ![.cancelled, .expired].contains(value.state) else { return }
        value.state = .cancelled; value.pauseReason = nil; value.generation += 1; session = value
    }
    public func assertIdentity(_ id: String) throws {
        guard session?.id == id else { throw HarnessError.unauthorized }
    }
}
