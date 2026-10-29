import Foundation

/// Server-created transport identity. Never serialize this as an authorization token.
/// Revocation is synchronous on the XPC queue, before asynchronous core cleanup.
public final class BrokerConnectionContext: @unchecked Sendable {
    public let id = UUID()
    private let lock = NSLock()
    private var connected = true
    private let isPeerLive: @Sendable () -> Bool
    package init(isPeerLive: @escaping @Sendable () -> Bool = { true }) { self.isPeerLive = isPeerLive }
    public var isConnected: Bool {
        lock.lock(); let live = connected; lock.unlock()
        // Never invoke a trusted owner's callback while holding the context lock.
        guard live else { return false }
        guard isPeerLive() else { revoke(); return false }
        lock.lock(); defer { lock.unlock() }
        return connected
    }
    package func revoke() {
        lock.lock(); connected = false; lock.unlock()
    }
}
