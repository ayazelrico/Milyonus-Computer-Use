import Foundation

/// Bounded authenticated transport server. A transport connection is never a native session or approval.
/// Mutable listener state is protected by lock; callbacks run outside that lock on XPC queues.
public final class BrokerHandshakeListener: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
    private let listener: NSXPCListener
    private let peer: BrokerPeerIdentity
    private let maximumConnections: Int
    private let onDisconnect: @Sendable (UUID) -> Void
    private let requestHandler: BrokerRequestHandler?
    private let controlHandler: BrokerRequestHandler?
    private let lock = NSLock()
    private var started = false
    private var closed = false
    private struct OwnedConnection {
        let channel: NSXPCConnection
        let context: BrokerConnectionContext
        let endpoint: BrokerEndpoint
    }
    private var connections: [UUID: OwnedConnection] = [:]

    public init(serviceName: String, peer: BrokerPeerIdentity, maximumConnections: Int = 4,
                onDisconnect: @escaping @Sendable (UUID) -> Void = { _ in },
                requestHandler: BrokerRequestHandler? = nil, controlHandler: BrokerRequestHandler? = nil) throws {
        guard BrokerPeerIdentity.validIdentifier(serviceName), (1...8).contains(maximumConnections) else {
            throw BrokerConnectionError.invalidService
        }
        listener = NSXPCListener(machServiceName: serviceName)
        self.peer = peer
        self.maximumConnections = maximumConnections
        self.onDisconnect = onDisconnect
        self.requestHandler = requestHandler
        self.controlHandler = controlHandler
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
        let context = BrokerConnectionContext()
        let id = context.id
        channel.setCodeSigningRequirement(peer.requirement)
        let endpoint = BrokerEndpoint(context: context, handler: requestHandler, controlHandler: controlHandler)
        channel.exportedInterface = NSXPCInterface(with: BrokerRequestChannel.self)
        channel.exportedObject = endpoint
        channel.invalidationHandler = { @Sendable [weak self] in self?.remove(id) }
        channel.interruptionHandler = { @Sendable [weak self] in self?.remove(id) }
        connections[id] = OwnedConnection(channel: channel, context: context, endpoint: endpoint)
        channel.resume()
        return true
    }

    private func remove(_ id: UUID) {
        lock.lock()
        let owned = connections.removeValue(forKey: id)
        owned?.context.revoke()
        lock.unlock()
        guard let owned else { return }
        owned.endpoint.cancel()
        owned.channel.invalidate()
        onDisconnect(id)
    }

    public func close() {
        lock.lock()
        guard !closed else { lock.unlock(); return }
        closed = true
        let owned = connections
        connections.removeAll()
        for connection in owned.values { connection.context.revoke() }
        lock.unlock()
        listener.invalidate()
        for (id, connection) in owned {
            connection.endpoint.cancel()
            connection.channel.invalidate()
            onDisconnect(id)
        }
    }

    deinit { close() }
}
