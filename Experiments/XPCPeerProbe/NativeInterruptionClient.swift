import Foundation
import ComputerUseContracts
import ComputerUseClient
import ComputerUseIPC
import ComputerUseAcceptance

@main struct NativeInterruptionClient {
    @MainActor private static var activeClient: XPCSessionClient?
    @MainActor static func main() async {
        do { try await run() }
        catch {
            let code = (error as? HarnessError)?.rawValue ?? (error as? BrokerConnectionError).map { String(describing: $0) } ?? "INTERNAL_ERROR"
            let session = try? await activeClient?.status()
            let data = try! JSONSerialization.data(withJSONObject: ["status": "failed", "error": code,
                "sessionState": session?.state.rawValue ?? "unavailable", "pauseReason": session?.pauseReason?.rawValue ?? "none"])
            try? FileHandle.standardError.write(contentsOf: data + Data([10])); exit(1)
        }
    }
    private static func stage(_ value: String) {
        try? FileHandle.standardError.write(contentsOf: Data(("STAGE " + value + "\n").utf8))
    }
    private struct Trace: Decodable { let event: String; let uptime: Double }
    private static func trace(_ path: String) throws -> [Trace] {
        guard let data = FileManager.default.contents(atPath: path) else { return [] }
        guard data.count <= 16_384 else { throw HarnessError.resourceLimit }
        let lines = data.split(separator: 10)
        let complete = data.last == 10 ? lines : Array(lines.dropLast())
        let events = try complete.map { try JSONDecoder().decode(Trace.self, from: Data($0)) }
        guard events.count <= 64, events.allSatisfy({ ["down", "drag", "up"].contains($0.event) && $0.uptime.isFinite }) else {
            throw HarnessError.protocolMismatch
        }
        return events
    }
    @MainActor private static func observe(_ client: XPCSessionClient, session: Session) async throws -> Observation {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while true {
            do {
                let result = try await client.observe(sessionID: session.id)
                guard !result.truncated else { throw HarnessError.staleObservation }
                return result
            } catch let error as HarnessError {
                guard [.focusChanged, .targetAmbiguous, .targetNotFound].contains(error), ContinuousClock.now < deadline else { throw error }
                stage("initial-observation-refusal-" + error.rawValue)
                try await Task.sleep(for: .milliseconds(50))
            }
        }
    }
    @MainActor private static func run() async throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count == 4, ["baseline", "stop", "disconnect"].contains(args[2]) else { exit(64) }
        let client = XPCSessionClient(serviceName: args[0], peer: try .developmentCDHash(args[1]),
                                     allowFixtureActions: true, allowNativeFixtureInput: true)
        activeClient = client
        stage("connect")
        try await client.connect()
        let capabilities = try await client.capabilities()
        guard capabilities.permissions["accessibility"] == true else { throw HarnessError.permissionRequired }
        stage("open")
        let opened = try await client.openFixtureSession()
        let deadline = ContinuousClock.now.advanced(by: .seconds(120))
        var ready: Session?
        while ContinuousClock.now < deadline {
            if let status = try await client.status(), status.state == .ready { ready = status; break }
            try await Task.sleep(for: .milliseconds(100))
        }
        stage("approval-observed")
        guard let session = ready else { throw HarnessError.timeout }
        _ = try await observe(client, session: session)
        var baselineActions = 0
        if args[2] == "baseline" {
            let first = try await observe(client, session: session)
            guard let input = first.elements.first(where: { $0.identifier == "fixture.input" }) else { throw HarnessError.targetNotFound }
            let text = "Native XPC fixture " + UUID().uuidString.prefix(8)
            let write = ActionRequest(requestId: UUID().uuidString, sessionId: opened.id, idempotencyKey: UUID().uuidString,
                observationId: first.id, generation: session.generation, elementId: input.id, kind: .setValue, text: text)
            stage("native-text")
            let written = try await client.typeText(write)
            guard written.effect == .applied, written.verification == .passed else { throw HarnessError.verificationFailed }
            let second = try await observe(client, session: session)
            guard second.elements.first(where: { $0.identifier == "fixture.input" })?.value == text,
                  let save = second.elements.first(where: { $0.identifier == "fixture.save" }) else { throw HarnessError.verificationFailed }
            let click = ActionRequest(requestId: UUID().uuidString, sessionId: opened.id, idempotencyKey: UUID().uuidString,
                observationId: second.id, generation: session.generation, elementId: save.id, kind: .press)
            stage("native-click")
            let clicked = try await client.click(click)
            guard clicked.effect == .applied, clicked.verification == .passed else { throw HarnessError.verificationFailed }
            stage("scroll-drag-baseline")
            let gestures = try await GestureAcceptanceRunner(client: client).run(session: session)
            guard gestures.independentVerification, gestures.actions == 2 else { throw HarnessError.verificationFailed }
            baselineActions = 4
            try await client.cancel(sessionID: session.id)
            await client.shutdown()
            print("{\"status\":\"passed\",\"mode\":\"baseline\",\"baselineActions\":4,\"independentVerification\":true,\"nativeApprovalGranted\":true}")
            return
        }
        stage("capture-interruption-target")
        let before = try await observe(client, session: session)
        guard let canvas = before.elements.first(where: { $0.identifier == "fixture.drag.canvas" }) else { throw HarnessError.targetNotFound }
        let initial = try trace(args[3])
        let initialDown = initial.filter { $0.event == "down" }.count
        let initialDrag = initial.filter { $0.event == "drag" }.count
        let initialUp = initial.filter { $0.event == "up" }.count
        let request = ActionRequest(requestId: UUID().uuidString, sessionId: session.id, idempotencyKey: UUID().uuidString,
            observationId: before.id, generation: session.generation, elementId: canvas.id, kind: .drag)
        stage("start-interrupted-drag")
        let action = Task { try await client.drag(request) }
        let deliveryDeadline = ContinuousClock.now.advanced(by: .seconds(2))
        var delivered = false
        while ContinuousClock.now < deliveryDeadline {
            let events = try trace(args[3])
            if events.filter({ $0.event == "down" }).count > initialDown && events.filter({ $0.event == "drag" }).count > initialDrag {
                delivered = true; break
            }
            try await Task.sleep(for: .milliseconds(2))
        }
        stage("receiver-motion-check")
        guard delivered else { await client.shutdown(); throw HarnessError.verificationFailed }
        if args[2] == "stop" { try await client.cancel(sessionID: session.id) }
        else { await client.shutdown() }
        var refused = false
        do { _ = try await action.value }
        catch { refused = true }
        let cleanupDeadline = ContinuousClock.now.advanced(by: .seconds(2))
        while ContinuousClock.now < cleanupDeadline {
            if try trace(args[3]).filter({ $0.event == "up" }).count > initialUp { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        let after = try trace(args[3])
        let motion = after.filter { $0.event == "drag" }.count - initialDrag
        let released = after.filter { $0.event == "up" }.count - initialUp
        guard refused, motion > 0, motion < 20, released == 1 else { throw HarnessError.verificationFailed }
        await client.shutdown()
        let report: [String: Any] = ["status": "passed", "mode": args[2], "baselineActions": baselineActions,
            "nativeApprovalGranted": true, "receiverSawMouseDownAndMotion": true,
            "interruptedMotionCount": motion, "partialNativeEffectObserved": true, "receiverSawCleanupMouseUp": true, "pendingActionRefused": refused]
        print(String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), as: UTF8.self))
    }
}
