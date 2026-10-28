import Foundation

/// Server-created transport identity. Never serialize this as an authorization token.
/// Revocation is synchronous on the XPC queue, before asynchronous core cleanup.
public final class BrokerConnectionContext: @unchecked Sendable {
    public let id = UUID()
    private let lock = NSLock()
    private var connected = true
    package init() {}
    public var isConnected: Bool {
        lock.lock(); defer { lock.unlock() }
        return connected
    }
    package func revoke() {
        lock.lock(); connected = false; lock.unlock()
    }
}
