import Foundation
import CryptoKit
import ComputerUseMacOS
import ComputerUseClient
import ComputerUseContracts
import ComputerUseAgent

/// Deterministic acceptance planner, never represented as real provider inference.
private struct SlowFixturePlanner: ActionPlanner {
    let desired: String
    func next(_ context: PlannerContext, deadline: Date) async throws -> PlannerStep {
        if context.observation.elements.contains(where: { $0.identifier == "fixture.input" && $0.value == desired }) {
            return .finish
        }
        try await Task.sleep(for: .seconds(18))
        guard Date() < deadline else { throw HarnessError.timeout }
        return .action(PlannedAction(elementIdentifier: "fixture.input", kind: .setValue, text: desired))
    }
}

do {
let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.count == 3, arguments[0] == "gesture-fixture-selftest", arguments[2] == "--allow-native-fixture-input" {
    if !(await runGestureAcceptance(companionPath: arguments[1])) { exit(1) }
} else if arguments == ["anthropic-plan-check"] {
    let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
    let model = ProcessInfo.processInfo.environment["MILYONUS_ANTHROPIC_MODEL"] ?? ""
    guard !key.isEmpty else { throw HarnessError.providerCredentialsRequired }
    let completion = CompletionCondition(elementIdentifier: "fixture.input", value: "Provider contract check")
    let planner = try AnthropicMessagesPlanner(sessionID: "synthetic-session", model: model,
        completion: completion, allowFixtureObservationEgress: true, apiKey: { key })
    func context(value: String) -> PlannerContext {
        PlannerContext(goal: "Set fixture.input to Provider contract check, then finish without saving.",
            observation: Observation(id: "synthetic-observation", sessionId: "synthetic-session",
                bundleId: "com.milyonus.computeruse.fixture", pid: 1, capturedAt: Date(),
                elements: [ElementSnapshot(id: "synthetic-element", role: "AXTextField", identifier: "fixture.input",
                    label: nil, value: value, bounds: nil, enabled: true, actions: [.setValue])], truncated: false), remainingSteps: 2)
    }
    guard case .action(let action) = try await planner.next(context(value: ""), deadline: Date().addingTimeInterval(60)),
          action.kind == .setValue, action.elementIdentifier == "fixture.input", action.text == completion.value else {
        throw HarnessError.verificationFailed
    }
    guard case .finish = try await planner.next(context(value: completion.value), deadline: Date().addingTimeInterval(60)) else {
        throw HarnessError.verificationFailed
    }
    let result: [String: Any] = ["suite": "anthropic-live-planner-contract", "realInference": true,
        "syntheticObservations": true, "desktopActions": 0, "verifiedProposals": 2, "requestedModel": model]
    print(String(decoding: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), as: UTF8.self))
} else if arguments == ["doctor"] {
    let result: [String: Any] = [
        "version": "0.1.0", "platform": "macOS", "osVersion": ProcessInfo.processInfo.operatingSystemVersionString,
        "permissions": Permissions.status(),
        "mutationTransport": "companion --mcp (native approval required)",
        "supportedMutationApps": ["com.milyonus.computeruse.fixture"],
        "productionReady": false
    ]
    let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
    print(String(decoding: data, as: UTF8.self))
 } else if arguments == ["contract-fixtures"] {
    let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
    func object<T: Encodable>(_ value: T) throws -> Any { try JSONSerialization.jsonObject(with: encoder.encode(value)) }
    let action = ActionRequest(requestId: "request", sessionId: "session", idempotencyKey: "key", observationId: "observation",
        generation: 1, elementId: "element", kind: .setValue, text: "İstanbul 👩🏽‍💻")
    var session = Session(id: "session", bundleId: "com.milyonus.computeruse.fixture", generation: 2, state: .paused,
        expiresAt: Date(timeIntervalSince1970: 1_800_000_000))
    session.pauseReason = .heartbeatLost
    let observation = Observation(id: "observation", sessionId: "session", bundleId: session.bundleId, pid: 42,
        capturedAt: Date(timeIntervalSince1970: 1_800_000_000),
        elements: [ElementSnapshot(id: "element", role: "AXTextField", identifier: "fixture.input", label: nil, value: "fixture",
            bounds: Rect(x: -100, y: 20, width: 300, height: 30), enabled: true, actions: [.setValue])], truncated: false)
    let scroll = ActionRequest(requestId: "scroll-request", sessionId: "session", idempotencyKey: "scroll-key",
        observationId: "observation", generation: 1, elementId: "scroll-element", kind: .scroll, scrollPixels: -200)
    let drag = ActionRequest(requestId: "drag-request", sessionId: "session", idempotencyKey: "drag-key",
        observationId: "observation", generation: 1, elementId: "drag-element", kind: .drag)
    let fixtures: [String: Any] = ["capabilities": try object(HarnessCapabilities(permissions: ["accessibility": false, "screenRecording": false])), "drag": try object(drag), "scroll": try object(scroll), "action": try object(action), "session": try object(session),
        "observation": try object(observation),
        "result": try object(ActionResult(requestId: "request", actionId: "action", effect: .unknown, verification: .unavailable, error: .effectUnknown)),
        "heartbeat": ["sessionId": "session", "generation": 2]]
    print(String(decoding: try JSONSerialization.data(withJSONObject: fixtures, options: [.sortedKeys]), as: UTF8.self))
} else if arguments == ["capture-inventory"] {
    let inventory = try await ScreenCapture.fixtureWindowInventory()
    print(String(decoding: try JSONSerialization.data(withJSONObject: inventory, options: [.sortedKeys]), as: UTF8.self))
} else if arguments == ["capture-fixture"] {
    let frame = try await ScreenCapture.captureFixture()
    let result: [String: Any] = ["windowId": frame.windowID, "pixelWidth": frame.transform.pixelWidth,
        "pixelHeight": frame.transform.pixelHeight, "pngBytes": frame.png.count,
        "sha256": SHA256.hash(data: frame.png).map { String(format: "%02x", $0) }.joined(),
        "imageWrittenToDisk": false, "imageSentToProvider": false]
    print(String(decoding: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), as: UTF8.self))
 } else if (arguments.count == 3 && ["agent-fixture", "anthropic-fixture"].contains(arguments[0]) && arguments[2] == "--allow-fixture-egress")
    || (arguments.count == 2 && arguments[0] == "agent-fixture-selftest") {
    let deterministic = arguments[0] == "agent-fixture-selftest"
    let anthropic = arguments[0] == "anthropic-fixture"
    let key = ProcessInfo.processInfo.environment[anthropic ? "ANTHROPIC_API_KEY" : "OPENAI_API_KEY"] ?? ""
    let model = ProcessInfo.processInfo.environment[anthropic ? "MILYONUS_ANTHROPIC_MODEL" : "MILYONUS_OPENAI_MODEL"] ?? ""
    if !deterministic {
        guard !key.isEmpty else { throw HarnessError.providerCredentialsRequired }
        guard !model.isEmpty else { throw HarnessError.invalidRequest }
    }
    let client = try StdioHarnessClient(companionExecutable: URL(fileURLWithPath: arguments[1]), diagnostics: deterministic || anthropic)
    do {
        try await client.connect()
        let pending = try await client.openFixtureSession()
        let completion = CompletionCondition(elementIdentifier: "fixture.input", value: "Agent fixture verification " + UUID().uuidString.prefix(8))
        let planner: any ActionPlanner
        if deterministic { planner = SlowFixturePlanner(desired: completion.value) }
        else if anthropic {
            planner = try AnthropicMessagesPlanner(sessionID: pending.id, model: model, completion: completion,
                allowFixtureObservationEgress: true, apiKey: { key })
        } else {
            planner = try OpenAIResponsesPlanner(sessionID: pending.id, model: model, completion: completion,
                allowFixtureObservationEgress: true, apiKey: { key })
        }
        let notice = deterministic
            ? "Approve the fixture session. Deterministic SDK test; 18-second planning delay; no provider request.\n"
            : "Approve the fixture session. Only fixture fields will be sent to \(anthropic ? "Anthropic" : "OpenAI").\n"
        try FileHandle.standardError.write(contentsOf: Data(notice.utf8))
        let approvalStart = ContinuousClock.now
        var ready: Session?
        while approvalStart.duration(to: .now) < .seconds(120) {
            guard let current = try await client.status(), current.id == pending.id,
                  ![.cancelled, .expired].contains(current.state) else { throw HarnessError.cancelled }
            if current.state == .ready { ready = current; break }
            try await Task.sleep(for: .milliseconds(250))
        }
        guard let ready else { throw HarnessError.timeout }
        // Native activation is asynchronous; retries here are read-only.
        for attempt in 0..<20 {
            do { _ = try await client.observe(sessionID: ready.id); break }
            catch HarnessError.focusChanged {
                if attempt == 19 { throw HarnessError.focusChanged }
                try await Task.sleep(for: .milliseconds(100))
            }
        }
        let outcome = try await AgentRunner(client: client).run(
            goal: "Set fixture.input to " + completion.value + ", then finish. No save is needed.",
            session: ready, completion: completion, planner: planner, maximumSteps: 6, timeoutSeconds: 90)
        try await client.cancel(sessionID: ready.id)
        await client.shutdown()
        let result: [String: Any] = ["suite": deterministic ? "deterministic-sdk-agent-fixture" : (anthropic ? "anthropic-agent-fixture" : "openai-agent-fixture"),
            "requestedModel": deterministic ? "none" : model, "realInference": !deterministic,
            "actions": outcome.actions, "completionVerified": true, "fixtureOnly": true,
            "planningDelaySeconds": deterministic ? 18 : 0]
        print(String(decoding: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), as: UTF8.self))
    } catch { await client.shutdown(); throw error }
} else if arguments.count == 2, arguments[0] == "client-check" {
    let client = try StdioHarnessClient(companionExecutable: URL(fileURLWithPath: arguments[1]))
    do {
        try await client.connect()
        let session = try await client.openFixtureSession()
        guard session.state == .awaitingApproval else { throw HarnessError.unauthorized }
        let current = try await client.status()
        guard current?.id == session.id else { throw HarnessError.invalidRequest }
        do {
            _ = try await client.observe(sessionID: session.id)
            throw HarnessError.policyDenied
        } catch HarnessError.unauthorized { }
        try await client.cancel(sessionID: session.id)
        guard try await client.status()?.state == .cancelled else { throw HarnessError.invalidRequest }
        await client.shutdown()
        print("{\"suite\":\"swift-client\",\"passed\":4,\"failed\":0}")
    } catch { await client.shutdown(); throw error }
} else {
    print("Milyonus Computer Use 0.1.0\nUsage: milyonus-cu gesture-fixture-selftest /absolute/companion/executable --allow-native-fixture-input | anthropic-plan-check | doctor | contract-fixtures | capture-fixture | client-check /absolute/companion/executable | agent-fixture-selftest /absolute/companion/executable | agent-fixture /absolute/companion/executable --allow-fixture-egress | anthropic-fixture /absolute/companion/executable --allow-fixture-egress\nLaunch the companion app for native session approval and MCP stdio control.")
    if !arguments.isEmpty { exit(64) }
}

} catch {
    let code = (error as? HarnessError)?.rawValue ?? "INTERNAL_ERROR"
    let data = (try? JSONSerialization.data(withJSONObject: ["error": code])) ?? Data()
    print(String(decoding: data, as: UTF8.self))
    exit(1)
}
