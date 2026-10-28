import Foundation

@objc(MilyonusBrokerRequestChannel)
public protocol BrokerRequestChannel: BrokerHandshake {
    func request(_ data: Data, reply: @escaping @Sendable (Data?, String?) -> Void)
}

public typealias BrokerRequestHandler = @Sendable (BrokerConnectionContext, Data) async -> Data

/// One bounded request per connection. This transport endpoint cannot approve native sessions.
final class BrokerEndpoint: NSObject, BrokerRequestChannel, @unchecked Sendable {
    static let maximumBytes = 262_144
    private let context: BrokerConnectionContext
    private let handler: BrokerRequestHandler?
    private let lock = NSLock()
    private var handshaken = false
    private var pending: Task<Void, Never>?

    init(context: BrokerConnectionContext, handler: BrokerRequestHandler?) {
        self.context = context
        self.handler = handler
    }

    func hello(_ nonce: String, reply: @escaping (String, Int) -> Void) {
        lock.lock()
        let admitted = context.isConnected && nonce.utf8.count == 36 && UUID(uuidString: nonce) != nil
        if admitted { handshaken = true }
        lock.unlock()
        reply(admitted ? nonce : "", admitted ? 1 : 0)
    }

    func request(_ data: Data, reply: @escaping @Sendable (Data?, String?) -> Void) {
        lock.lock()
        guard handshaken, context.isConnected, let handler else {
            lock.unlock(); reply(nil, "UNAUTHORIZED"); return
        }
        guard !data.isEmpty, data.count <= Self.maximumBytes, pending == nil else {
            lock.unlock(); reply(nil, "RESOURCE_LIMIT"); return
        }
        pending = Task { [self] in
            defer { finish() }
            guard !Task.isCancelled, context.isConnected else { reply(nil, "CANCELLED"); return }
            let result = await handler(context, data)
            guard !Task.isCancelled, context.isConnected else { reply(nil, "CANCELLED"); return }
            guard !result.isEmpty, result.count <= Self.maximumBytes else { reply(nil, "RESOURCE_LIMIT"); return }
            reply(result, nil)
        }
        lock.unlock()
    }

    private func finish() { lock.lock(); pending = nil; lock.unlock() }
    func cancel() {
        context.revoke()
        lock.lock(); let task = pending; lock.unlock()
        task?.cancel()
    }
}
