import Foundation
import ComputerUseIPC
import ComputerUseCore

private actor InvocationCount {
    private var value = 0
    func increment() { value += 1 }
    func count() -> Int { value }
}

@main struct OwnedWorkerPeer {
    @MainActor static func wait(_ condition: () -> Bool) async throws {
        let limit = ContinuousClock.now.advanced(by: .seconds(8))
        while !condition() {
            guard ContinuousClock.now < limit else { throw BrokerConnectionError.timeout }
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    @MainActor static func client(_ args: [String]) async throws {
        guard args.count == 7, let expectedPID = Int32(args[3]), expectedPID > 0 else { exit(64) }
        if args[4] != "immediate" { try await wait { FileManager.default.fileExists(atPath: args[5]) } }
        let channel = AuthenticatedBrokerConnection()
        defer { channel.close() }
        var result: [String: Any] = ["authenticatedBeforeRequest": false, "metadataVerified": false]
        do {
            try await channel.connect(serviceName: args[1], peer: .developmentCDHash(args[2]),
                                      expectedProcessIdentifier: expectedPID, timeoutSeconds: 2)
            result["authenticatedBeforeRequest"] = channel.isAuthenticated
            let response = try await channel.request(Data("read-metadata".utf8), timeoutSeconds: 2)
            result["metadataVerified"] = response == Data("bounded-fixture-metadata".utf8)
            result["outcome"] = "authenticated"
        } catch {
            result["outcome"] = (error as? BrokerConnectionError).map { String(describing: $0) } ?? "unexpected"
        }
        try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
            .write(to: URL(fileURLWithPath: args[6]), options: .withoutOverwriting)
    }

    @MainActor static func server(_ args: [String]) async throws {
        guard args.count == 5 else { exit(64) }
        let service = args[1], pin = args[2], mode = args[3]
        let folder = URL(fileURLWithPath: args[4], isDirectory: true)
        let gate = folder.appendingPathComponent("primary-ready")
        let report = folder.appendingPathComponent("primary-result.json")
        let parentPID = ProcessInfo.processInfo.processIdentifier
        let executable = URL(fileURLWithPath: CommandLine.arguments[0])
        let slot = ReadWorkerProcessSlot { try OwnedReadWorkerProcess(executable: executable, arguments: [
            "--client", service, mode == "wrong-server-signature" ? String(repeating: "0", count: 40) : pin,
            String(mode == "wrong-server-pid" ? Int32.max : parentPID), "gated", gate.path, report.path
        ]) }
        let child = try slot.acquire()
        defer { slot.cancel() }
        let calls = InvocationCount()
        let listener = try BrokerHandshakeListener(serviceName: service,
            peer: .developmentCDHash(mode == "wrong-client-signature" ? String(repeating: "0", count: 40) : pin),
            ownedProcessIdentifier: { child.runningProcessIdentifier },
            requestHandler: { context, data in
                guard context.isConnected, data == Data("read-metadata".utf8) else { return Data() }
                await calls.increment()
                return Data("bounded-fixture-metadata".utf8)
            })
        try listener.start()
        defer { listener.close() }
        try await child.launch()
        var siblingRefused = false
        if mode == "same-signature-sibling" {
            let siblingReport = folder.appendingPathComponent("sibling-result.json")
            let sibling = try OwnedReadWorkerProcess(executable: executable, arguments: [
                "--client", service, pin, String(parentPID), "immediate", gate.path, siblingReport.path
            ])
            defer { sibling.stop() }
            try await sibling.launch()
            try await wait {
                if case .exited = sibling.state { return FileManager.default.fileExists(atPath: siblingReport.path) }
                return false
            }
            let result = try JSONSerialization.jsonObject(with: Data(contentsOf: siblingReport)) as? [String: Any]
            siblingRefused = result?["outcome"] as? String == "authenticationFailed"
                && result?["authenticatedBeforeRequest"] as? Bool == false
                && result?["metadataVerified"] as? Bool == false
        }
        try Data("ready".utf8).write(to: gate, options: .withoutOverwriting)
        try await wait {
            if case .exited = child.state { return FileManager.default.fileExists(atPath: report.path) }
            return false
        }
        var result = try JSONSerialization.jsonObject(with: Data(contentsOf: report)) as? [String: Any] ?? [:]
        result["postHandshakeInvocations"] = await calls.count()
        result["siblingRefused"] = siblingRefused
        result["ownedChildExited"] = child.state == .exited(status: 0, signalled: false)
        result["ownerAdmissionRetired"] = child.runningProcessIdentifier == nil
        print(String(decoding: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), as: UTF8.self))
    }

    static func main() async {
        do {
            let args = Array(CommandLine.arguments.dropFirst())
            if args.first == "--server" { try await server(args) }
            else if args.first == "--client" { try await client(args) }
            else { exit(64) }
        } catch {
            print("{\"probeError\":\"bounded-worker-peer-failure\"}")
            exit(1)
        }
    }
}
