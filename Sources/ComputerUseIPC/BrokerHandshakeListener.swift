import Foundation

/// Bounded handshake-only server. A transport connection is never a native session or approval.
/// Mutable listener state is protected by lock; callbacks run outside that lock on XPC queues.
public final class BrokerHandshakeListener: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
    private let listener: NSXPCListener
    private let peer: BrokerPeerIdentity
    private let maximumConnections: Int
    private let onDisconnect: @Sendable (UUID) -> Void
    private let lock = NSLock()
    private var started = false
    private var closed = false
    private var connections: [UUID: NSXPCConnection] = [:]

    public init(serviceName: String, peer: BrokerPeerIdentity, maximumConnections: Int = 4,
                onDisconnect: @escaping @Sendable (UUID) -> Void = { _ in }) throws {
        guard BrokerPeerIdentity.validIdentifier(serviceName), (1...8).contains(maximumConnections) else {
            throw BrokerConnectionError.invalidService
        }
        listener = NSXPCListener(machServiceName: serviceName)
        self.peer = peer
        self.maximumConnections = maximumConnections
        self.onDisconnect = onDisconnect
        super.init()
        listener.delegate = self
    }

    public func start() throws {
        lock.lock(); defer { lock.unlock() }
        guard !started, !closed else { throw BrokerConnectionError.alreadyConnected }
        started = true
        listener.resume()
    }

    public var connectionCount: Int {
        lock.lock(); defer { lock.unlock() }
        return connections.count
    }

    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection channel: NSXPCConnection) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard started, !closed, connections.count < maximumConnections else { return false }
        let id = UUID()
        channel.setCodeSigningRequirement(peer.requirement)
        channel.exportedInterface = NSXPCInterface(with: BrokerHandshake.self)
        channel.exportedObject = HandshakeEndpoint()
        channel.invalidationHandler = { @Sendable [weak self] in self?.remove(id) }
        channel.interruptionHandler = { @Sendable [weak self] in self?.remove(id) }
        connections[id] = channel
        channel.resume()
        return true
    }

    private func remove(_ id: UUID) {
        lock.lock()
        let channel = connections.removeValue(forKey: id)
        lock.unlock()
        guard let channel else { return }
        channel.invalidate()
        onDisconnect(id)
    }

    public func close() {
        lock.lock()
        guard !closed else { lock.unlock(); return }
        closed = true
        let owned = connections
        connections.removeAll()
        lock.unlock()
        listener.invalidate()
        for (id, channel) in owned {
            channel.invalidate()
            onDisconnect(id)
        }
    }

    deinit { close() }
}

private final class HandshakeEndpoint: NSObject, BrokerHandshake {
    func hello(_ nonce: String, reply: @escaping (String, Int) -> Void) {
        // Only a bounded public challenge is echoed; never decode native action intent here.
        guard nonce.utf8.count == 36, UUID(uuidString: nonce) != nil else { reply("", 0); return }
        reply(nonce, 1)
    }
}
