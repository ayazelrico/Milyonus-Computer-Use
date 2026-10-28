import Foundation
import Security
import ComputerUseIPC

private final class HandshakePeer: NSObject, NSXPCListenerDelegate, BrokerHandshake, @unchecked Sendable {
    let mode: String
    let identity: BrokerPeerIdentity
    private let lock = NSLock()
    private var connections: [NSXPCConnection] = []
    init(mode: String, identity: BrokerPeerIdentity) { self.mode = mode; self.identity = identity }
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection channel: NSXPCConnection) -> Bool {
        channel.setCodeSigningRequirement(identity.requirement)
        channel.exportedInterface = NSXPCInterface(with: BrokerHandshake.self)
        channel.exportedObject = self
        lock.lock(); connections.append(channel); lock.unlock()
        channel.resume()
        return true
    }
    func hello(_ nonce: String, reply: @escaping (String, Int) -> Void) {
        if mode == "silent" { return }
        reply(mode == "wrongNonce" ? "wrong" : nonce, mode == "wrongVersion" ? 2 : 1)
    }
    func shutdown() {
        lock.lock(); let existing = connections; connections.removeAll(); lock.unlock()
        existing.forEach { $0.invalidate() }
    }
}

@MainActor
final class BrokerConnectionTests: TestCase {
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
}
