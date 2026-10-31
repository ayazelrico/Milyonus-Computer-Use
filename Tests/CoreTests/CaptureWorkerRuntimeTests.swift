import Foundation
import ComputerUseContracts
import ComputerUseCore
import ComputerUseMacOS
import ComputerUseWorker
import ComputerUseIPC

/// Real authenticated role probe, always scoped to this non-fixture process.
@MainActor
final class CaptureWorkerRuntimeTests {
    private var ticket: ReadWorkerTicket?
    private var child: OwnedReadWorkerProcess?
    private var result: Result<CaptureWorkerReply, HarnessError>?
    private var connection: UUID?

    private func receive(_ context: BrokerConnectionContext, _ data: Data) -> Data {
        guard context.isConnected, let ticket, result == nil else { return Data() }
        do {
            if connection == nil {
                guard data == FixtureWorkerRuntime.captureNext else { throw HarnessError.protocolMismatch }
                connection = context.id
                return try CaptureWorkerWire.encodeRequest(ticket)
            }
            guard connection == context.id else { throw HarnessError.unauthorized }
            result = try CaptureWorkerWire.decodeReply(data, expected: ticket)
            return Data("accepted".utf8)
        } catch {
            result = .failure((error as? HarnessError) ?? .protocolMismatch)
            return Data()
        }
    }
    static func runProbe() async throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count == 2, let executable = Bundle.main.executableURL else { throw HarnessError.invalidRequest }
        let probe = CaptureWorkerRuntimeTests()
        let own = try ReadWorkerProcessIdentity.read(pid: ProcessInfo.processInfo.processIdentifier)
        var results: [[String: Any]] = []
        for changed in [false, true] {
            let child = try OwnedReadWorkerProcess(executable: executable,
                arguments: [FixtureWorkerRuntime.captureRole, args[1], String(own.pid)])
            probe.child = child; probe.result = nil; probe.connection = nil
            let target = try ReadWorkerTarget(pid: own.pid, startSeconds: own.startSeconds + (changed ? 1 : 0),
                startMicroseconds: own.startMicroseconds, windowID: 7)
            probe.ticket = ReadWorkerTicket(requestID: UUID(), incarnation: UUID(), connectionID: UUID(),
                sessionID: "negative-capture-scope", generation: 1, target: target, timeout: .seconds(10))
            let listener = try BrokerHandshakeListener(serviceName: args[1], peer: FixtureWorkerIdentity.current(),
                ownedPeer: {
                    guard let pid = child.runningProcessIdentifier else { return nil }
                    return BrokerOwnedPeer(pid: pid, isLive: { child.runningProcessIdentifier == pid })
                }, requestHandler: { context, data in await probe.receive(context, data) })
            try listener.start()
            defer { child.stop(); listener.close() }
            try await child.launch()
            let deadline = ContinuousClock.now.advanced(by: .seconds(8))
            while probe.result == nil {
                guard ContinuousClock.now < deadline, !child.isRetired else { throw HarnessError.timeout }
                try await Task.sleep(for: .milliseconds(5))
            }
            let expected: HarnessError = changed ? .staleObservation : .policyDenied
            guard case .failure(let error) = probe.result, error == expected else { throw HarnessError.verificationFailed }
            child.stop(); listener.close()
            let retirement = ContinuousClock.now.advanced(by: .seconds(2))
            while !child.isRetired {
                guard ContinuousClock.now < retirement else { throw HarnessError.timeout }
                try await Task.sleep(for: .milliseconds(5))
            }
            results.append(["name": changed ? "changed-process-start" : "non-fixture", "refusal": expected.rawValue, "helperExited": true])
        }
        print(String(decoding: try JSONSerialization.data(withJSONObject: ["status": "passed-negative-capture-worker-runtime",
            "cases": results, "nativeApprovalCreated": false, "imageCaptured": false, "pixelsTransferred": false], options: [.sortedKeys]), as: UTF8.self))
    }
}
