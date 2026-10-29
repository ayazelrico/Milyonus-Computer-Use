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
    private let ownedProcessIdentifier: (@Sendable () -> Int32?)?
    private let lock = NSLock()
    private var started = false
    private var closed = false
    private struct OwnedConnection {
        let channel: NSXPCConnection
        let context: BrokerConnectionContext
        let endpoint: BrokerEndpoint
    }
    private var connections: [UUID: OwnedConnection] = [:]

    public convenience init(serviceName: String, peer: BrokerPeerIdentity, maximumConnections: Int = 4,
                onDisconnect: @escaping @Sendable (UUID) -> Void = { _ in },
                requestHandler: BrokerRequestHandler? = nil, controlHandler: BrokerRequestHandler? = nil) throws {
        guard BrokerPeerIdentity.validIdentifier(serviceName), (1...8).contains(maximumConnections) else {
            throw BrokerConnectionError.invalidService
        }
        self.init(listener: NSXPCListener(machServiceName: serviceName), peer: peer,
                  maximumConnections: maximumConnections, ownedProcessIdentifier: nil,
                  onDisconnect: onDisconnect, requestHandler: requestHandler, controlHandler: controlHandler)
    }

    /// Trusted launcher only. The provider must read the still-owned child's
    /// current running state, not return a PID received in a worker message.
    package convenience init(serviceName: String, peer: BrokerPeerIdentity,
                             ownedProcessIdentifier: @escaping @Sendable () -> Int32?,
                             onDisconnect: @escaping @Sendable (UUID) -> Void = { _ in },
                             requestHandler: BrokerRequestHandler? = nil) throws {
        guard BrokerPeerIdentity.validIdentifier(serviceName) else { throw BrokerConnectionError.invalidService }
        self.init(listener: NSXPCListener(machServiceName: serviceName), peer: peer, maximumConnections: 1,
                  ownedProcessIdentifier: ownedProcessIdentifier, onDisconnect: onDisconnect,
                  requestHandler: requestHandler, controlHandler: nil)
    }

    package convenience init(peer: BrokerPeerIdentity,
                             ownedProcessIdentifier: @escaping @Sendable () -> Int32?,
                             requestHandler: BrokerRequestHandler? = nil) {
        self.init(listener: .anonymous(), peer: peer, maximumConnections: 1,
                  ownedProcessIdentifier: ownedProcessIdentifier, onDisconnect: { _ in },
                  requestHandler: requestHandler, controlHandler: nil)
    }

    private init(listener: NSXPCListener, peer: BrokerPeerIdentity, maximumConnections: Int,
                 ownedProcessIdentifier: (@Sendable () -> Int32?)?,
                 onDisconnect: @escaping @Sendable (UUID) -> Void,
                 requestHandler: BrokerRequestHandler?, controlHandler: BrokerRequestHandler?) {
        self.listener = listener
        self.peer = peer
        self.maximumConnections = maximumConnections
        self.onDisconnect = onDisconnect
        self.requestHandler = requestHandler
        self.controlHandler = controlHandler
        self.ownedProcessIdentifier = ownedProcessIdentifier
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

    package var endpoint: NSXPCListenerEndpoint { listener.endpoint }

    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection channel: NSXPCConnection) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard started, !closed, connections.count < maximumConnections else { return false }
        let acceptedPID = channel.processIdentifier
        if let ownedProcessIdentifier {
            guard acceptedPID > 0, ownedProcessIdentifier() == acceptedPID else { return false }
        }
        let provider = ownedProcessIdentifier
        let context = BrokerConnectionContext(isPeerLive: {
            provider.map { $0() == acceptedPID } ?? true
        })
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
