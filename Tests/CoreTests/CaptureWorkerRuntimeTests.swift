import Foundation
import ComputerUseContracts
import ComputerUseCore
import ComputerUseMacOS
import ComputerUseWorker
import ComputerUseIPC

/// Real authenticated role probe, always scoped to this non-fixture process.
@MainActor
final class CaptureWorkerRuntimeTests {
    static func runProbe() async throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count == 2 else { throw HarnessError.invalidRequest }
        let own = try ReadWorkerProcessIdentity.read(pid: ProcessInfo.processInfo.processIdentifier)
        var results: [[String: Any]] = []
        for changed in [false, true] {
            let host = try FixtureCaptureWorkerHost(service: args[1])
            defer { host.cancel() }
            let controller = CaptureWorkerController { try host.makeTransport() }
            let target = try ReadWorkerTarget(pid: own.pid, startSeconds: own.startSeconds + (changed ? 1 : 0),
                startMicroseconds: own.startMicroseconds, windowID: 7)
            // Synthetic session metadata only. This target is always our own
            // non-fixture process; no native grant or positive capture occurs.
            let session = Session(id: "negative-capture-scope", bundleId: SessionController.fixtureBundleID,
                generation: 1, state: .ready, expiresAt: Date().addingTimeInterval(30))
            var refusal: HarnessError?
            do {
                _ = try await controller.capture(connectionID: UUID(), session: session, target: target,
                    timeout: .seconds(8), admission: {})
            } catch { refusal = error as? HarnessError }
            let expected: HarnessError = changed ? .staleObservation : .policyDenied
            guard refusal == expected else { throw HarnessError.verificationFailed }
            host.cancel()
            let retirement = ContinuousClock.now.advanced(by: .seconds(2))
            while !host.retired {
                guard ContinuousClock.now < retirement else { throw HarnessError.timeout }
                try await Task.sleep(for: .milliseconds(5))
            }
            results.append(["name": changed ? "changed-process-start" : "non-fixture", "refusal": expected.rawValue, "helperExited": true])
        }
        print(String(decoding: try JSONSerialization.data(withJSONObject: ["status": "passed-negative-capture-worker-runtime",
            "cases": results, "nativeApprovalCreated": false, "imageCaptured": false, "pixelsTransferred": false], options: [.sortedKeys]), as: UTF8.self))
    }
}
