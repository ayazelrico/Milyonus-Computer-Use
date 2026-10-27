import Foundation
import Security

// Read-only feasibility probe. No desktop APIs, sessions or native approvals.
@objc protocol ProbeProtocol {
    func ping(reply: @escaping (String) -> Void)
    func afterHandshake(reply: @escaping (String) -> Void)
}
final class Service: NSObject, ProbeProtocol {
    private let lock = NSLock()
    private var count = 0
    private var handshakeComplete = false
    private let tracker: Service?
    var logInvocations = false
    init(tracker: Service? = nil) { self.tracker = tracker }
    private func record(_ event: String) {
        if let tracker { tracker.record(event); return }
        lock.lock(); count += 1; lock.unlock()
        if logInvocations { try? FileHandle.standardOutput.write(contentsOf: Data((event + "\n").utf8)) }
    }
    func ping(reply: @escaping (String) -> Void) {
        lock.lock(); handshakeComplete = true; lock.unlock()
        record("invoked")
        reply("pong")
    }
    func afterHandshake(reply: @escaping (String) -> Void) {
        lock.lock(); let admitted = handshakeComplete; lock.unlock()
        guard admitted else { reply("handshakeRequired"); return }
        record("afterHandshake")
        reply("ack")
    }
    func invocationCount() -> Int { lock.lock(); defer { lock.unlock() }; return count }
}
final class Delegate: NSObject, NSXPCListenerDelegate {
    let requirement: String
    let service = Service()
    var connections: [NSXPCConnection] = []
    init(requirement: String) { self.requirement = requirement }
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.setCodeSigningRequirement(requirement)
        connection.exportedInterface = NSXPCInterface(with: ProbeProtocol.self)
        connection.exportedObject = Service(tracker: service)
        connections.append(connection)
        connection.resume()
        return true
    }
}
final class ResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: [String: Any]?
    func finish(_ result: [String: Any]) { lock.lock(); defer { lock.unlock() }; if value == nil { value = result } }
    func read() -> [String: Any]? { lock.lock(); defer { lock.unlock() }; return value }
}
let args = Array(CommandLine.arguments.dropFirst())
let namedServer = args.first == "--server"
let unprimed = args.first == "--client-unprimed"
let namedClient = args.first == "--client" || unprimed
guard (args.count == 2 && !namedServer && !namedClient) || (args.count == 3 && (namedServer || namedClient)) else { exit(64) }
let requirements = (namedServer || namedClient) ? [args[2]] : args
// Foundation raises an exception for malformed requirements. Validate first.
for requirement in requirements {
    var parsed: SecRequirement?
    guard SecRequirementCreateWithString(requirement as CFString, [], &parsed) == errSecSuccess,
          parsed != nil else { fputs("Invalid signing requirement\n", stderr); exit(64) }
}
if namedServer {
    let listener = NSXPCListener(machServiceName: args[1])
    let delegate = Delegate(requirement: args[2])
    delegate.service.logInvocations = true
    listener.delegate = delegate
    listener.resume()
    // Bound prototype lifetime even if the harness fails to unload its job.
    let deadline = ContinuousClock.now.advanced(by: .seconds(30))
    withExtendedLifetime(delegate) {
        while ContinuousClock.now < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
    }
    listener.invalidate()
    exit(0)
}
let listener = namedClient ? nil : NSXPCListener.anonymous()
let delegate = Delegate(requirement: args[0])
if let listener { listener.delegate = delegate; listener.resume() }
let connection: NSXPCConnection
if namedClient { connection = NSXPCConnection(machServiceName: args[1]) }
else { connection = NSXPCConnection(listenerEndpoint: listener!.endpoint) }
connection.remoteObjectInterface = NSXPCInterface(with: ProbeProtocol.self)
connection.setCodeSigningRequirement(namedClient ? args[2] : args[1])
let result = ResultBox()
connection.resume()
let proxy = connection.remoteObjectProxyWithErrorHandler { error in
    let error = error as NSError
    result.finish(["outcome": "rejected", "domain": error.domain, "code": error.code])
} as! ProbeProtocol
if unprimed {
    proxy.afterHandshake { value in
        result.finish(["outcome": value == "handshakeRequired" ? "handshakeRequired" : "unexpectedAdmission"])
    }
} else {
proxy.ping { value in
    guard value == "pong" else { result.finish(["outcome": "invalidReply"]); return }
    // Only an authenticated reply on this exact connection permits the next message.
    proxy.afterHandshake { acknowledgement in
        result.finish(["outcome": acknowledgement == "ack" ? "replied" : "invalidReply"])
    }
}
}
let deadline = ContinuousClock.now.advanced(by: .seconds(10))
while result.read() == nil, ContinuousClock.now < deadline {
    RunLoop.current.run(until: Date().addingTimeInterval(0.01))
}
var report = result.read() ?? ["outcome": "timeout"]
if !namedClient { report["serverInvocations"] = delegate.service.invocationCount() }
connection.invalidate()
listener?.invalidate()
for accepted in delegate.connections { accepted.invalidate() }
let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
print(String(decoding: data, as: UTF8.self))
exit(report["outcome"] as? String == "timeout" ? 1 : 0)
