import Foundation
import Darwin
import ComputerUseContracts

/// Package-only counters for synthetic timeout diagnosis; no protocol payloads.
package struct StdioTimeoutSnapshot: Sendable {
    package let requestID: Int
    package let queued: Int
    package let writtenBytes: Int
    package let receivedFrames: Int
    package let readerFinished: Bool
    package let childRunning: Bool
}

/// Launches a dedicated visible companion over inherited pipes. It does not connect to
/// an arbitrary localhost endpoint and cannot approve its own sessions.
public actor StdioHarnessClient: CapabilityHarnessClient, NativeTextHarnessClient, NativePointerHarnessClient, NativeScrollHarnessClient, NativeDragHarnessClient, HeartbeatHarnessClient {
    private let process: Process
    private let input: FileHandle
    private let output: FileHandle
    private var nextID = 0
    private var pending: [Int: CheckedContinuation<Data, Error>] = [:]
    private var timeoutTasks: [Int: Task<Void, Never>] = [:]
    private var closed = false
    private var heartbeatTask: Task<Void, Never>?
    private var ownedSessionID: String?
    private var openingSession = false
    private var sessionLifecycle = UUID()
    private var reader: Task<Void, Never>?
    private struct OutboundFrame {
        let data: Data
        var offset = 0
        let deadline = ContinuousClock.now.advanced(by: .seconds(10))
    }
    private var outbound: [OutboundFrame] = []
    private var writer: Task<Void, Never>?
    private var backpressureCount = 0
    private var writtenBytes = 0
    private var readerFinished = true
    private var receivedFrames = 0
    private var timeoutDiagnosed = false
    private let timeoutDiagnostic: (@Sendable (StdioTimeoutSnapshot) -> Void)?

    public init(companionExecutable: URL, diagnostics: Bool = false) throws {
        try self.init(companionExecutable: companionExecutable, diagnostics: diagnostics, timeoutDiagnostic: nil)
    }
    package init(companionExecutable: URL, diagnostics: Bool = false,
                 timeoutDiagnostic: (@Sendable (StdioTimeoutSnapshot) -> Void)?) throws {
        self.timeoutDiagnostic = timeoutDiagnostic
        guard companionExecutable.isFileURL, companionExecutable.path.hasPrefix("/"),
              FileManager.default.isExecutableFile(atPath: companionExecutable.path) else { throw HarnessError.invalidRequest }
        let child = Process(), stdin = Pipe(), stdout = Pipe()
        child.executableURL = companionExecutable; child.arguments = diagnostics ? ["--mcp", "--diagnostics"] : ["--mcp"]
        child.standardInput = stdin; child.standardOutput = stdout
        child.standardError = diagnostics ? FileHandle.standardError : FileHandle.nullDevice
        // Do not pass provider API tokens or agent configuration through the environment.
        child.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HOME": NSHomeDirectory(), "LANG": "en_US.UTF-8"]
        process = child; input = stdin.fileHandleForWriting; output = stdout.fileHandleForReading
        for descriptor in [input.fileDescriptor, output.fileDescriptor] {
            let flags = fcntl(descriptor, F_GETFL)
            guard flags >= 0, fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) == 0 else {
                throw HarnessError.protocolMismatch
            }
        }
        guard fcntl(input.fileDescriptor, F_SETNOSIGPIPE, 1) == 0 else { throw HarnessError.protocolMismatch }
        try child.run()
    }
    deinit {
        try? input.close()
        if !closed { Self.terminateOwnedChild(process) }
        reader?.cancel()
        writer?.cancel()
        for task in timeoutTasks.values { task.cancel() }
        heartbeatTask?.cancel()
    }
    public func connect() async throws {
        guard reader == nil, !closed else { throw HarnessError.protocolMismatch }
        let handle = output
        readerFinished = false
        reader = Task.detached { [weak self] in
            defer {
                try? handle.close()
                let client = self
                Task { await client?.readerDidFinish() }
            }
            var buffer = Data()
            do {
                while !Task.isCancelled {
                    var bytes = [UInt8](repeating: 0, count: 4096)
                    let count = Darwin.read(handle.fileDescriptor, &bytes, bytes.count)
                    if count < 0 && errno == EINTR { continue }
                    if count < 0 && (errno == EAGAIN || errno == EWOULDBLOCK) {
                        try await Task.sleep(for: .milliseconds(10))
                        continue
                    }
                    if count < 0 { throw HarnessError.protocolMismatch }
                    if count == 0 { break }
                    buffer.append(contentsOf: bytes.prefix(count))
                    while let index = buffer.firstIndex(of: 10) {
                        let line = Data(buffer[..<index]); buffer.removeSubrange(...index)
                        guard line.count <= HarnessProtocol.maximumMessageBytes else { throw HarnessError.resourceLimit }
                        await self?.receive(line)
                    }
                    guard buffer.count <= HarnessProtocol.maximumMessageBytes else { throw HarnessError.resourceLimit }
                }
            } catch {
                await self?.shutdown(reason: (error as? HarnessError) ?? .protocolMismatch)
                return
            }
            await self?.shutdown()
        }
        let params: [String: Any] = ["protocolVersion": "2025-11-25", "capabilities": [:],
                                     "clientInfo": ["name": "milyonus-swift-client", "version": "0.1.0"]]
        let initialized = try await rpc(method: "initialize", paramsData: JSONSerialization.data(withJSONObject: params))
        guard let result = try? JSONSerialization.jsonObject(with: initialized) as? [String: Any],
              result["protocolVersion"] as? String == "2025-11-25" else {
            shutdown(); throw HarnessError.protocolMismatch
        }
        try write(["jsonrpc": "2.0", "method": "notifications/initialized"])
    }
    public func shutdown() { shutdown(reason: .cancelled) }
    private func shutdown(reason: HarnessError) {
        guard !closed else { return }
        if reason == .timeout { diagnoseTimeout(pending.keys.min() ?? 0) }
        closed = true
        sessionLifecycle = UUID()
        heartbeatTask?.cancel(); heartbeatTask = nil; ownedSessionID = nil
        for continuation in pending.values { continuation.resume(throwing: reason) }
        pending.removeAll()
        for task in timeoutTasks.values { task.cancel() }
        timeoutTasks.removeAll()
        writer?.cancel(); writer = nil; outbound.removeAll()
        try? input.close()
        Self.terminateOwnedChild(process)
        if let reader { reader.cancel() } else { try? output.close() }
        reader = nil
    }
    private nonisolated static func terminateOwnedChild(_ child: Process) {
        guard child.isRunning else { return }
        child.terminate()
        // Only the directly launched child is eligible; never signal a process group.
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) {
            guard child.isRunning else { return }
            _ = Darwin.kill(child.processIdentifier, SIGKILL)
        }
    }
    package var childIsRunning: Bool { process.isRunning }
    package var childExitStatus: Int32? { process.isRunning ? nil : process.terminationStatus }
    private func readerDidFinish() { readerFinished = true }
    package var ioState: (queued: Int, backpressure: Int, bytes: Int, readerFinished: Bool) {
        (outbound.count, backpressureCount, writtenBytes, readerFinished)
    }
    package var sessionLifecycleState: (opening: Bool, owned: Bool, heartbeat: Bool, closed: Bool) {
        (openingSession, ownedSessionID != nil, heartbeatTask != nil, closed)
    }
    private func write(_ message: [String: Any]) throws {
        guard !closed else { throw HarnessError.cancelled }
        let data = try JSONSerialization.data(withJSONObject: message)
        guard data.count <= HarnessProtocol.maximumMessageBytes else { throw HarnessError.resourceLimit }
        guard outbound.count < 8 else { throw HarnessError.resourceLimit }
        outbound.append(OutboundFrame(data: data + Data([10])))
        if writer == nil {
            writer = Task { [weak self] in await self?.drainWrites() }
        }
    }
    private func drainWrites() async {
        defer { writer = nil }
        while !closed && !Task.isCancelled && !outbound.isEmpty {
            guard ContinuousClock.now < outbound[0].deadline else { shutdown(reason: .timeout); return }
            let frame = outbound[0]
            let count = frame.data.withUnsafeBytes { bytes in
                Darwin.write(input.fileDescriptor, bytes.baseAddress!.advanced(by: frame.offset),
                             min(4096, frame.data.count - frame.offset))
            }
            if count > 0 {
                writtenBytes += count
                outbound[0].offset += count
                if outbound[0].offset == frame.data.count { outbound.removeFirst() }
                // Keep Stop and reply handling runnable even during a sustained stream.
                await Task.yield()
            } else if count < 0 && errno == EINTR {
                await Task.yield()
            } else if count < 0 && (errno == EAGAIN || errno == EWOULDBLOCK) {
                backpressureCount += 1
                do { try await Task.sleep(for: .milliseconds(5)) } catch { return }
            } else {
                // A partial frame may already have reached the peer. Never replay it.
                shutdown(reason: .effectUnknown)
                return
            }
        }
    }
    private func receive(_ data: Data) {
        guard !closed else { return }
        receivedFrames += 1
        do {
            switch try RPCReply.decode(data) {
            case .notification: return
            case .result(let id, let result):
                takePending(id)?.resume(returning: result)
            case .failure(let id):
                takePending(id)?.resume(throwing: HarnessError.protocolMismatch)
            }
        } catch {
            shutdown(reason: .protocolMismatch)
        }
    }
    private func takePending(_ id: Int) -> CheckedContinuation<Data, Error>? {
        timeoutTasks.removeValue(forKey: id)?.cancel()
        return pending.removeValue(forKey: id)
    }
    private func diagnoseTimeout(_ id: Int) {
        guard !timeoutDiagnosed else { return }
        timeoutDiagnosed = true
        timeoutDiagnostic?(StdioTimeoutSnapshot(requestID: id, queued: outbound.count,
            writtenBytes: writtenBytes, receivedFrames: receivedFrames,
            readerFinished: readerFinished, childRunning: process.isRunning))
    }
    private func expire(_ id: Int) {
        if pending[id] != nil { diagnoseTimeout(id) }
        if let continuation = takePending(id) {
            continuation.resume(throwing: HarnessError.timeout)
            // A timeout is not permission to repeat an action. Close the session transport.
            shutdown()
        }
    }
    // Package-only observation for deterministic transport lifecycle regression tests.
    package var requestState: (pending: Int, issued: Int, timers: Int) { (pending.count, nextID, timeoutTasks.count) }
    private func rpc(method: String, paramsData: Data) async throws -> Data {
        if Task.isCancelled { shutdown(); throw HarnessError.cancelled }
        guard !closed else { throw HarnessError.cancelled }
        guard pending.count < 8 else { throw HarnessError.resourceLimit }
        nextID += 1; let id = nextID
        let response: Data = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending[id] = continuation
                do {
                    try write(["jsonrpc": "2.0", "id": id, "method": method,
                               "params": try JSONSerialization.jsonObject(with: paramsData)])
                    timeoutTasks[id] = Task { [weak self] in
                        do { try await Task.sleep(for: .seconds(10)) } catch { return }
                        await self?.expire(id)
                    }
                } catch { takePending(id)?.resume(throwing: error) }
            }
        } onCancel: { Task { await self.shutdown() } }
        // Cancellation can race a response already removed from the continuation table.
        guard !Task.isCancelled, !closed else { shutdown(); throw HarnessError.cancelled }
        return response
    }
    private func call<T: Decodable & Sendable>(_ name: String, arguments: Data) async throws -> T {
        let params = try JSONSerialization.data(withJSONObject: ["name": name,
                                 "arguments": try JSONSerialization.jsonObject(with: arguments)])
        let response = try await rpc(method: "tools/call", paramsData: params)
        let reply: ToolReply
        do { reply = try ToolReply.decode(response) }
        catch { shutdown(reason: .protocolMismatch); throw HarnessError.protocolMismatch }
        switch reply {
        case .failure(let error):
            // A valid domain refusal is not a malformed transport response.
            throw error
        case .value(let payload):
            do {
                _ = try StrictJSON.object(payload)
                let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(T.self, from: payload)
            } catch {
                shutdown(reason: .protocolMismatch)
                throw HarnessError.protocolMismatch
            }
        }
    }

    public func capabilities() async throws -> HarnessCapabilities {
        let value: HarnessCapabilities = try await call("system_capabilities", arguments: Data("{}".utf8))
        do { try value.validate() }
        catch { shutdown(reason: .protocolMismatch); throw HarnessError.protocolMismatch }
        return value
    }

    public func openFixtureSession() async throws -> Session {
        guard !closed else { throw HarnessError.cancelled }
        guard !openingSession else { throw HarnessError.leaseBusy }
        openingSession = true
        defer { openingSession = false }
        let lifecycle = sessionLifecycle
        let session: Session = try await call("session_open", arguments: Data("{}".utf8))
        guard !closed, !Task.isCancelled, lifecycle == sessionLifecycle else {
            // A created session may exist remotely. Close the dedicated connection;
            // never adopt a late open response or start its heartbeat after cancel.
            shutdown()
            throw HarnessError.cancelled
        }
        try validateSession(session)
        try requireReply(session.state == .awaitingApproval && session.generation == 1)
        sessionLifecycle = UUID()
        let heartbeatLifecycle = sessionLifecycle
        let heartbeatSessionID = session.id
        ownedSessionID = session.id
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                guard await self?.keepAlive(lifecycle: heartbeatLifecycle, sessionID: heartbeatSessionID) == true else { return }
            }
        }
        return session
    }
    /// Executes the same tick as the timer for package-only synthetic tests.
    package func heartbeatOnce() async -> Bool {
        guard let sessionID = ownedSessionID else { return false }
        return await keepAlive(lifecycle: sessionLifecycle, sessionID: sessionID)
    }
    private func ownsHeartbeat(lifecycle: UUID, sessionID: String) -> Bool {
        !closed && !Task.isCancelled && sessionLifecycle == lifecycle && ownedSessionID == sessionID
    }
    private func keepAlive(lifecycle: UUID, sessionID: String) async -> Bool {
        guard ownsHeartbeat(lifecycle: lifecycle, sessionID: sessionID) else { return false }
        do {
            let session = try await status()
            guard ownsHeartbeat(lifecycle: lifecycle, sessionID: sessionID),
                  let session, session.id == sessionID,
                  ![.cancelled, .expired].contains(session.state) else { return false }
            if session.state == .ready {
                _ = try await heartbeat(sessionID: session.id, generation: session.generation)
            }
            return ownsHeartbeat(lifecycle: lifecycle, sessionID: sessionID)
        } catch HarnessError.unauthorized {
            // A native pause may race status. Only this same lifecycle may poll again.
            return ownsHeartbeat(lifecycle: lifecycle, sessionID: sessionID)
        } catch HarnessError.staleObservation {
            return ownsHeartbeat(lifecycle: lifecycle, sessionID: sessionID)
        } catch {
            // Obsolete work must not tear down a newly owned session. Protocol/RPC
            // failures retain their own conservative transport shutdown behavior.
            if ownsHeartbeat(lifecycle: lifecycle, sessionID: sessionID) { shutdown() }
            return false
        }
    }
    private func requireReply(_ condition: Bool) throws {
        guard condition else { shutdown(reason: .protocolMismatch); throw HarnessError.protocolMismatch }
    }
    private func validateSession(_ session: Session, expectedID: String? = nil) throws {
        try requireReply((try? session.validate()) != nil && session.bundleId == HarnessProtocol.fixtureBundleID &&
                         (expectedID == nil || session.id == expectedID))
    }
    public func heartbeat(sessionID: String, generation: Int) async throws -> Session {
        struct Arguments: Encodable { let sessionId: String; let generation: Int }
        let session: Session = try await call("session_heartbeat", arguments: JSONEncoder().encode(Arguments(sessionId: sessionID, generation: generation)))
        try validateSession(session, expectedID: sessionID)
        try requireReply(session.generation == generation && session.state == .ready)
        return session
    }
    public func status() async throws -> Session? {
        let expectedID = ownedSessionID
        let session: Session? = try await call("session_status", arguments: Data("{}".utf8))
        if let session { try validateSession(session, expectedID: expectedID) }
        else { try requireReply(expectedID == nil) }
        return session
    }
    public func observe(sessionID: String) async throws -> Observation {
        let observation: Observation = try await call("desktop_observe", arguments: JSONEncoder().encode(["sessionId": sessionID]))
        try requireReply(observation.sessionId == sessionID && observation.bundleId == HarnessProtocol.fixtureBundleID &&
                         (try? observation.validate()) != nil)
        return observation
    }
    private func actionCall(_ name: String, request: ActionRequest) async throws -> ActionResult {
        let result: ActionResult = try await call(name, arguments: JSONEncoder().encode(request))
        guard result.requestId == request.requestId, (try? result.validate()) != nil else {
            // A transport-level ID alone cannot establish which desktop action completed.
            shutdown(reason: .protocolMismatch)
            throw HarnessError.protocolMismatch
        }
        return result
    }
    public func act(_ request: ActionRequest) async throws -> ActionResult {
        try request.validate()
        guard request.kind != .scroll, request.kind != .drag else { throw HarnessError.unsupportedCapability }
        return try await actionCall("desktop_action", request: request)
    }
    public func drag(_ request: ActionRequest) async throws -> ActionResult {
        try request.validate()
        guard request.kind == .drag else { throw HarnessError.invalidRequest }
        return try await actionCall("desktop_drag", request: request)
    }
    public func scroll(_ request: ActionRequest) async throws -> ActionResult {
        try request.validate()
        guard request.kind == .scroll else { throw HarnessError.invalidRequest }
        return try await actionCall("desktop_scroll", request: request)
    }
    public func click(_ request: ActionRequest) async throws -> ActionResult {
        try request.validate()
        guard request.kind == .press, request.text == nil else { throw HarnessError.invalidRequest }
        return try await actionCall("desktop_click", request: request)
    }
    public func typeText(_ request: ActionRequest) async throws -> ActionResult {
        try request.validate()
        guard request.kind == .setValue, let text = request.text, text.utf16.count <= 1024 else {
            throw HarnessError.invalidRequest
        }
        return try await actionCall("desktop_type_text", request: request)
    }
    public func cancel(sessionID: String) async throws {
        if openingSession || ownedSessionID == sessionID { sessionLifecycle = UUID() }
        if ownedSessionID == sessionID { heartbeatTask?.cancel(); heartbeatTask = nil; ownedSessionID = nil }
        let session: Session = try await call("session_cancel", arguments: JSONEncoder().encode(["sessionId": sessionID]))
        try validateSession(session, expectedID: sessionID)
        try requireReply(session.state == .cancelled || session.state == .expired)
    }
}
