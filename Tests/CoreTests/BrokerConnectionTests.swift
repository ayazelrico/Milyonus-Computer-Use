import Foundation
import Security
import ComputerUseIPC

private final class OwnedPeerGate: @unchecked Sendable {
    private let lock = NSLock()
    private var pid: Int32?
    private var invocations = 0
    init(_ pid: Int32?) { self.pid = pid }
    func currentPID() -> Int32? { lock.lock(); defer { lock.unlock() }; return pid }
    func replace(_ pid: Int32?) { lock.lock(); self.pid = pid; lock.unlock() }
    func invoked() { lock.lock(); invocations += 1; lock.unlock() }
    var count: Int { lock.lock(); defer { lock.unlock() }; return invocations }
}

private final class HandshakePeer: NSObject, NSXPCListenerDelegate, BrokerRequestChannel, @unchecked Sendable {
    let mode: String
    let identity: BrokerPeerIdentity
    private let lock = NSLock()
    private var connections: [NSXPCConnection] = []
    init(mode: String, identity: BrokerPeerIdentity) { self.mode = mode; self.identity = identity }
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection channel: NSXPCConnection) -> Bool {
        channel.setCodeSigningRequirement(identity.requirement)
        channel.exportedInterface = NSXPCInterface(with: BrokerRequestChannel.self)
        channel.exportedObject = self
        lock.lock(); connections.append(channel); lock.unlock()
        channel.resume()
        return true
    }
    func hello(_ nonce: String, reply: @escaping (String, Int) -> Void) {
        if mode == "silent" { return }
        reply(mode == "wrongNonce" ? "wrong" : nonce, mode == "wrongVersion" ? 2 : 1)
    }
    func control(_ data: Data, reply: @escaping @Sendable (Data?, String?) -> Void) { reply(data, nil) }
    func request(_ data: Data, reply: @escaping @Sendable (Data?, String?) -> Void) {
        if mode == "silentRequest" { return }
        reply(data, nil)
    }
    func shutdown() {
        lock.lock(); let existing = connections; connections.removeAll(); lock.unlock()
        existing.forEach { $0.invalidate() }
    }
}

@MainActor
final class BrokerConnectionTests: TestCase {
    func testOwnedWorkerProcessBindingAndRetirement() async throws {
        let pin = try identity(), pid = ProcessInfo.processInfo.processIdentifier
        for mode in ["matching", "wrong-client-pid", "wrong-server-pid", "retired"] {
            let gate = OwnedPeerGate(mode == "wrong-client-pid" ? Int32.max : pid)
            let listener = BrokerHandshakeListener(peer: pin, ownedProcessIdentifier: { gate.currentPID() },
                requestHandler: { _, data in gate.invoked(); return data })
            try listener.start()
            let connection = AuthenticatedBrokerConnection()
            defer { connection.close(); listener.close() }
            var authenticated = false
            do {
                try await connection.connect(endpoint: listener.endpoint, peer: pin,
                    expectedProcessIdentifier: mode == "wrong-server-pid" ? Int32.max : pid, timeoutSeconds: 1)
                authenticated = connection.isAuthenticated
                if mode == "wrong-client-pid" || mode == "wrong-server-pid" { fail("Wrong owned peer admitted") }
                if mode == "retired" {
                    gate.replace(nil)
                    do { _ = try await connection.request(Data("fixture-metadata".utf8), timeoutSeconds: 1); fail("Retired peer handled data") }
                    catch { expectEqual(error as? BrokerConnectionError, .requestFailed) }
                } else if mode == "matching" {
                    let received = try await connection.request(Data("fixture-metadata".utf8), timeoutSeconds: 1)
                    expectEqual(received, Data("fixture-metadata".utf8))
                }
            } catch { expectEqual(error as? BrokerConnectionError, .authenticationFailed) }
            expectEqual(authenticated, mode == "matching" || mode == "retired")
            expectEqual(gate.count, mode == "matching" ? 1 : 0)
        }
    }

    func testOwnedContextRevocationCannotRecoverWithSamePID() throws {
        let gate = OwnedPeerGate(42)
        let context = BrokerConnectionContext(isPeerLive: { gate.currentPID() == 42 })
        expectEqual(context.isConnected, true)
        gate.replace(nil)
        expectEqual(context.isConnected, false)
        gate.replace(42)
        expectEqual(context.isConnected, false)
        expectThrows(try BrokerHandshakeListener(serviceName: "invalid", peer: identity(),
            ownedProcessIdentifier: { 42 }))
    }

    private func identity() throws -> BrokerPeerIdentity {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { throw BrokerConnectionError.invalidIdentity }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else {
            throw BrokerConnectionError.invalidIdentity
        }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, [], &info) == errSecSuccess,
              let hash = (info as? [String: Any])?[kSecCodeInfoUnique as String] as? Data else {
            throw BrokerConnectionError.invalidIdentity
        }
        return try .developmentCDHash(hash.map { String(format: "%02x", $0) }.joined())
    }
    func testIdentityRejectsInjectedOrAmbiguousPolicy() throws {
        let identity = try BrokerPeerIdentity(teamID: "ABCDEFGHIJ", signingIdentifier: "com.milyonus.computeruse")
        expectFalse(identity.isDevelopmentPin)
        for team in ["", "abcdefghij", "ABC\" or true", "ABCDEFGHIJK"] {
            expectThrows(try BrokerPeerIdentity(teamID: team, signingIdentifier: "com.milyonus.computeruse"))
        }
        for identifier in ["", "com..test", "com.test\" or true", "com.test/*", "com.test\n", ".test"] {
            expectThrows(try BrokerPeerIdentity(teamID: "ABCDEFGHIJ", signingIdentifier: identifier))
        }
        expectThrows(try BrokerPeerIdentity.developmentCDHash(String(repeating: "g", count: 40)))
        expectThrows(try BrokerPeerIdentity.developmentCDHash(String(repeating: "a", count: 39)))
        expectEqual(try BrokerPeerIdentity.developmentCDHash(String(repeating: "a", count: 40)).isDevelopmentPin, true)
    }
    func testRealXPCHandshakeAndClose() async throws {
        let pin = try identity()
        let peer = HandshakePeer(mode: "echo", identity: pin)
        let listener = NSXPCListener.anonymous(); listener.delegate = peer; listener.resume()
        defer { peer.shutdown(); listener.invalidate() }
        let channel = AuthenticatedBrokerConnection()
        try await channel.connect(endpoint: listener.endpoint, peer: pin)
        expectEqual(channel.isAuthenticated, true)
        do { try await channel.connect(endpoint: listener.endpoint, peer: pin); fail("Duplicate connection accepted") }
        catch { expectEqual(error as? BrokerConnectionError, .alreadyConnected) }
        channel.close()
        expectFalse(channel.isAuthenticated)
        try await channel.connect(endpoint: listener.endpoint, peer: pin)
        expectEqual(channel.isAuthenticated, true)
        channel.close()
    }
    func testInvalidReplySignatureAndTimeoutFailClosed() async throws {
        let pin = try identity()
        for mode in ["wrongNonce", "wrongVersion", "silent", "wrongSignature"] {
            let peer = HandshakePeer(mode: mode, identity: pin)
            let listener = NSXPCListener.anonymous(); listener.delegate = peer; listener.resume()
            let channel = AuthenticatedBrokerConnection()
            let expected: BrokerConnectionError = mode == "silent" ? .timeout : (mode == "wrongSignature" ? .authenticationFailed : .protocolMismatch)
            do {
                try await channel.connect(endpoint: listener.endpoint,
                    peer: mode == "wrongSignature" ? .developmentCDHash(String(repeating: "0", count: 40)) : pin,
                    timeoutSeconds: 1)
                fail("Invalid peer accepted: \(mode)")
            } catch { expectEqual(error as? BrokerConnectionError, expected) }
            expectFalse(channel.isAuthenticated)
            channel.close(); peer.shutdown(); listener.invalidate()
        }
    }
    func testCancellationDoesNotAuthenticate() async throws {
        let pin = try identity()
        let peer = HandshakePeer(mode: "silent", identity: pin)
        let listener = NSXPCListener.anonymous(); listener.delegate = peer; listener.resume()
        defer { peer.shutdown(); listener.invalidate() }
        let channel = AuthenticatedBrokerConnection()
        let task = Task { try await channel.connect(endpoint: listener.endpoint, peer: pin) }
        try await Task.sleep(for: .milliseconds(30))
        task.cancel()
        do { try await task.value; fail("Cancelled handshake accepted") }
        catch { expectEqual(error as? BrokerConnectionError, .cancelled) }
        expectFalse(channel.isAuthenticated)
        channel.close()
    }
    func testBoundedRequestRoundTripAndTimeout() async throws {
        let pin = try identity()
        for mode in ["echo", "silentRequest"] {
            let peer = HandshakePeer(mode: mode, identity: pin)
            let listener = NSXPCListener.anonymous(); listener.delegate = peer; listener.resume()
            let channel = AuthenticatedBrokerConnection()
            defer { channel.close(); peer.shutdown(); listener.invalidate() }
            do { _ = try await channel.request(Data("test".utf8)); fail("Unauthenticated request accepted") }
            catch { expectEqual(error as? BrokerConnectionError, .unauthorized) }
            try await channel.connect(endpoint: listener.endpoint, peer: pin)
            do { _ = try await channel.request(Data(repeating: 0, count: 262_145)); fail("Oversized request accepted") }
            catch { expectEqual(error as? BrokerConnectionError, .resourceLimit) }
            expectEqual(channel.isAuthenticated, true)
            if mode == "echo" {
                let payload = Data("bounded".utf8)
                let received = try await channel.request(payload)
                expectEqual(received, payload)
            } else {
                do { _ = try await channel.request(Data("test".utf8), timeoutSeconds: 1); fail("Silent request accepted") }
                catch { expectEqual(error as? BrokerConnectionError, .timeout) }
                expectFalse(channel.isAuthenticated)
            }
        }
    }

    func testControlRemainsAvailableWhileRequestIsPending() async throws {
        let pin = try identity()
        let peer = HandshakePeer(mode: "silentRequest", identity: pin)
        let listener = NSXPCListener.anonymous(); listener.delegate = peer; listener.resume()
        let channel = AuthenticatedBrokerConnection()
        defer { channel.close(); peer.shutdown(); listener.invalidate() }
        try await channel.connect(endpoint: listener.endpoint, peer: pin)
        let request = Task { try await channel.request(Data("held".utf8)) }
        try await Task.sleep(for: .milliseconds(30))
        do { _ = try await channel.request(Data("second".utf8)); fail("Second request admitted") }
        catch { expectEqual(error as? BrokerConnectionError, .resourceLimit) }
        do { _ = try await channel.control(Data(repeating: 0, count: 4097)); fail("Oversized control admitted") }
        catch { expectEqual(error as? BrokerConnectionError, .resourceLimit) }
        let heartbeat = try await channel.control(Data("heartbeat".utf8))
        expectEqual(heartbeat, Data("heartbeat".utf8))
        expectEqual(channel.isAuthenticated, true)
        request.cancel()
        do { _ = try await request.value; fail("Cancelled request completed") }
        catch { expectEqual(error as? BrokerConnectionError, .cancelled) }
        expectFalse(channel.isAuthenticated)
    }

}
