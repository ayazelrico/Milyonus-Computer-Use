import Foundation

@objc(MilyonusBrokerRequestChannel)
public protocol BrokerRequestChannel: BrokerHandshake {
    func control(_ data: Data, reply: @escaping @Sendable (Data?, String?) -> Void)
    func request(_ data: Data, reply: @escaping @Sendable (Data?, String?) -> Void)
}

public typealias BrokerRequestHandler = @Sendable (BrokerConnectionContext, Data) async -> Data

/// One bounded request and one independent control request per connection. This transport endpoint cannot approve native sessions.
final class BrokerEndpoint: NSObject, BrokerRequestChannel, @unchecked Sendable {
    static let maximumBytes = 262_144
    private let context: BrokerConnectionContext
    private let handler: BrokerRequestHandler?
    private let controlHandler: BrokerRequestHandler?
    private let lock = NSLock()
    private var handshaken = false
    private var pending: [Bool: Task<Void, Never>] = [:]

    init(context: BrokerConnectionContext, handler: BrokerRequestHandler?, controlHandler: BrokerRequestHandler?) {
        self.context = context
        self.handler = handler
        self.controlHandler = controlHandler
    }

    func hello(_ nonce: String, reply: @escaping (String, Int) -> Void) {
        lock.lock()
        let admitted = context.isConnected && nonce.utf8.count == 36 && UUID(uuidString: nonce) != nil
        if admitted { handshaken = true }
        lock.unlock()
        reply(admitted ? nonce : "", admitted ? 1 : 0)
    }

    func request(_ data: Data, reply: @escaping @Sendable (Data?, String?) -> Void) {
        receive(data, control: false, reply: reply)
    }
    func control(_ data: Data, reply: @escaping @Sendable (Data?, String?) -> Void) {
        receive(data, control: true, reply: reply)
    }
    private func receive(_ data: Data, control: Bool, reply: @escaping @Sendable (Data?, String?) -> Void) {
        lock.lock()
        let selectedHandler = control ? controlHandler : handler
        guard handshaken, context.isConnected, let handler = selectedHandler else {
            lock.unlock(); reply(nil, "UNAUTHORIZED"); return
        }
        guard !data.isEmpty, data.count <= (control ? 4096 : Self.maximumBytes), pending[control] == nil else {
            lock.unlock(); reply(nil, "RESOURCE_LIMIT"); return
        }
        pending[control] = Task { [self] in
            defer { finish(control) }
            guard !Task.isCancelled, context.isConnected else { reply(nil, "CANCELLED"); return }
            let result = await handler(context, data)
            guard !Task.isCancelled, context.isConnected else { reply(nil, "CANCELLED"); return }
            guard !result.isEmpty, result.count <= Self.maximumBytes else { reply(nil, "RESOURCE_LIMIT"); return }
            reply(result, nil)
        }
        lock.unlock()
    }

    private func finish(_ control: Bool) { lock.lock(); pending.removeValue(forKey: control); lock.unlock() }
    func cancel() {
        context.revoke()
        lock.lock(); let tasks = Array(pending.values); lock.unlock()
        tasks.forEach { $0.cancel() }
    }
}
