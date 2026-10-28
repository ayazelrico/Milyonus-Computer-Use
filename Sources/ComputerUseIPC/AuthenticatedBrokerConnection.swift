import Foundation

/// First exchange contains only a fresh public nonce and protocol version. No desktop data or grants.
@objc(MilyonusBrokerHandshake)
public protocol BrokerHandshake {
    func hello(_ nonce: String, reply: @escaping (String, Int) -> Void)
}

/// Connection authentication only. Deliberately exposes no native actions or underlying XPC proxy.
@MainActor
public final class AuthenticatedBrokerConnection {
    public private(set) var isAuthenticated = false
    private var connection: NSXPCConnection?
    private var generation = UUID()
    private var pending: CheckedContinuation<Void, Error>?
    private var timer: Task<Void, Never>?

    public init() {}

    public func connect(serviceName: String, peer: BrokerPeerIdentity, timeoutSeconds: Int = 5) async throws {
        guard BrokerPeerIdentity.validIdentifier(serviceName), (1...30).contains(timeoutSeconds) else {
            throw BrokerConnectionError.invalidService
        }
        try await connect(channel: NSXPCConnection(machServiceName: serviceName), peer: peer, timeoutSeconds: timeoutSeconds)
    }

    package func connect(endpoint: NSXPCListenerEndpoint, peer: BrokerPeerIdentity, timeoutSeconds: Int = 5) async throws {
        guard (1...30).contains(timeoutSeconds) else { throw BrokerConnectionError.invalidService }
        try await connect(channel: NSXPCConnection(listenerEndpoint: endpoint), peer: peer, timeoutSeconds: timeoutSeconds)
    }

    private func connect(channel: NSXPCConnection, peer: BrokerPeerIdentity, timeoutSeconds: Int) async throws {
        guard connection == nil, pending == nil else { throw BrokerConnectionError.alreadyConnected }
        try Task.checkCancellation()
        let epoch = UUID()
        generation = epoch
        let nonce = UUID().uuidString
        channel.remoteObjectInterface = NSXPCInterface(with: BrokerHandshake.self)
        channel.setCodeSigningRequirement(peer.requirement)
        channel.invalidationHandler = { @Sendable [weak self] in
            Task { @MainActor in self?.fail(.authenticationFailed, epoch: epoch) }
        }
        channel.interruptionHandler = { @Sendable [weak self] in
            Task { @MainActor in self?.fail(.authenticationFailed, epoch: epoch) }
        }
        connection = channel
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending = continuation
                timer = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(timeoutSeconds)) } catch { return }
                    self?.fail(.timeout, epoch: epoch)
                }
                channel.resume()
                guard let proxy = channel.remoteObjectProxyWithErrorHandler({ @Sendable [weak self] _ in
                    Task { @MainActor in self?.fail(.authenticationFailed, epoch: epoch) }
                }) as? BrokerHandshake else { fail(.protocolMismatch, epoch: epoch); return }
                proxy.hello(nonce) { @Sendable [weak self] echoed, version in
                    Task { @MainActor in
                        guard let self, self.generation == epoch, self.pending != nil else { return }
                        guard echoed == nonce, version == 1 else { self.fail(.protocolMismatch, epoch: epoch); return }
                        self.isAuthenticated = true
                        self.timer?.cancel(); self.timer = nil
                        let pending = self.pending; self.pending = nil
                        pending?.resume()
                    }
                }
            }
            if Task.isCancelled { close(); throw BrokerConnectionError.cancelled }
        } onCancel: {
            Task { @MainActor [weak self] in self?.fail(.cancelled, epoch: epoch) }
        }
    }

    public func close() { fail(.cancelled, epoch: generation) }

    private func fail(_ error: BrokerConnectionError, epoch: UUID) {
        guard generation == epoch else { return }
        generation = UUID()
        isAuthenticated = false
        timer?.cancel(); timer = nil
        let continuation = pending; pending = nil
        let old = connection; connection = nil
        old?.invalidate()
        continuation?.resume(throwing: error)
    }

    isolated deinit { timer?.cancel(); connection?.invalidate() }
}
