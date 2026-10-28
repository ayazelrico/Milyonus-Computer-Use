import Foundation
import ComputerUseContracts

/// Server-side session ownership. Connection IDs and liveness come from the local transport,
/// never from a request payload. This type cannot create a native approval.
@MainActor
public final class ConnectionSessionOwner {
    private let sessions: SessionController
    private let invalidateTargets: () -> Void
    private var binding: Binding?
    private struct Binding {
        let connectionID: UUID
        let sessionID: String
        let isConnected: @Sendable () -> Bool
    }

    public init(sessions: SessionController, invalidateTargets: @escaping () -> Void) {
        self.sessions = sessions
        self.invalidateTargets = invalidateTargets
    }

    public func open(connectionID: UUID, isConnected: @escaping @Sendable () -> Bool) throws -> Session {
        guard isConnected() else { throw HarnessError.unauthorized }
        let session = try sessions.open(bundleID: SessionController.fixtureBundleID)
        binding = Binding(connectionID: connectionID, sessionID: session.id, isConnected: isConnected)
        // Transport disconnection may race creation even though session state is actor-isolated.
        guard isConnected() else {
            disconnect(connectionID)
            throw HarnessError.unauthorized
        }
        return session
    }

    /// Use before dispatch and again at every asynchronous execution admission point.
    /// Session readiness/generation checks remain the execution engine's responsibility.
    public func requireOwnership(connectionID: UUID, sessionID: String) throws {
        guard let binding, binding.connectionID == connectionID, binding.sessionID == sessionID,
              sessions.current()?.id == sessionID else { throw HarnessError.unauthorized }
        guard binding.isConnected() else {
            disconnect(connectionID)
            throw HarnessError.unauthorized
        }
        guard let session = sessions.current(), ![.cancelled, .expired].contains(session.state) else {
            throw HarnessError.unauthorized
        }
    }

    /// A delayed disconnect must never cancel a replacement connection's or native UI's session.
    public func disconnect(_ connectionID: UUID) {
        guard let binding, binding.connectionID == connectionID else { return }
        self.binding = nil
        guard sessions.session?.id == binding.sessionID else { return }
        sessions.cancel()
        invalidateTargets()
    }
}
