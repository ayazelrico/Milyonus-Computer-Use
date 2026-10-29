import Foundation
import ComputerUseContracts
import ComputerUseIPC

/// Opt-in lifecycle adapter for an independently registered companion.
/// Fixture AX actions and native input each require explicit trusted host opt-ins.
@MainActor
public final class XPCSessionClient: ManagedHarnessClient, CapabilityHarnessClient, HeartbeatHarnessClient, NativeTextHarnessClient, NativePointerHarnessClient, NativeScrollHarnessClient, NativeDragHarnessClient {
    private let channel: AuthenticatedBrokerConnection
    private let serviceName: String
    private let peer: BrokerPeerIdentity
    private let allowFixtureActions: Bool
    private let allowFixtureObservation: Bool
    private let allowNativeFixtureInput: Bool
    private var lifecycle = UUID()
    private var ownedSessionID: String?
    private var opening = false
    private var latestSession: Session?
    private var heartbeatTask: Task<Void, Never>?

    public init(serviceName: String, peer: BrokerPeerIdentity, allowFixtureActions: Bool = false, allowNativeFixtureInput: Bool = false,
                allowFixtureObservation: Bool = false) {
        self.serviceName = serviceName
        self.peer = peer
        self.channel = AuthenticatedBrokerConnection()
        self.allowFixtureActions = allowFixtureActions
        self.allowFixtureObservation = allowFixtureObservation || allowFixtureActions
        self.allowNativeFixtureInput = allowFixtureActions && allowNativeFixtureInput
    }
    package init(connectedChannel: AuthenticatedBrokerConnection, peer: BrokerPeerIdentity, allowNativeFixtureInput: Bool = false,
                 allowFixtureObservation: Bool = false) {
        self.channel = connectedChannel
        self.serviceName = "com.milyonus.test"
        self.allowFixtureActions = allowNativeFixtureInput
        self.allowFixtureObservation = allowFixtureObservation || allowNativeFixtureInput
        self.allowNativeFixtureInput = allowNativeFixtureInput
        self.peer = peer
    }
    public func connect() async throws { try await channel.connect(serviceName: serviceName, peer: peer) }
    public func shutdown() async {
        lifecycle = UUID()
        ownedSessionID = nil
        latestSession = nil
        heartbeatTask?.cancel(); heartbeatTask = nil
        channel.close()
    }

    private func reject() throws -> Never {
        lifecycle = UUID(); ownedSessionID = nil; latestSession = nil
        heartbeatTask?.cancel(); heartbeatTask = nil; channel.close()
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
        latestSession = session
        startHeartbeat(sessionID: session.id, epoch: lifecycle)
        return session
    }

    public func status() async throws -> Session? {
        guard let id = ownedSessionID else { throw HarnessError.unauthorized }
        let session: Session? = try await call("session_status")
        guard let session else { try reject() }
        try validate(session, expectedID: id)
        latestSession = session
        return session
    }

    public func capabilities() async throws -> HarnessCapabilities {
        let result: HarnessCapabilities = try await call("system_capabilities")
        guard (try? result.validate()) != nil, Set(result.supportedActions) == (allowFixtureActions ? [.press, .setValue] : []),
              result.nativeTextInput == allowNativeFixtureInput, result.nativeElementClick == allowNativeFixtureInput,
              result.experimentalNativeFixtureScroll == allowNativeFixtureInput,
              result.experimentalNativeFixtureDrag == allowNativeFixtureInput else { try reject() }
        return result
    }

    public func heartbeat(sessionID: String, generation: Int) async throws -> Session {
        guard ownedSessionID == sessionID, generation > 0 else { throw HarnessError.unauthorized }
        struct Arguments: Encodable { let sessionId: String; let generation: Int }
        let result: Session = try await call("session_heartbeat",
            arguments: JSONEncoder().encode(Arguments(sessionId: sessionID, generation: generation)), control: true)
        try validate(result, expectedID: sessionID)
        guard result.state == .ready, result.generation == generation else { try reject() }
        latestSession = result
        return result
    }

    public func cancel(sessionID: String) async throws {
        guard ownedSessionID == sessionID else { throw HarnessError.unauthorized }
        // Fence any old status/heartbeat response before dispatching cancellation.
        lifecycle = UUID()
        heartbeatTask?.cancel(); heartbeatTask = nil
        latestSession = nil
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

    private func startHeartbeat(sessionID: String, epoch: UUID) {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                guard let self, self.lifecycle == epoch, self.ownedSessionID == sessionID else { return }
                // Status polling belongs to the caller. The timer never competes for the action lane.
                guard let session = self.latestSession, session.state == .ready else { continue }
                do { _ = try await self.heartbeat(sessionID: sessionID, generation: session.generation) }
                catch {
                    guard self.lifecycle == epoch, self.ownedSessionID == sessionID else { return }
                    if let error = error as? HarnessError, [.unauthorized, .staleObservation].contains(error) {
                        self.latestSession = nil // A fresh caller status must observe a renewed native grant.
                    } else if error as? BrokerConnectionError != .resourceLimit {
                        await self.shutdown()
                        return
                    }
                }
            }
        }
    }

    isolated deinit { heartbeatTask?.cancel() }

    public func observe(sessionID: String) async throws -> Observation {
        guard allowFixtureObservation else { throw HarnessError.unsupportedCapability }
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
        return try await actionCall("desktop_action", request: request)
    }
    private func actionCall(_ name: String, request: ActionRequest) async throws -> ActionResult {
        guard ownedSessionID == request.sessionId else { throw HarnessError.unauthorized }
        let result: ActionResult = try await call(name, arguments: JSONEncoder().encode(request))
        guard (try? result.validate()) != nil, result.requestId == request.requestId else { try reject() }
        return result
    }
    public func typeText(_ request: ActionRequest) async throws -> ActionResult {
        guard allowNativeFixtureInput else { throw HarnessError.unsupportedCapability }
        try request.validate()
        guard request.kind == .setValue, let text = request.text, text.utf16.count <= 1024 else { throw HarnessError.invalidRequest }
        return try await actionCall("desktop_type_text", request: request)
    }
    public func click(_ request: ActionRequest) async throws -> ActionResult {
        guard allowNativeFixtureInput else { throw HarnessError.unsupportedCapability }
        try request.validate()
        guard request.kind == .press, request.text == nil else { throw HarnessError.invalidRequest }
        return try await actionCall("desktop_click", request: request)
    }
    public func scroll(_ request: ActionRequest) async throws -> ActionResult {
        guard allowNativeFixtureInput else { throw HarnessError.unsupportedCapability }
        try request.validate()
        guard request.kind == .scroll else { throw HarnessError.invalidRequest }
        return try await actionCall("desktop_scroll", request: request)
    }
    public func drag(_ request: ActionRequest) async throws -> ActionResult {
        guard allowNativeFixtureInput else { throw HarnessError.unsupportedCapability }
        try request.validate()
        guard request.kind == .drag else { throw HarnessError.invalidRequest }
        return try await actionCall("desktop_drag", request: request)
    }

}
