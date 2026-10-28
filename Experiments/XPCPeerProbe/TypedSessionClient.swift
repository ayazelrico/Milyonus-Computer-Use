import Foundation
import ComputerUseContracts
import ComputerUseClient
import ComputerUseIPC

@main struct TypedSessionClient {
    @MainActor static func main() async {
        do { try await run() }
        catch {
            let code = (error as? HarnessError)?.rawValue ?? (error as? BrokerConnectionError).map { String(describing: $0) } ?? "INTERNAL_ERROR"
            let report = ["status": "failed", "error": code]
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]) {
                try? FileHandle.standardError.write(contentsOf: data + Data([10]))
            }
            exit(1)
        }
    }
    @MainActor private static func run() async throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count == 2 || (args.count == 3 && ["approval", "fixture", "revoke"].contains(args[2])) else { exit(64) }
        let client = XPCSessionClient(serviceName: args[0], peer: try .developmentCDHash(args[1]), allowFixtureActions: args.count == 3 && ["fixture", "revoke"].contains(args[2]))
        try await client.connect()
        let capabilities = try await client.capabilities()
        let session = try await client.openFixtureSession()
        if args.count == 3 {
            guard capabilities.permissions["accessibility"] == true else { throw HarnessError.permissionRequired }
            try FileHandle.standardError.write(contentsOf: Data("Awaiting manual native session approval in companion.\n".utf8))
            let deadline = ContinuousClock.now.advanced(by: .seconds(120))
            var approved: Session?
            while ContinuousClock.now < deadline {
                if let current = try await client.status(), current.state == .ready { approved = current; break }
                try await Task.sleep(for: .milliseconds(250))
            }
            guard let approved else { throw HarnessError.timeout }
            let heartbeat = try await client.heartbeat(sessionID: approved.id, generation: approved.generation)
            guard heartbeat.state == .ready else { throw HarnessError.protocolMismatch }
            if args[2] == "fixture" {
                // Simulate model planning beyond the server's 15-second liveness lease.
                try await Task.sleep(for: .seconds(18))
                let afterPlanning = try await client.status()
                let diagnostic = "AFTER_PLANNING state=" + (afterPlanning?.state.rawValue ?? "none")
                    + " pauseReason=" + (afterPlanning?.pauseReason?.rawValue ?? "none") + "\n"
                try FileHandle.standardError.write(contentsOf: Data(diagnostic.utf8))
                guard afterPlanning?.state == .ready else { throw HarnessError.timeout }
            }
            if ["fixture", "revoke"].contains(args[2]) {
                // Approval requests foreground activation asynchronously; observe may safely retry focus refusal.
                let focusDeadline = ContinuousClock.now.advanced(by: .seconds(3))
                var observation: Observation?
                while ContinuousClock.now < focusDeadline {
                    do { observation = try await client.observe(sessionID: approved.id); break }
                    catch HarnessError.focusChanged { try await Task.sleep(for: .milliseconds(100)) }
                }
                guard let before = observation, !before.truncated,
                      let target = before.elements.first(where: { $0.identifier == "fixture.input" }),
                      target.enabled, target.actions.contains(.setValue) else { throw HarnessError.targetNotFound }
                let value = "XPC fixture acceptance " + UUID().uuidString.prefix(8)
                let request = ActionRequest(requestId: UUID().uuidString, sessionId: approved.id,
                    idempotencyKey: UUID().uuidString, observationId: before.id, generation: approved.generation,
                    elementId: target.id, kind: .setValue, text: value)
                if args[2] == "revoke" {
                    try FileHandle.standardError.write(contentsOf: Data("READY_FOR_PERMISSION_REVOCATION\n".utf8))
                    let deadline = ContinuousClock.now.advanced(by: .seconds(90))
                    var revoked = false
                    while ContinuousClock.now < deadline {
                        if try await client.capabilities().permissions["accessibility"] == false { revoked = true; break }
                        try await Task.sleep(for: .milliseconds(250))
                    }
                    guard revoked else { throw HarnessError.timeout }
                    let state = try await client.status()
                    let refusal: HarnessError
                    do { _ = try await client.act(request); throw BrokerConnectionError.requestFailed }
                    catch let error as HarnessError { refusal = error }
                    guard [.unauthorized, .permissionRequired, .staleObservation, .focusChanged].contains(refusal) else {
                        throw BrokerConnectionError.protocolMismatch
                    }
                    try await client.cancel(sessionID: approved.id)
                    await client.shutdown()
                    let report: [String: Any] = ["status": "passed", "typedSDK": true,
                        "nativeApprovalGranted": true, "permissionRevoked": true, "desktopActions": 0,
                        "actionRefusal": refusal.rawValue, "stateAfterRevocation": state?.state.rawValue ?? "none",
                        "pauseReason": state?.pauseReason?.rawValue ?? "none", "cancelled": true]
                    print(String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), as: UTF8.self))
                    return
                }
                let result = try await client.act(request)
                guard result.effect == .applied, result.verification == .passed else { throw HarnessError.verificationFailed }
                let after = try await client.observe(sessionID: approved.id)
                guard after.id != before.id, !after.truncated,
                      after.elements.first(where: { $0.identifier == "fixture.input" })?.value == value else { throw HarnessError.verificationFailed }
                try await client.cancel(sessionID: approved.id)
                await client.shutdown()
                print("{\"status\":\"passed\",\"typedSDK\":true,\"nativeApprovalGranted\":true,\"heartbeatVerified\":true,\"planningDelaySeconds\":18,\"automaticHeartbeatVerified\":true,\"desktopActions\":1,\"independentPostcondition\":true,\"cancelled\":true}")
                return
            }
            // Close an actually approved connection. A new connection must start awaitingApproval.
            await client.shutdown()
            try await Task.sleep(for: .milliseconds(500))
            try await client.connect()
            let next = try await client.openFixtureSession()
            guard next.state == .awaitingApproval, next.id != approved.id else { throw HarnessError.protocolMismatch }
            try await client.cancel(sessionID: next.id)
            await client.shutdown()
            print("{\"status\":\"passed\",\"typedSDK\":true,\"nativeApprovalGranted\":true,\"heartbeatVerified\":true,\"newSessionAfterDisconnect\":true,\"desktopActions\":0}")
            return
        }
        guard session.state == .awaitingApproval else { throw HarnessError.protocolMismatch }
        guard try await client.status()?.id == session.id else { throw HarnessError.protocolMismatch }
        do { _ = try await client.openFixtureSession(); throw HarnessError.protocolMismatch }
        catch HarnessError.leaseBusy {}
        do { _ = try await client.observe(sessionID: session.id); throw HarnessError.protocolMismatch }
        catch HarnessError.unsupportedCapability {}
        try await client.cancel(sessionID: session.id)
        let pending = try await client.openFixtureSession()
        await client.shutdown()
        try await Task.sleep(for: .milliseconds(500))
        try await client.connect()
        let next = try await client.openFixtureSession()
        guard next.state == .awaitingApproval, next.id != pending.id else { throw HarnessError.protocolMismatch }
        try await client.cancel(sessionID: next.id)
        await client.shutdown()
        let report: [String: Any] = ["status": "passed", "typedSDK": true,
            "nativeApprovalGranted": false, "desktopActions": 0, "newSessionAfterDisconnect": true,
            "accessibilityGranted": capabilities.permissions["accessibility"] ?? false,
            "screenRecordingGranted": capabilities.permissions["screenRecording"] ?? false]
        print(String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), as: UTF8.self))
    }
}
