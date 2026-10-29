import Foundation
import ComputerUseContracts
import ComputerUseCore
import ComputerUseMacOS
import ComputerUseWorker

@MainActor
final class FixtureWorkerRuntimeTests: TestCase {
    func testRoleRejectsUntrustedStartupBeforeConnecting() async throws {
        for args in [[], [FixtureWorkerRuntime.role], [FixtureWorkerRuntime.role, "invalid", "0"],
                     [FixtureWorkerRuntime.role, "com.milyonus.worker.test", String(Int32.max)],
                     [FixtureWorkerRuntime.role, "com.milyonus.worker.test", "1", "arbitrary-pin"]] {
            do { try await FixtureWorkerRuntime.run(arguments: args); fail("Invalid worker bootstrap admitted") }
            catch { expectEqual(error as? HarnessError, .unauthorized) }
        }
    }

    /// Standalone subprocess probe only. The target is hardcoded to this non-
    /// fixture process, so synthetic metadata never authorizes an AX tree read.
    static func runProbe() async throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count == 2 else { throw HarnessError.invalidRequest }
        let host = try FixtureWorkerHost(service: args[1])
        defer { host.cancel() }
        let reader = ReadWorkerController { try host.makeTransport() }
        let own = try ReadWorkerProcessIdentity.read(pid: ProcessInfo.processInfo.processIdentifier)
        let metadata = Session(id: "negative-runtime-scope", bundleId: SessionController.fixtureBundleID,
                               generation: 1, state: .ready, expiresAt: Date().addingTimeInterval(60))
        var cases: [[String: Any]] = []
        for mode in ["non-fixture", "changed-start", "explicit-window"] {
            let target = try ReadWorkerTarget(pid: own.pid,
                startSeconds: own.startSeconds + (mode == "changed-start" ? 1 : 0),
                startMicroseconds: own.startMicroseconds, windowID: mode == "explicit-window" ? 7 : nil)
            let expected: HarnessError = mode == "non-fixture" ? .policyDenied : mode == "changed-start" ? .staleObservation : .unsupportedCapability
            var received: HarnessError?
            do {
                _ = try await reader.read(connectionID: UUID(), session: metadata, target: target) {
                    guard try ReadWorkerProcessIdentity.read(pid: own.pid) == own else { throw HarnessError.staleObservation }
                }
            } catch { received = error as? HarnessError }
            guard received == expected else { throw HarnessError.protocolMismatch }
            let limit = ContinuousClock.now.advanced(by: .seconds(2))
            while !host.retired {
                guard ContinuousClock.now < limit else { throw HarnessError.timeout }
                try await Task.sleep(for: .milliseconds(5))
            }
            guard let state = host.processState, case .exited = state else { throw HarnessError.protocolMismatch }
            cases.append(["name": mode, "error": expected.rawValue, "helperExited": true,
                          "exitState": String(describing: state)])
        }
        let result: [String: Any] = ["status": "passed-negative-worker-runtime", "cases": cases,
            "nativeSessionOpened": false, "nativeApprovalCreated": false, "axTreeRead": false,
            "scope": "Only this non-fixture probe process; synthetic correlation metadata"]
        print(String(decoding: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), as: UTF8.self))
    }
}
