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
        let state = name == "session_cancel" ? "cancelled" : "awaitingApproval"
        let id = mode == "wrongID" && name == "session_status" ? "other-session" : "fixture-session"
        let session = Session(id: id, bundleId: HarnessProtocol.fixtureBundleID,
            generation: 1, state: state == "cancelled" ? .cancelled : .awaitingApproval,
            expiresAt: Date().addingTimeInterval(300))
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let encoded = try! encoder.encode(session)
        let object = try! JSONSerialization.jsonObject(with: encoded)
        reply(try! JSONSerialization.data(withJSONObject: ["result": object]), nil)
    }
    func close() { lock.lock(); let existing = channels; channels.removeAll(); lock.unlock(); existing.forEach { $0.invalidate() } }
}

@MainActor final class XPCSessionClientTests: TestCase {
    func testTypedIdentityMismatchAndDuplicateEnvelopeCloseTransport() async throws {
        var code: SecCode?, staticCode: SecStaticCode?, info: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, [], &info) == errSecSuccess,
              let hash = (info as? [String: Any])?[kSecCodeInfoUnique as String] as? Data else { throw BrokerConnectionError.invalidIdentity }
        let pin = try BrokerPeerIdentity.developmentCDHash(hash.map { String(format: "%02x", $0) }.joined())
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
}
