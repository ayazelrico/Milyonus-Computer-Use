import Foundation
import Darwin
import ComputerUseContracts
import ComputerUseClient

private final class StdioTimeoutProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [StdioTimeoutSnapshot] = []
    func record(_ value: StdioTimeoutSnapshot) { lock.lock(); defer { lock.unlock() }; values.append(value) }
    func snapshots() -> [StdioTimeoutSnapshot] { lock.lock(); defer { lock.unlock() }; return values }
}

enum StdioFailureFixture {
    static func runIfRequested() throws {
        guard CommandLine.arguments.dropFirst().first == "--stdio-failure-child" else { return }
        guard CommandLine.arguments.count >= 3 else { exit(64) }
        let mode = CommandLine.arguments[2]
        func inheritedStage(_ stage: String) throws {
            guard CommandLine.arguments.count > 3 else { return }
            let path = URL(fileURLWithPath: CommandLine.arguments[3]).appendingPathExtension("stage")
            try Data(stage.utf8).write(to: path, options: .atomic)
        }
        try inheritedStage("child-started")
        if mode == "late" { signal(SIGPIPE, SIG_IGN) }
        if mode == "late" || mode == "hostile" || mode == "nonreading" {
            signal(SIGTERM, SIG_IGN)
        }
        if mode == "hostile" {
            // Fail-safe for a broken test implementation; production teardown must win first.
            DispatchQueue.global().asyncAfter(deadline: .now() + 8) { exit(73) }
        }
        guard readLine() != nil else { exit(65) }
        try inheritedStage("initialize-received")
        let response: String
        switch mode {
        case "duplicate-id": response = "{\"jsonrpc\":\"2.0\",\"id\":1,\"id\":1,\"result\":{\"protocolVersion\":\"2025-11-25\"}}"
        case "boolean": response = "{\"jsonrpc\":\"2.0\",\"id\":true,\"result\":{\"protocolVersion\":\"2025-11-25\"}}"
        case "ambiguous": response = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{},\"error\":{}}"
        case "invalid-initialize": response = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":null}"
        case "invalid": response = "not-json"
        case "oversized": response = String(repeating: "x", count: HarnessProtocol.maximumMessageBytes + 1)
        case "duplicate-tool", "duplicate-payload", "duplicate-error", "closed-input", "inherited-output", "slowreader", "nonreading", "hostile", "late", "pending", "action-valid", "action-unknown", "action-wrong-request", "action-empty-id", "action-path-id", "action-long-id", "action-unknown-passed", "action-not-applied-passed", "action-passed-error", "valid", "tool-multiple", "tool-wrong-type", "tool-numeric-flag", "tool-invalid-json", "tool-wrong-schema", "tool-unknown-error", "tool-domain-error": response = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"protocolVersion\":\"2025-11-25\"}}"
        default:
            guard mode.hasPrefix("state-") || mode.hasPrefix("caps-") else { exit(64) }
            response = "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"protocolVersion\":\"2025-11-25\"}}"
        }
        try FileHandle.standardOutput.write(contentsOf: Data((response + "\n").utf8))
        try inheritedStage("initialize-replied")
        if mode == "nonreading" { Thread.sleep(forTimeInterval: 15); exit(74) }
        if mode == "slowreader" { Thread.sleep(forTimeInterval: 0.3) }
        var heldOpenReply: Data?
        while let line = readLine() {
            let notification = (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any]
            try inheritedStage("request-received")
            if mode == "closed-input", notification?["method"] as? String == "notifications/initialized" {
                close(STDIN_FILENO)
                try Data("closed".utf8).write(to: URL(fileURLWithPath: CommandLine.arguments[3]), options: .atomic)
                Thread.sleep(forTimeInterval: 3)
                exit(0)
            }
            if mode == "inherited-output", notification?["method"] as? String == "notifications/initialized" {
                try inheritedStage("initialized-received")
                let holder = Process()
                holder.executableURL = URL(fileURLWithPath: "/bin/sleep")
                holder.arguments = ["3"]
                holder.environment = ["PATH": "/usr/bin:/bin"]
                holder.standardInput = FileHandle.nullDevice
                holder.standardOutput = FileHandle.standardOutput
                holder.standardError = FileHandle.nullDevice
                try holder.run()
                try Data("inherited".utf8).write(to: URL(fileURLWithPath: CommandLine.arguments[3]), options: .atomic)
                try inheritedStage("holder-started")
                exit(0)
            }
            if let request = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
               let id = request["id"] as? Int {
                if mode == "pending" || mode == "hostile" { continue }
                if mode == "late" {
                    let marker = URL(fileURLWithPath: CommandLine.arguments[3])
                    try Data("received".utf8).write(to: marker, options: .atomic)
                    Thread.sleep(forTimeInterval: 0.2)
                }
                var result: [String: Any] = ["content": [["type": "text", "text": "null"]], "isError": false]
                switch mode {
                case "caps-valid", "caps-policy", "caps-boolean":
                    var payload = try JSONSerialization.jsonObject(with: JSONEncoder().encode(HarnessCapabilities(permissions: ["accessibility": false, "screenRecording": false]))) as! [String: Any]
                    if mode == "caps-policy" { payload["requiresNativeApproval"] = false }
                    if mode == "caps-boolean" { payload["experimentalNativeFixtureDrag"] = 1 }
                    let encoded = try JSONSerialization.data(withJSONObject: payload)
                    result = ["isError": false, "content": [["type": "text", "text": String(decoding: encoded, as: UTF8.self)]]]
                case "duplicate-tool":
                    let bytes = Data("{\"jsonrpc\":\"2.0\",\"id\":\(id),\"result\":{\"content\":[{\"type\":\"text\",\"text\":\"null\"}],\"isError\":false,\"isError\":true}}\n".utf8)
                    try FileHandle.standardOutput.write(contentsOf: bytes)
                    continue
                case "duplicate-payload":
                    let text = "{\"id\":\"fixture-session\",\"id\":\"other\",\"bundleId\":\"com.milyonus.computeruse.fixture\",\"generation\":1,\"state\":\"ready\",\"expiresAt\":\"2030-01-01T00:00:00Z\"}"
                    result = ["isError": false, "content": [["type": "text", "text": text]]]
                case "duplicate-error":
                    result = ["isError": true, "content": [["type": "text", "text": "{\"error\":\"UNAUTHORIZED\",\"error\":\"CANCELLED\"}"]]]
                case "slowreader", "action-valid", "action-unknown", "action-wrong-request", "action-empty-id", "action-path-id", "action-long-id", "action-unknown-passed", "action-not-applied-passed", "action-passed-error":
                    let params = request["params"] as? [String: Any]
                    let arguments = params?["arguments"] as? [String: Any]
                    var actionID = "fixture-action"
                    if mode == "action-empty-id" { actionID = "" }
                    if mode == "action-path-id" { actionID = "../invalid" }
                    if mode == "action-long-id" { actionID = String(repeating: "x", count: 129) }
                    var action: [String: Any] = [
                        "requestId": mode == "action-wrong-request" ? "unrelated" : (arguments?["requestId"] as? String ?? "missing"),
                        "actionId": actionID, "effect": "applied", "verification": "passed"
                    ]
                    if mode == "action-unknown" {
                        action["effect"] = "unknown"; action["verification"] = "unavailable"; action["error"] = "EFFECT_UNKNOWN"
                    }
                    if mode == "action-unknown-passed" { action["effect"] = "unknown" }
                    if mode == "action-not-applied-passed" { action["effect"] = "notApplied" }
                    if mode == "action-passed-error" { action["error"] = "CANCELLED" }
                    let encoded = try JSONSerialization.data(withJSONObject: action)
                    result = ["isError": false, "content": [["type": "text", "text": String(decoding: encoded, as: UTF8.self)]]]
                case "tool-multiple": result["content"] = [["type": "text", "text": "null"], ["type": "text", "text": "{}"]]
                case "tool-wrong-type": result["content"] = [["type": "image", "text": "null"]]
                case "tool-numeric-flag": result["isError"] = 0
                case "tool-invalid-json": result["content"] = [["type": "text", "text": "not-json"]]
                case "tool-wrong-schema": result["content"] = [["type": "text", "text": "{}"]]
                case "tool-unknown-error", "tool-domain-error":
                    let code = mode == "tool-domain-error" ? "UNAUTHORIZED" : "UNRECOGNIZED"
                    result = ["isError": true, "content": [["type": "text", "text": "{\"error\":\"\(code)\"}"]]]
                default: break
                }
                if mode.hasPrefix("state-") {
                    let params = request["params"] as? [String: Any]
                    let name = params?["name"] as? String ?? ""
                    let arguments = params?["arguments"] as? [String: Any] ?? [:]
                    let operation = name == "desktop_observe" ? "observe" : name.replacingOccurrences(of: "session_", with: "")
                    let sessionID = arguments["sessionId"] as? String ?? "fixture-session"
                    var payload: [String: Any] = [
                        "id": sessionID, "bundleId": HarnessProtocol.fixtureBundleID, "generation": arguments["generation"] as? Int ?? 1,
                        "state": operation == "open" ? "awaitingApproval" : (operation == "cancel" ? "cancelled" : "ready"),
                        "expiresAt": "2030-01-01T00:00:00Z"
                    ]
                    if operation == "observe" {
                        payload = ["id": "fixture-observation", "sessionId": sessionID, "bundleId": HarnessProtocol.fixtureBundleID,
                                   "pid": 42, "capturedAt": "2026-10-25T00:00:00Z", "elements": [], "truncated": false,
                                   "source": "accessibility"]
                    }
                    if mode.hasPrefix("state-" + operation + "-") {
                        if mode.hasSuffix("wrong-id") { payload[operation == "observe" ? "sessionId" : "id"] = "unrelated" }
                        if mode.hasSuffix("wrong-app") { payload["bundleId"] = "com.example.other" }
                        if mode.hasSuffix("bad-generation") { payload["generation"] = 0 }
                        if mode.hasSuffix("bad-reason") { payload["pauseReason"] = "heartbeatLost" }
                        if mode.hasSuffix("bad-expiry") { payload["expiresAt"] = "invalid-date" }
                        if mode.hasSuffix("wrong-generation") { payload["generation"] = 99 }
                        if mode.hasSuffix("wrong-state") { payload["state"] = operation == "heartbeat" ? "paused" : "ready" }
                        if mode.hasSuffix("bad-pid") { payload["pid"] = 0 }
                        if mode.hasSuffix("bad-id") { payload["id"] = "../invalid" }
                        if operation == "observe" {
                            var element: [String: Any] = ["id": "element", "role": "AXButton", "enabled": true, "actions": ["press"]]
                            if mode.hasSuffix("duplicate-elements") { payload["elements"] = [element, element] }
                            if mode.hasSuffix("duplicate-actions") {
                                element["actions"] = ["press", "press"]; payload["elements"] = [element]
                            }
                            if mode.hasSuffix("oversized-text") {
                                element["label"] = String(repeating: "a", count: 48_000); payload["elements"] = [element]
                            }
                            if mode.hasSuffix("wrong-source") { payload["source"] = "shell" }
                        }
                        if mode.hasSuffix("expired") { payload["state"] = "expired" }
                    }
                    let text: String
                    if mode == "state-status-null" && operation == "status" { text = "null" }
                    else { text = String(decoding: try JSONSerialization.data(withJSONObject: payload), as: UTF8.self) }
                    result = ["isError": false, "content": [["type": "text", "text": text]]]
                }
                let reply: [String: Any] = ["jsonrpc": "2.0", "id": id, "result": result]
                let replyBytes = try JSONSerialization.data(withJSONObject: reply) + Data([10])
                if mode == "late" {
                    let phase: String
                    do { try FileHandle.standardOutput.write(contentsOf: replyBytes); phase = "replied" }
                    catch { phase = "pipe-closed" }
                    try Data(phase.utf8).write(to: URL(fileURLWithPath: CommandLine.arguments[3]), options: .atomic)
                    exit(0)
                }
                if mode == "state-status-held" || mode == "state-status-held-until-open" {
                    let params = request["params"] as? [String: Any]
                    let name = params?["name"] as? String
                    if name == "session_status" {
                        heldOpenReply = replyBytes
                        continue
                    }
                    try FileHandle.standardOutput.write(contentsOf: replyBytes)
                    let release = mode == "state-status-held" ? name == "session_cancel" : name == "session_open"
                    if release, let held = heldOpenReply {
                        try FileHandle.standardOutput.write(contentsOf: held)
                        heldOpenReply = nil
                    }
                    continue
                }
                if mode == "state-open-held" {
                    let params = request["params"] as? [String: Any]
                    if params?["name"] as? String == "session_open" {
                        heldOpenReply = replyBytes
                        continue
                    }
                    try FileHandle.standardOutput.write(contentsOf: replyBytes)
                    if let heldOpenReply { try FileHandle.standardOutput.write(contentsOf: heldOpenReply) }
                    heldOpenReply = nil
                    continue
                }
                try FileHandle.standardOutput.write(contentsOf: replyBytes)
                try inheritedStage("reply-written")
            }
        }
        if mode == "hostile" {
            // Ignore EOF as well as SIGTERM so the SDK must enforce its deadline.
            while true { Thread.sleep(forTimeInterval: 0.1) }
        }
        exit(0)
    }
}

@MainActor
final class StdioFailureTests: TestCase {
    func client(mode: String, marker: URL? = nil,
                onTimeout: (@Sendable (StdioTimeoutSnapshot) -> Void)? = nil) throws -> StdioHarnessClient {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let script = directory.appendingPathComponent("fixture")
        let executable = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.path
        let quoted = "'" + executable.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
        let diagnosticMarker = marker ?? directory.appendingPathComponent("diagnostic")
        let markerArgument = " '" + diagnosticMarker.path.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
        try Data(("#!/bin/sh\nexec " + quoted + " --stdio-failure-child " + mode + markerArgument + "\n").utf8).write(to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        return try StdioHarnessClient(companionExecutable: script, timeoutDiagnostic: { snapshot in
            onTimeout?(snapshot)
            let raw = try? String(contentsOf: diagnosticMarker.appendingPathExtension("stage"), encoding: .utf8)
            let stages = ["child-started", "initialize-received", "initialize-replied", "initialized-received", "holder-started", "request-received", "reply-written"]
            let stage = raw.flatMap { stages.contains($0) ? $0 : nil } ?? "unavailable"
            print("STDIO_TIMEOUT mode=\(mode) stage=\(stage) request=\(snapshot.requestID) queued=\(snapshot.queued) writtenBytes=\(snapshot.writtenBytes) receivedFrames=\(snapshot.receivedFrames) readerFinished=\(snapshot.readerFinished) childRunning=\(snapshot.childRunning)")
        })
    }
    func testInvalidPipeRepliesCloseTransport() async throws {
        for mode in ["duplicate-id", "boolean", "ambiguous", "invalid", "invalid-initialize", "oversized"] {
            let client = try client(mode: mode)
            let started = ContinuousClock.now
            do {
                try await client.connect()
                fail("Malformed pipe reply must not initialize the client")
            } catch {
                expectEqual(error as? HarnessError, mode == "oversized" ? .resourceLimit : .protocolMismatch)
            }
            expectEqual(started.duration(to: .now) < .seconds(5), true)
            do {
                _ = try await client.status()
                fail("Failed transport must not accept another RPC")
            } catch { expectEqual(error as? HarnessError, .cancelled) }
            await client.shutdown()
        }
    }
    func testValidPipeReplyStillConnects() async throws {
        let client = try client(mode: "valid")
        do {
            try await client.connect()
            let status = try await client.status()
            expectEqual(status, nil)
        } catch {
            await client.shutdown()
            throw error
        }
        await client.shutdown()
    }
    func testMalformedToolResultsCloseTransport() async throws {
        for mode in ["duplicate-tool", "duplicate-payload", "duplicate-error", "tool-multiple", "tool-wrong-type", "tool-numeric-flag", "tool-invalid-json",
                     "tool-wrong-schema", "tool-unknown-error"] {
            let client = try client(mode: mode)
            do {
                try await client.connect()
                do {
                    _ = try await client.status()
                    fail("Malformed tool result must be refused")
                } catch { expectEqual(error as? HarnessError, .protocolMismatch) }
                do {
                    _ = try await client.status()
                    fail("Malformed result must close transport")
                } catch { expectEqual(error as? HarnessError, .cancelled) }
            } catch { await client.shutdown(); throw error }
            await client.shutdown()
        }
    }
    func testDomainRefusalDoesNotCloseTransport() async throws {
        let client = try client(mode: "tool-domain-error")
        do {
            try await client.connect()
            for _ in 0..<2 {
                do { _ = try await client.status(); fail("Expected domain refusal") }
                catch { expectEqual(error as? HarnessError, .unauthorized) }
            }
        } catch { await client.shutdown(); throw error }
        await client.shutdown()
    }

    func sendAction(_ method: String, client: StdioHarnessClient) async throws -> ActionResult {
        let action = ActionRequest(requestId: "expected-request", sessionId: "fixture-session", idempotencyKey: "fixture-key",
                                   observationId: "fixture-observation", generation: 1, elementId: "fixture-element",
                                   kind: method == "drag" ? .drag : (method == "scroll" ? .scroll : (method == "type" ? .setValue : .press)), text: method == "type" ? "fixture text" : nil, scrollPixels: method == "scroll" ? -200 : nil)
        switch method {
        case "drag": return try await client.drag(action)
        case "scroll": return try await client.scroll(action)
        case "click": return try await client.click(action)
        case "type": return try await client.typeText(action)
        default: return try await client.act(action)
        }
    }
    func testInvalidActionResponsesCloseAllMutationRoutes() async throws {
        for mode in ["action-wrong-request", "action-empty-id", "action-path-id", "action-long-id", "action-unknown-passed", "action-not-applied-passed", "action-passed-error"] {
            for method in ["act", "click", "type", "scroll", "drag"] {
                let client = try client(mode: mode)
                do {
                    try await client.connect()
                    do {
                        _ = try await sendAction(method, client: client)
                        fail("Invalid action response must not be accepted")
                    } catch { expectEqual(error as? HarnessError, .protocolMismatch) }
                    do {
                        _ = try await sendAction(method, client: client)
                        fail("Mutation must not be retried on a closed transport")
                    } catch { expectEqual(error as? HarnessError, .cancelled) }
                } catch { await client.shutdown(); throw error }
                await client.shutdown()
            }
        }
    }
    func testCorrelatedActionResponsesPreserveOutcome() async throws {
        for mode in ["action-valid", "action-unknown"] {
            let client = try client(mode: mode)
            do {
                try await client.connect()
                for method in ["act", "click", "type", "scroll", "drag"] {
                    let result = try await sendAction(method, client: client)
                    expectEqual(result.requestId, "expected-request")
                    expectEqual(result.actionId, "fixture-action")
                    expectEqual(result.effect, mode == "action-unknown" ? .unknown : .applied)
                    expectEqual(result.verification, mode == "action-unknown" ? .unavailable : .passed)
                    expectEqual(result.error, mode == "action-unknown" ? .effectUnknown : nil)
                }
            } catch { await client.shutdown(); throw error }
            await client.shutdown()
        }
    }

    func performSessionOperation(_ operation: String, client: StdioHarnessClient) async throws {
        switch operation {
        case "open": _ = try await client.openFixtureSession()
        case "status": _ = try await client.openFixtureSession(); _ = try await client.status()
        case "heartbeat": _ = try await client.heartbeat(sessionID: "fixture-session", generation: 1)
        case "cancel": try await client.cancel(sessionID: "fixture-session")
        case "observe": _ = try await client.observe(sessionID: "fixture-session")
        default: fail("Unknown test operation")
        }
    }
    func testSessionAndObservationMismatchesCloseTransport() async throws {
        let scenarios = [
            ("open", ["wrong-app", "bad-id", "bad-generation", "wrong-state", "bad-reason", "bad-expiry"]),
            ("status", ["wrong-id", "wrong-app", "bad-generation", "null", "bad-reason", "bad-expiry"]),
            ("heartbeat", ["wrong-id", "wrong-app", "wrong-generation", "wrong-state", "bad-reason", "bad-expiry"]),
            ("cancel", ["wrong-id", "wrong-app", "wrong-state", "bad-reason", "bad-expiry"]),
            ("observe", ["wrong-id", "wrong-app", "bad-pid", "bad-id", "duplicate-elements", "duplicate-actions", "oversized-text", "wrong-source"])
        ]
        for (operation, faults) in scenarios {
            for fault in faults {
                let client = try client(mode: "state-" + operation + "-" + fault)
                do {
                    try await client.connect()
                    do {
                        try await performSessionOperation(operation, client: client)
                        fail("Mismatched response must be rejected")
                    } catch { expectEqual(error as? HarnessError, .protocolMismatch) }
                    do {
                        _ = try await client.status()
                        fail("Mismatched response must close transport")
                    } catch { expectEqual(error as? HarnessError, .cancelled) }
                } catch { await client.shutdown(); throw error }
                await client.shutdown()
            }
        }
    }
    func testHeartbeatCannotRenewAfterOwnershipCancellation() async throws {
        let client = try client(mode: "state-status-held")
        try await client.connect()
        let session = try await client.openFixtureSession()
        let tick = Task { await client.heartbeatOnce() }
        try await waitForPending(1, client: client)
        let issued = await client.requestState.issued
        try await client.cancel(sessionID: session.id)
        let continued = await tick.value
        expectEqual(continued, false)
        let after = await client.requestState.issued
        expectEqual(after, issued + 1) // Only cancel, no late heartbeat.
        let state = await client.sessionLifecycleState
        expectEqual(state.owned, false); expectEqual(state.heartbeat, false)
        expectEqual(state.closed, false)
        await client.shutdown()
    }
    func testOldHeartbeatCannotFollowReusedSessionIdentity() async throws {
        let client = try client(mode: "state-status-held-until-open")
        try await client.connect()
        let original = try await client.openFixtureSession()
        let tick = Task { await client.heartbeatOnce() }
        try await waitForPending(1, client: client)
        let issued = await client.requestState.issued
        try await client.cancel(sessionID: original.id)
        let replacement = try await client.openFixtureSession()
        expectEqual(replacement.id, original.id) // Adversarial peer reuses the identifier.
        let continued = await tick.value
        expectEqual(continued, false)
        let after = await client.requestState.issued
        expectEqual(after, issued + 2) // Cancel and open only.
        let state = await client.sessionLifecycleState
        expectEqual(state.owned, true); expectEqual(state.heartbeat, true)
        expectEqual(state.closed, false)
        await client.shutdown()
    }
    func testCurrentHeartbeatTickStillRenewsAndStopsAfterShutdown() async throws {
        let client = try client(mode: "state-valid")
        try await client.connect()
        _ = try await client.openFixtureSession()
        let before = await client.requestState.issued
        let continued = await client.heartbeatOnce()
        expectEqual(continued, true)
        let after = await client.requestState.issued
        expectEqual(after, before + 2) // Status plus one heartbeat.
        await client.shutdown()
        let stopped = await client.heartbeatOnce()
        expectEqual(stopped, false)
        let final = await client.requestState.issued
        expectEqual(final, after)
    }
    func testConcurrentOpenRefusedBeforeSecondRPC() async throws {
        let client = try client(mode: "state-open-held")
        try await client.connect()
        let first = Task { try await client.openFixtureSession() }
        try await waitForPending(1, client: client)
        let issued = await client.requestState.issued
        do { _ = try await client.openFixtureSession(); fail("Concurrent open accepted") }
        catch { expectEqual(error as? HarnessError, .leaseBusy) }
        let after = await client.requestState.issued
        expectEqual(after, issued)
        await client.shutdown()
        do { _ = try await first.value; fail("Closed open returned session") }
        catch { expectEqual(error as? HarnessError, .cancelled) }
        let state = await client.sessionLifecycleState
        expectEqual(state.opening, false); expectEqual(state.owned, false)
        expectEqual(state.heartbeat, false); expectEqual(state.closed, true)
    }
    func testCancelWhileOpeningCannotAdoptLateSession() async throws {
        let client = try client(mode: "state-open-held")
        try await client.connect()
        let opening = Task { try await client.openFixtureSession() }
        try await waitForPending(1, client: client)
        var cancelError: Error?
        do { try await client.cancel(sessionID: "fixture-session") }
        catch { cancelError = error }
        // The cancel response may win the race, or terminal shutdown may reject it.
        expectEqual(cancelError == nil || (cancelError as? HarnessError) == .cancelled, true)
        do { _ = try await opening.value; fail("Cancelled opening adopted late response") }
        catch { expectEqual(error as? HarnessError, .cancelled) }
        let state = await client.sessionLifecycleState
        expectEqual(state.opening, false); expectEqual(state.owned, false)
        expectEqual(state.heartbeat, false); expectEqual(state.closed, true)
        let issued = await client.requestState.issued
        do { _ = try await client.openFixtureSession(); fail("Closed client reopened") }
        catch { expectEqual(error as? HarnessError, .cancelled) }
        let after = await client.requestState.issued
        expectEqual(after, issued)
        await client.shutdown()
    }
    func testCorrelatedSessionAndObservationControls() async throws {
        let client = try client(mode: "state-valid")
        do {
            try await client.connect()
            let session = try await client.openFixtureSession()
            expectEqual(session.id, "fixture-session")
            expectEqual(session.state, .awaitingApproval)
            let status = try await client.status()
            expectEqual(status?.id, session.id)
            let heartbeat = try await client.heartbeat(sessionID: session.id, generation: 1)
            expectEqual(heartbeat.generation, 1)
            expectEqual(heartbeat.state, .ready)
            let observation = try await client.observe(sessionID: session.id)
            expectEqual(observation.sessionId, session.id)
            expectEqual(observation.pid, 42)
            try await client.cancel(sessionID: session.id)
        } catch { await client.shutdown(); throw error }
        await client.shutdown()
        let expiredClient = try self.client(mode: "state-cancel-expired")
        do {
            try await expiredClient.connect()
            try await expiredClient.cancel(sessionID: "fixture-session")
        } catch { await expiredClient.shutdown(); throw error }
        await expiredClient.shutdown()
    }

    func waitForPending(_ count: Int, client: StdioHarnessClient) async throws {
        for _ in 0..<200 {
            if await client.requestState.pending == count { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        await client.shutdown()
        throw HarnessError.timeout
    }
    func testPreCancelledRequestNeverDispatches() async throws {
        let client = try client(mode: "valid")
        try await client.connect()
        let issued = await client.requestState.issued
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await client.status()
        }
        do { _ = try await task.value; fail("Pre-cancelled call must fail") }
        catch { expectEqual(error as? HarnessError, .cancelled) }
        let state = await client.requestState
        expectEqual(state.issued, issued)
        expectEqual(state.pending, 0)
        await client.shutdown()
    }
    func testCancellingPendingCallDrainsSiblingRequests() async throws {
        let client = try client(mode: "pending")
        try await client.connect()
        let first = Task { try await client.status() }
        let second = Task { try await client.status() }
        try await waitForPending(2, client: client)
        first.cancel()
        for task in [first, second] {
            do { _ = try await task.value; fail("Pending call must be cancelled") }
            catch { expectEqual(error as? HarnessError, .cancelled) }
        }
        let pendingCount = await client.requestState.pending
        expectEqual(pendingCount, 0)
        do { _ = try await client.status(); fail("Cancelled transport must remain closed") }
        catch { expectEqual(error as? HarnessError, .cancelled) }
        await client.shutdown()
    }
    func testShutdownDrainsPendingCallIdempotently() async throws {
        let client = try client(mode: "pending")
        try await client.connect()
        let task = Task { try await client.status() }
        try await waitForPending(1, client: client)
        await client.shutdown()
        await client.shutdown()
        do { _ = try await task.value; fail("Shutdown must cancel pending call") }
        catch { expectEqual(error as? HarnessError, .cancelled) }
        let pendingCount = await client.requestState.pending
        expectEqual(pendingCount, 0)
    }

    func testLateReplyAfterCancellationCannotReviveCall() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let marker = directory.appendingPathComponent("phase")
        let client = try client(mode: "late", marker: marker)
        try await client.connect()
        let task = Task { try await client.status() }
        func waitForPhase(_ phase: String) async throws {
            for _ in 0..<400 {
                let current = try? String(contentsOf: marker, encoding: .utf8)
                if current == phase || (phase == "replied" && current == "pipe-closed") { return }
                try await Task.sleep(for: .milliseconds(5))
            }
            await client.shutdown()
            throw HarnessError.timeout
        }
        try await waitForPhase("received")
        task.cancel()
        do { _ = try await task.value; fail("Cancellation must win before delayed reply") }
        catch { expectEqual(error as? HarnessError, .cancelled) }
        try await waitForPhase("replied")
        let pending = await client.requestState.pending
        expectEqual(pending, 0)
        do { _ = try await client.status(); fail("Late reply cannot reopen transport") }
        catch { expectEqual(error as? HarnessError, .cancelled) }
        await client.shutdown()
    }

    func waitForChildExit(_ client: StdioHarnessClient) async throws {
        for _ in 0..<300 {
            if await !client.childIsRunning { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw HarnessError.timeout
    }
    func testShutdownEscalatesOnlyOwnedUnresponsiveChild() async throws {
        let client = try client(mode: "hostile")
        try await client.connect()
        let call = Task { try await client.status() }
        try await waitForPending(1, client: client)
        let started = ContinuousClock.now
        await client.shutdown()
        await client.shutdown()
        do { _ = try await call.value; fail("Shutdown must drain pending call") }
        catch { expectEqual(error as? HarnessError, .cancelled) }
        try await waitForChildExit(client)
        let status = await client.childExitStatus
        expectEqual(status, SIGKILL)
        expectEqual(started.duration(to: .now) < .seconds(3), true)
        let pending = await client.requestState.pending
        expectEqual(pending, 0)
    }
    func testCancellationEscalatesUnresponsiveChild() async throws {
        let client = try client(mode: "hostile")
        try await client.connect()
        let call = Task { try await client.status() }
        try await waitForPending(1, client: client)
        call.cancel()
        do { _ = try await call.value; fail("Cancelled call must not succeed") }
        catch { expectEqual(error as? HarnessError, .cancelled) }
        try await waitForChildExit(client)
        let status = await client.childExitStatus
        expectEqual(status, SIGKILL)
        await client.shutdown()
    }
    func testCooperativeChildExitsWithoutEscalation() async throws {
        let client = try client(mode: "valid")
        try await client.connect()
        // The regular valid peer exits normally or on SIGTERM; it does not ignore shutdown.
        await client.shutdown()
        try await waitForChildExit(client)
        let status = await client.childExitStatus
        expectFalse(status == SIGKILL)
    }

    func waitForEmptyWriteQueue(_ client: StdioHarnessClient) async throws {
        for _ in 0..<200 {
            if await client.ioState.queued == 0 { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        await client.shutdown()
        throw HarnessError.timeout
    }
    func startLargeRequests(_ client: StdioHarnessClient) -> [Task<ActionResult, Error>] {
        (0..<8).map { index in
            Task {
                try await client.act(ActionRequest(requestId: "large-\(index)", sessionId: "fixture-session",
                    idempotencyKey: "key-\(index)", observationId: "observation", generation: 1,
                    elementId: "element", kind: .setValue, text: String(repeating: "x", count: 16384)))
            }
        }
    }
    func waitForBackpressure(_ client: StdioHarnessClient) async throws {
        for _ in 0..<400 {
            if await client.ioState.backpressure > 0 { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        await client.shutdown()
        throw HarnessError.timeout
    }
    func checkBackpressureCancellation(cancelTask: Bool) async throws {
        let client = try client(mode: "nonreading")
        try await client.connect()
        try await waitForEmptyWriteQueue(client)
        let calls = startLargeRequests(client)
        try await waitForBackpressure(client)
        let started = ContinuousClock.now
        if cancelTask { calls[0].cancel() } else { await client.shutdown() }
        for call in calls {
            do { _ = try await call.value; fail("Blocked requests must be cancelled") }
            catch { expectEqual(error as? HarnessError, .cancelled) }
        }
        expectEqual(started.duration(to: .now) < .seconds(1), true)
        let state = await client.ioState
        expectEqual(state.queued, 0)
        expectEqual(state.backpressure > 0, true)
        try await waitForChildExit(client)
        for _ in 0..<100 {
            if await client.ioState.readerFinished { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        let readerFinished = await client.ioState.readerFinished
        expectEqual(readerFinished, true)
        await client.shutdown()
    }
    func testShutdownRemainsResponsiveUnderWriteBackpressure() async throws {
        try await checkBackpressureCancellation(cancelTask: false)
    }
    func testTaskCancellationRemainsResponsiveUnderWriteBackpressure() async throws {
        try await checkBackpressureCancellation(cancelTask: true)
    }
    func testPartialWritesPreserveRequestFrames() async throws {
        let client = try client(mode: "slowreader")
        try await client.connect()
        try await waitForEmptyWriteQueue(client)
        let calls = startLargeRequests(client)
        do {
            for (index, call) in calls.enumerated() {
                let result = try await call.value
                expectEqual(result.requestId, "large-\(index)")
                expectEqual(result.effect, .applied)
            }
        } catch { await client.shutdown(); throw error }
        let state = await client.ioState
        expectEqual(state.queued, 0)
        expectEqual(state.backpressure > 0, true)
        await client.shutdown()
    }
    func testBlockedWritesExpireWithoutReplay() async throws {
        let client = try client(mode: "nonreading")
        try await client.connect()
        try await waitForEmptyWriteQueue(client)
        let calls = startLargeRequests(client)
        try await waitForBackpressure(client)
        var timeouts = 0
        for call in calls {
            do { _ = try await call.value; fail("Blocked request must time out") }
            catch {
                let error = error as? HarnessError
                expectEqual(error == .timeout || error == .cancelled, true)
                if error == .timeout { timeouts += 1 }
            }
        }
        expectEqual(timeouts > 0, true)
        let state = await client.requestState
        expectEqual(state.issued, 9)
        expectEqual(state.pending, 0)
        try await waitForChildExit(client)
        await client.shutdown()
    }

    func testReaderStopsWithInheritedOutputStillOpen() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let marker = directory.appendingPathComponent("inherited")
        let client = try client(mode: "inherited-output", marker: marker)
        do { try await client.connect() }
        catch {
            let state = await client.ioState
            let requests = await client.requestState
            let childRunning = await client.childIsRunning
            let rawStage = try? String(contentsOf: marker.appendingPathExtension("stage"), encoding: .utf8)
            let knownStages = ["child-started", "initialize-received", "initialize-replied", "initialized-received", "holder-started"]
            let stage = rawStage.flatMap { knownStages.contains($0) ? $0 : nil } ?? "unavailable"
            print("INHERITED_OUTPUT_DIAGNOSTIC stage=\(stage) childRunning=\(childRunning) queued=\(state.queued) writtenBytes=\(state.bytes) readerFinished=\(state.readerFinished) pending=\(requests.pending) timers=\(requests.timers)")
            await client.shutdown()
            throw error
        }
        for _ in 0..<200 {
            if FileManager.default.fileExists(atPath: marker.path) { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        expectEqual(FileManager.default.fileExists(atPath: marker.path), true)
        let start = ContinuousClock.now
        await client.shutdown()
        for _ in 0..<100 {
            if await client.ioState.readerFinished { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        let finished = await client.ioState.readerFinished
        expectEqual(finished, true)
        expectEqual(start.duration(to: .now) < .seconds(1), true)
        // The unrelated descendant is not signalled; its three-second sleep expires naturally.
    }

    func testTimeoutDiagnosticsPreserveDeadlineAndTerminalCleanup() async throws {
        let probe = StdioTimeoutProbe()
        let client = try client(mode: "pending", onTimeout: { probe.record($0) })
        try await client.connect()
        do { _ = try await client.status(); fail("Unanswered request did not expire") }
        catch { expectEqual(error as? HarnessError, .timeout) }
        let snapshots = probe.snapshots()
        expectEqual(snapshots.count, 1)
        let snapshot = try requireValue(snapshots.first)
        expectEqual(snapshot.requestID, 2)
        expectEqual(snapshot.queued, 0)
        expectEqual(snapshot.writtenBytes > 0, true)
        expectEqual(snapshot.receivedFrames, 1)
        expectEqual(snapshot.childRunning, true)
        expectEqual(snapshot.readerFinished, false)
        do { _ = try await client.status(); fail("Timed-out transport remained open") }
        catch { expectEqual(error as? HarnessError, .cancelled) }
        expectEqual(probe.snapshots().count, 1)
        await client.shutdown()
    }

    func testCompletedRequestsReleaseTimeoutTasks() async throws {
        let client = try client(mode: "valid")
        try await client.connect()
        for _ in 0..<32 {
            _ = try await client.status()
            let state = await client.requestState
            expectEqual(state.pending, 0)
            expectEqual(state.timers, 0)
        }
        await client.shutdown()
        let state = await client.requestState
        expectEqual(state.timers, 0)
    }
    func testShutdownReleasesPendingTimeoutTasks() async throws {
        let client = try client(mode: "pending")
        try await client.connect()
        let call = Task { try await client.status() }
        try await waitForPending(1, client: client)
        let before = await client.requestState
        expectEqual(before.timers, 1)
        await client.shutdown()
        do { _ = try await call.value; fail("Pending request must be cancelled") }
        catch { expectEqual(error as? HarnessError, .cancelled) }
        let after = await client.requestState
        expectEqual(after.timers, 0)
        expectEqual(after.pending, 0)
    }

    func testClosedInputDoesNotSignalSDKOrReplay() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let marker = directory.appendingPathComponent("closed")
        let client = try client(mode: "closed-input", marker: marker)
        try await client.connect()
        for _ in 0..<200 {
            if FileManager.default.fileExists(atPath: marker.path) { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        expectEqual(FileManager.default.fileExists(atPath: marker.path), true)
        do { _ = try await sendAction("act", client: client); fail("Closed input must fail") }
        catch { expectEqual(error as? HarnessError, .effectUnknown) }
        let state = await client.requestState
        expectEqual(state.issued, 2)
        expectEqual(state.pending, 0)
        expectEqual(state.timers, 0)
        do { _ = try await client.status(); fail("Failed write must close transport") }
        catch { expectEqual(error as? HarnessError, .cancelled) }
        await client.shutdown()
    }
    func testPendingLimitRefusesNewWorkWithoutEviction() async throws {
        let client = try client(mode: "nonreading")
        try await client.connect()
        try await waitForEmptyWriteQueue(client)
        let calls = startLargeRequests(client)
        try await waitForPending(8, client: client)
        try await waitForBackpressure(client)
        do { _ = try await client.status(); fail("Ninth pending request must be refused") }
        catch { expectEqual(error as? HarnessError, .resourceLimit) }
        let state = await client.requestState
        expectEqual(state.pending, 8)
        expectEqual(state.timers, 8)
        expectEqual(state.issued, 9)
        await client.shutdown()
        for call in calls {
            do { _ = try await call.value; fail("Queued request must be cancelled") }
            catch { expectEqual(error as? HarnessError, .cancelled) }
        }
        try await waitForChildExit(client)
    }

}
