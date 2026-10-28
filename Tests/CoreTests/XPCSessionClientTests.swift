import Foundation
import Security
import ComputerUseIPC
import ComputerUseClient
import ComputerUseContracts

private final class TypedSessionPeer: NSObject, NSXPCListenerDelegate, BrokerRequestChannel, @unchecked Sendable {
    let mode: String
    let identity: BrokerPeerIdentity
    private let lock = NSLock()
    private var channels: [NSXPCConnection] = []
    private var heartbeatCalls = 0
    func heartbeatCount() -> Int { lock.lock(); defer { lock.unlock() }; return heartbeatCalls }
    init(mode: String, identity: BrokerPeerIdentity) { self.mode = mode; self.identity = identity }
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.setCodeSigningRequirement(identity.requirement)
        connection.exportedInterface = NSXPCInterface(with: BrokerRequestChannel.self)
        connection.exportedObject = self
        lock.lock(); channels.append(connection); lock.unlock()
        connection.resume(); return true
    }
    func hello(_ nonce: String, reply: @escaping (String, Int) -> Void) { reply(nonce, 1) }
    func request(_ data: Data, reply: @escaping @Sendable (Data?, String?) -> Void) { respond(data, reply: reply) }
    func control(_ data: Data, reply: @escaping @Sendable (Data?, String?) -> Void) { respond(data, reply: reply) }
    private func respond(_ data: Data, reply: @escaping @Sendable (Data?, String?) -> Void) {
        let name = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["name"] as? String
        if mode == "duplicate" {
            reply(Data("{\"error\":\"UNAUTHORIZED\",\"error\":\"CANCELLED\"}".utf8), nil); return
        }
        if mode == "domain" { reply(Data("{\"error\":\"LEASE_BUSY\"}".utf8), nil); return }
        if name == "session_heartbeat" { lock.lock(); heartbeatCalls += 1; lock.unlock() }
        let state = name == "session_cancel" ? "cancelled" : (mode == "heartbeat" && name != "session_open" ? "ready" : "awaitingApproval")
        let id = mode == "wrongID" && name == "session_status" ? "other-session" : "fixture-session"
        let session = Session(id: id, bundleId: HarnessProtocol.fixtureBundleID,
            generation: 1, state: state == "cancelled" ? .cancelled : (state == "ready" ? .ready : .awaitingApproval),
            expiresAt: Date().addingTimeInterval(300))
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let encoded = try! encoder.encode(session)
        let object = try! JSONSerialization.jsonObject(with: encoded)
        reply(try! JSONSerialization.data(withJSONObject: ["result": object]), nil)
    }
    func close() { lock.lock(); let existing = channels; channels.removeAll(); lock.unlock(); existing.forEach { $0.invalidate() } }
}

@MainActor final class XPCSessionClientTests: TestCase {
    private func identity() throws -> BrokerPeerIdentity {
        var code: SecCode?, staticCode: SecStaticCode?, info: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, [], &info) == errSecSuccess,
              let hash = (info as? [String: Any])?[kSecCodeInfoUnique as String] as? Data else { throw BrokerConnectionError.invalidIdentity }
        return try BrokerPeerIdentity.developmentCDHash(hash.map { String(format: "%02x", $0) }.joined())
    }
    func testTypedIdentityMismatchAndDuplicateEnvelopeCloseTransport() async throws {
        let pin = try identity()
        for mode in ["wrongID", "duplicate", "domain", "valid"] {
            let peer = TypedSessionPeer(mode: mode, identity: pin)
            let listener = NSXPCListener.anonymous(); listener.delegate = peer; listener.resume()
            let channel = AuthenticatedBrokerConnection()
            try await channel.connect(endpoint: listener.endpoint, peer: pin)
            let client = XPCSessionClient(connectedChannel: channel, peer: pin)
            if mode == "wrongID" {
                let session = try await client.openFixtureSession()
                expectEqual(session.state, .awaitingApproval)
                do { _ = try await client.status(); fail("Mismatched session accepted") }
                catch { expectEqual(error as? HarnessError, .protocolMismatch) }
                expectFalse(channel.isAuthenticated)
            } else if mode == "duplicate" {
                do { _ = try await client.openFixtureSession(); fail("Duplicate envelope accepted") }
                catch { expectEqual(error as? HarnessError, .protocolMismatch) }
                expectFalse(channel.isAuthenticated)
            } else if mode == "domain" {
                do { _ = try await client.openFixtureSession(); fail("Domain refusal lost") }
                catch { expectEqual(error as? HarnessError, .leaseBusy) }
                expectEqual(channel.isAuthenticated, true)
            } else {
                let session = try await client.openFixtureSession()
                let status = try await client.status()
                expectEqual(status?.id, session.id)
                try await client.cancel(sessionID: session.id)
                do { _ = try await client.status(); fail("Cancelled ownership retained") }
                catch { expectEqual(error as? HarnessError, .unauthorized) }
            }
            await client.shutdown(); peer.close(); listener.invalidate()
        }
    }
    func testAutomaticHeartbeatUsesControlAndStopsAfterShutdown() async throws {
        let pin = try identity()
        let peer = TypedSessionPeer(mode: "heartbeat", identity: pin)
        let listener = NSXPCListener.anonymous(); listener.delegate = peer; listener.resume()
        let channel = AuthenticatedBrokerConnection()
        try await channel.connect(endpoint: listener.endpoint, peer: pin)
        let client = XPCSessionClient(connectedChannel: channel, peer: pin)
        defer { channel.close(); peer.close(); listener.invalidate() }
        _ = try await client.openFixtureSession()
        let status = try await client.status()
        expectEqual(status?.state, .ready)
        let deadline = ContinuousClock.now.advanced(by: .seconds(7))
        while peer.heartbeatCount() == 0 && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        expectEqual(peer.heartbeatCount() > 0, true)
        await client.shutdown()
        let count = peer.heartbeatCount()
        try await Task.sleep(for: .milliseconds(5200))
        expectEqual(peer.heartbeatCount(), count)
        expectFalse(channel.isAuthenticated)
    }

}
