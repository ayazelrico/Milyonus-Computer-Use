import Foundation
import ComputerUseContracts
import ComputerUseClient
import ComputerUseIPC

@main struct IsolatedReadClient {
    @MainActor static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count == 5, let fixturePID = Int32(args[2]) else { exit(64) }
        let client: XPCSessionClient
        do { client = XPCSessionClient(serviceName: args[0], peer: try .developmentCDHash(args[1]), allowFixtureObservation: true) }
        catch { exit(64) }
        var report: [String: Any] = ["status": "failed", "desktopActions": 0, "nativeApprovalCreatedByRPC": false]
        var stage = "connect"
        func mark(_ value: String) throws {
            stage = value
            var progress: [String: Any] = ["stage": value]
            if let granted = report["brokerAccessibilityGranted"] { progress["brokerAccessibilityGranted"] = granted }
            try JSONSerialization.data(withJSONObject: progress, options: [.sortedKeys])
                .write(to: URL(fileURLWithPath: args[4]), options: .atomic)
        }
        do {
            try mark("connect")
            try await client.connect()
            let policyChannel = AuthenticatedBrokerConnection()
            try await policyChannel.connect(serviceName: args[0], peer: .developmentCDHash(args[1]))
            let forbiddenRoute = try await policyChannel.request(JSONSerialization.data(withJSONObject:
                ["name": "desktop_action", "arguments": [:] as [String: String]]))
            policyChannel.close()
            guard let refusedRoute = try JSONSerialization.jsonObject(with: forbiddenRoute) as? [String: Any],
                  refusedRoute["error"] as? String == "UNSUPPORTED_CAPABILITY" else { throw HarnessError.protocolMismatch }
            report["serverMutationRouteRejected"] = true
            try mark("capabilities")
            let capabilities = try await client.capabilities()
            report["brokerAccessibilityGranted"] = capabilities.permissions["accessibility"] ?? false
            guard capabilities.supportedActions.isEmpty, !capabilities.nativeTextInput,
                  !capabilities.nativeElementClick, !capabilities.experimentalNativeFixtureDrag,
                  !capabilities.experimentalNativeFixtureScroll, capabilities.requiresNativeApproval else {
                throw HarnessError.protocolMismatch
            }
            try mark("open-session")
            let pending = try await client.openFixtureSession()
            guard pending.state == .awaitingApproval else { throw HarnessError.protocolMismatch }
            try mark("unapproved-read")
            do { _ = try await client.observe(sessionID: pending.id); throw HarnessError.verificationFailed }
            catch {
                guard let refusal = error as? HarnessError, [.unauthorized, .permissionRequired].contains(refusal) else { throw error }
                report["unapprovedReadRefusal"] = refusal.rawValue
            }
            let forbidden = ActionRequest(requestId: "forbidden", sessionId: pending.id, idempotencyKey: "forbidden",
                observationId: "not-a-native-target", generation: pending.generation, elementId: "not-a-native-target", kind: .press)
            do { _ = try await client.act(forbidden); throw HarnessError.verificationFailed }
            catch { guard error as? HarnessError == .unsupportedCapability else { throw error } }
            report["actionsRejected"] = true
            if args[3] == "approval" {
                try mark("awaiting-native-approval")
                let deadline = ContinuousClock.now.advanced(by: .seconds(120))
                var ready: Session?
                while ContinuousClock.now < deadline {
                    let status = try await client.status()
                    if status?.state == .ready { ready = status; break }
                    guard status?.state == .awaitingApproval else { throw HarnessError.userInterrupted }
                    try await Task.sleep(for: .milliseconds(200))
                }
                guard let ready else { throw HarnessError.timeout }
                try mark("worker-observations")
                var ids = Set<String>()
                for _ in 0..<3 {
                    let settle = ContinuousClock.now.advanced(by: .seconds(3))
                    var captured: Observation?
                    while ContinuousClock.now < settle {
                        do { captured = try await client.observe(sessionID: ready.id); break }
                        catch {
                            guard let error = error as? HarnessError,
                                  [.leaseBusy, .focusChanged, .targetNotFound, .targetAmbiguous].contains(error) else { throw error }
                            try await Task.sleep(for: .milliseconds(30))
                        }
                    }
                    guard let observation = captured, observation.pid == fixturePID, !observation.truncated,
                          observation.elements.contains(where: { $0.identifier == "fixture.input" }),
                          observation.elements.allSatisfy({ $0.identifier != "fixture.secure"
                              && $0.value?.contains("synthetic-secret-never-export") != true }),
                          ids.insert(observation.id).inserted,
                          (0...3).contains(Date().timeIntervalSince(observation.capturedAt)) else { throw HarnessError.verificationFailed }
                    let status = try await client.status()
                    guard status?.state == .ready, status?.generation == ready.generation else { throw HarnessError.userInterrupted }
                }
                report["verifiedObservations"] = ids.count
                report["secureFieldExcluded"] = true
            } else {
                guard args[3] == "unapproved" else { throw HarnessError.invalidRequest }
                let status = try await client.status()
                guard status?.state == .awaitingApproval else { throw HarnessError.protocolMismatch }
            }
            try mark("cancel-session")
            try await client.cancel(sessionID: pending.id)
            do { _ = try await client.observe(sessionID: pending.id); throw HarnessError.verificationFailed }
            catch { guard error as? HarnessError == .unauthorized else { throw error } }
            report["sessionCancelled"] = true
            report["status"] = args[3] == "approval" ? "passed-isolated-read" : "passed-unapproved-isolated-read"
            try mark("complete")
        } catch {
            report["stage"] = stage
            report["error"] = (error as? HarnessError)?.rawValue ?? String(describing: type(of: error))
        }
        await client.shutdown()
        print(String(decoding: (try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])) ?? Data("{}".utf8), as: UTF8.self))
        exit((report["status"] as? String)?.hasPrefix("passed") == true ? 0 : 1)
    }
}
