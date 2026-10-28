import Foundation
import ComputerUseContracts
import ComputerUseIPC

/// Opt-in lifecycle adapter for an independently registered companion.
/// Fixture AX actions require an explicit trusted host opt-in; native input routes are unavailable.
@MainActor
public final class XPCSessionClient: ManagedHarnessClient, CapabilityHarnessClient, HeartbeatHarnessClient {
    private let channel: AuthenticatedBrokerConnection
    private let serviceName: String
    private let peer: BrokerPeerIdentity
    private let allowFixtureActions: Bool
    private var lifecycle = UUID()
    private var ownedSessionID: String?
    private var opening = false

    public init(serviceName: String, peer: BrokerPeerIdentity, allowFixtureActions: Bool = false) {
        self.serviceName = serviceName
        self.peer = peer
        self.channel = AuthenticatedBrokerConnection()
        self.allowFixtureActions = allowFixtureActions
    }
    package init(connectedChannel: AuthenticatedBrokerConnection, peer: BrokerPeerIdentity) {
        self.channel = connectedChannel
        self.serviceName = "com.milyonus.test"
        self.allowFixtureActions = false
        self.peer = peer
    }
    public func connect() async throws { try await channel.connect(serviceName: serviceName, peer: peer) }
    public func shutdown() async {
        lifecycle = UUID()
        ownedSessionID = nil
        channel.close()
    }

    private func reject() throws -> Never {
        lifecycle = UUID(); ownedSessionID = nil; channel.close()
        throw HarnessError.protocolMismatch
    }

    private func call<T: Decodable>(_ name: String, arguments: Data = Data("{}".utf8), control: Bool = false) async throws -> T {
        let epoch = lifecycle
        let argumentObject = try JSONSerialization.jsonObject(with: arguments)
        let request = try JSONSerialization.data(withJSONObject: ["name": name, "arguments": argumentObject])
        let response = try await (control ? channel.control(request) : channel.request(request))
        guard epoch == lifecycle, !Task.isCancelled else { throw HarnessError.cancelled }
        let object: [String: Any]
        do {
            guard let decoded = try StrictJSON.object(response) as? [String: Any] else { try reject() }
            object = decoded
        } catch { try reject() }
        if Set(object.keys) == ["error"], let value = object["error"] as? String,
           let error = HarnessError(rawValue: value) { throw error }
        guard Set(object.keys) == ["result"], let result = object["result"] else { try reject() }
        do {
            let data = try JSONSerialization.data(withJSONObject: result, options: [.fragmentsAllowed])
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch { try reject() }
    }

    private func validate(_ session: Session, expectedID: String? = nil) throws {
        guard (try? session.validate()) != nil, session.bundleId == HarnessProtocol.fixtureBundleID,
              expectedID == nil || session.id == expectedID else { try reject() }
    }

    public func openFixtureSession() async throws -> Session {
        guard !opening, ownedSessionID == nil else { throw HarnessError.leaseBusy }
        opening = true
        defer { opening = false }
        let epoch = lifecycle
        let session: Session = try await call("session_open")
        guard epoch == lifecycle, !Task.isCancelled else { throw HarnessError.cancelled }
        try validate(session)
        guard session.state == .awaitingApproval, session.generation == 1 else { try reject() }
        ownedSessionID = session.id
        return session
    }

    public func status() async throws -> Session? {
        guard let id = ownedSessionID else { throw HarnessError.unauthorized }
        let session: Session? = try await call("session_status")
        guard let session else { try reject() }
        try validate(session, expectedID: id)
        return session
    }

    public func capabilities() async throws -> HarnessCapabilities {
        let result: HarnessCapabilities = try await call("system_capabilities")
        guard (try? result.validate()) != nil, Set(result.supportedActions) == (allowFixtureActions ? [.press, .setValue] : []),
              !result.nativeTextInput, !result.nativeElementClick,
              !result.experimentalNativeFixtureScroll, !result.experimentalNativeFixtureDrag else { try reject() }
        return result
    }

    public func heartbeat(sessionID: String, generation: Int) async throws -> Session {
        guard ownedSessionID == sessionID, generation > 0 else { throw HarnessError.unauthorized }
        struct Arguments: Encodable { let sessionId: String; let generation: Int }
        let result: Session = try await call("session_heartbeat",
            arguments: JSONEncoder().encode(Arguments(sessionId: sessionID, generation: generation)), control: true)
        try validate(result, expectedID: sessionID)
        guard result.state == .ready, result.generation == generation else { try reject() }
        return result
    }

    public func cancel(sessionID: String) async throws {
        guard ownedSessionID == sessionID else { throw HarnessError.unauthorized }
        // Fence any old status/heartbeat response before dispatching cancellation.
        lifecycle = UUID()
        let result: Session
        do {
            result = try await call("session_cancel",
                arguments: JSONEncoder().encode(["sessionId": sessionID]), control: true)
        } catch {
            // A heartbeat may already occupy the control slot. Closing revokes ownership
            // even when a cancel acknowledgement cannot be obtained. Never claim an ack.
            await shutdown()
            throw error
        }
        try validate(result, expectedID: sessionID)
        guard [.cancelled, .expired].contains(result.state) else { try reject() }
        ownedSessionID = nil
    }

    public func observe(sessionID: String) async throws -> Observation {
        guard allowFixtureActions else { throw HarnessError.unsupportedCapability }
        guard ownedSessionID == sessionID else { throw HarnessError.unauthorized }
        let observation: Observation = try await call("desktop_observe", arguments: JSONEncoder().encode(["sessionId": sessionID]))
        guard (try? observation.validate()) != nil, observation.sessionId == sessionID,
              observation.bundleId == HarnessProtocol.fixtureBundleID else { try reject() }
        return observation
    }
    public func act(_ request: ActionRequest) async throws -> ActionResult {
        guard allowFixtureActions else { throw HarnessError.unsupportedCapability }
        guard ownedSessionID == request.sessionId else { throw HarnessError.unauthorized }
        try request.validate()
        guard request.kind == .press || request.kind == .setValue else { throw HarnessError.unsupportedCapability }
        let result: ActionResult = try await call("desktop_action", arguments: JSONEncoder().encode(request))
        guard (try? result.validate()) != nil, result.requestId == request.requestId else { try reject() }
        return result
    }
}
