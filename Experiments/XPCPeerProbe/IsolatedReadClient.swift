import Foundation
import Darwin
import ComputerUseContracts
import ComputerUseClient
import ComputerUseIPC

@main struct IsolatedReadClient {
    private struct AXEvent: Decodable {
        let event: String
        let uptime: Double
        let pid: Int32
    }
    private static func events(_ path: String, pid: Int32) throws -> [AXEvent] {
        let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 4097) ?? Data()
        guard data.count <= 4096 else { throw HarnessError.resourceLimit }
        var lines = data.split(separator: 10)
        if data.last != 10, !lines.isEmpty { lines.removeLast() }
        let result = try lines.map { try JSONDecoder().decode(AXEvent.self, from: Data($0)) }
        guard result.count <= 4, result.allSatisfy({ $0.pid == pid && $0.uptime.isFinite && $0.uptime > 0
            && ["ready", "armed", "ax-read-enter", "ax-read-return"].contains($0.event) }) else { throw HarnessError.protocolMismatch }
        return result
    }
    private static func ownedStart(_ pid: Int32) throws -> [UInt64] {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard pid > 0, proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size,
              info.pbi_pid == UInt32(pid), info.pbi_ppid == UInt32(getppid()) else { throw HarnessError.unauthorized }
        return [info.pbi_start_tvsec, info.pbi_start_tvusec]
    }
    private struct ChildIdentity {
        let pid: Int32
        let seconds: UInt64
        let microseconds: UInt64
    }
    private static func executablePath(_ pid: Int32) throws -> String {
        var buffer = [UInt8](repeating: 0, count: 4096)
        guard proc_pidpath(pid, &buffer, 4096) > 0,
              let path = String(bytes: buffer.prefix(while: { $0 != 0 }), encoding: .utf8) else { throw HarnessError.targetNotFound }
        return path
    }
    private static func workerChild(of parent: Int32) throws -> ChildIdentity {
        let path = try executablePath(parent)
        guard URL(fileURLWithPath: path).lastPathComponent == "MilyonusComputerUse" else { throw HarnessError.unauthorized }
        var pids = [Int32](repeating: 0, count: 32)
        let count = proc_listchildpids(parent, &pids, Int32(32 * MemoryLayout<Int32>.size))
        guard count >= 0, count < 32 else { throw HarnessError.resourceLimit }
        var found: [ChildIdentity] = []
        for pid in pids.prefix(Int(count)) where pid > 0 {
            var info = proc_bsdinfo()
            let size = Int32(MemoryLayout<proc_bsdinfo>.size)
            guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size,
                  info.pbi_ppid == UInt32(parent), (try? executablePath(pid)) == path else { continue }
            found.append(ChildIdentity(pid: pid, seconds: info.pbi_start_tvsec, microseconds: info.pbi_start_tvusec))
        }
        guard found.count == 1, let child = found.first else { throw HarnessError.verificationFailed }
        return child
    }
    private static func originalChildAlive(_ child: ChildIdentity) throws -> Bool {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        if proc_pidinfo(child.pid, PROC_PIDTBSDINFO, 0, &info, size) == size {
            return info.pbi_start_tvsec == child.seconds && info.pbi_start_tvusec == child.microseconds
        }
        guard kill(child.pid, 0) != 0, errno == ESRCH else { throw HarnessError.verificationFailed }
        return false
    }

    @MainActor static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count == 6 || args.count == 7, let fixturePID = Int32(args[2]),
              let brokerPID = Int32(args[5]), brokerPID > 0 else { exit(64) }
        let client: XPCSessionClient
        do { client = XPCSessionClient(serviceName: args[0], peer: try .developmentCDHash(args[1]), allowFixtureObservation: true) }
        catch { exit(64) }
        var report: [String: Any] = ["status": "failed", "desktopActions": 0, "nativeApprovalCreatedByRPC": false]
        var stage = "connect"
        var alreadyCancelled = false
        func mark(_ value: String) throws {
            stage = value
            var progress: [String: Any] = ["stage": value]
            if let granted = report["brokerAccessibilityGranted"] { progress["brokerAccessibilityGranted"] = granted }
            try JSONSerialization.data(withJSONObject: progress, options: [.sortedKeys])
                .write(to: URL(fileURLWithPath: args[4]), options: .atomic)
        }
        do {
            let initialStart = args[3] == "stall-stop" ? try ownedStart(fixturePID) : nil
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
            if args[3] == "approval" || args[3] == "stall-stop" {
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
                if args[3] == "stall-stop" {
                    guard args.count == 7, try ownedStart(fixturePID) == initialStart else { throw HarnessError.unauthorized }
                    try mark("arming-ax-stall")
                    guard kill(fixturePID, SIGUSR1) == 0 else { throw HarnessError.targetNotFound }
                    let armDeadline = ContinuousClock.now.advanced(by: .seconds(2))
                    while !(try events(args[6], pid: fixturePID)).contains(where: { $0.event == "armed" }) {
                        guard ContinuousClock.now < armDeadline else { throw HarnessError.timeout }
                        try await Task.sleep(for: .milliseconds(2))
                    }
                    var readFinished = false
                    let blockedRead = Task { @MainActor in
                        defer { readFinished = true }
                        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
                        while true {
                            do { return try await client.observe(sessionID: ready.id) }
                            catch {
                                guard error as? HarnessError == .leaseBusy, ContinuousClock.now < deadline else { throw error }
                                try await Task.sleep(for: .milliseconds(2))
                            }
                        }
                    }
                    defer { blockedRead.cancel() }
                    let enterDeadline = ContinuousClock.now.advanced(by: .seconds(2))
                    var entered: AXEvent?
                    while entered == nil {
                        entered = try events(args[6], pid: fixturePID).first(where: { $0.event == "ax-read-enter" })
                        guard !readFinished, ContinuousClock.now < enterDeadline else { throw HarnessError.verificationFailed }
                        if entered == nil { try await Task.sleep(for: .milliseconds(2)) }
                    }
                    guard let entered, !readFinished else { throw HarnessError.verificationFailed }
                    let blockedChild = try workerChild(of: brokerPID)
                    try mark("stop-during-ax-stall")
                    let stopUptime = ProcessInfo.processInfo.systemUptime
                    let start = ContinuousClock.now
                    try await client.cancel(sessionID: ready.id)
                    alreadyCancelled = true
                    let latency = start.duration(to: .now)
                    let after = try events(args[6], pid: fixturePID)
                    report["stopAcknowledgedMs"] = Double(latency.components.seconds) * 1000 + Double(latency.components.attoseconds) / 1e15
                    report["axReadEnteredUptime"] = entered.uptime
                    report["stopRequestedUptime"] = stopUptime
                    report["stopAcknowledgedUptime"] = ProcessInfo.processInfo.systemUptime
                    report["axReturnedAtAcknowledgement"] = after.contains(where: { $0.event == "ax-read-return" })
                    try mark("verify-stop-latency")
                    guard latency < .milliseconds(250), entered.uptime <= stopUptime,
                          ProcessInfo.processInfo.systemUptime < entered.uptime + 5,
                          !after.contains(where: { $0.event == "ax-read-return" }) else { throw HarnessError.verificationFailed }
                    try mark("verify-pending-read-cancelled")
                    do { _ = try await blockedRead.value; throw HarnessError.verificationFailed }
                    catch { guard error as? HarnessError == .cancelled else { throw error } }
                    try mark("verify-worker-exit")
                    let exitDeadline = ContinuousClock.now.advanced(by: .seconds(2))
                    while try originalChildAlive(blockedChild) {
                        guard ContinuousClock.now < exitDeadline else { throw HarnessError.timeout }
                        try await Task.sleep(for: .milliseconds(5))
                    }
                    report["stopWhileAXBlocked"] = true
                    report["pendingReadRefused"] = true
                    report["axReadEnteredBeforeStop"] = true
                    report["blockedWorkerPID"] = blockedChild.pid
                    report["blockedWorkerExitedBeforeBrokerUnload"] = true
                    report["stopAcknowledgedMs"] = Double(latency.components.seconds) * 1000 + Double(latency.components.attoseconds) / 1e15
                }
            } else {
                guard args[3] == "unapproved" else { throw HarnessError.invalidRequest }
                let status = try await client.status()
                guard status?.state == .awaitingApproval else { throw HarnessError.protocolMismatch }
            }
            try mark("cancel-session")
            if !alreadyCancelled { try await client.cancel(sessionID: pending.id) }
            do { _ = try await client.observe(sessionID: pending.id); throw HarnessError.verificationFailed }
            catch { guard error as? HarnessError == .unauthorized else { throw error } }
            report["sessionCancelled"] = true
            report["status"] = args[3] == "stall-stop" ? "passed-isolated-ax-stop" : args[3] == "approval" ? "passed-isolated-read" : "passed-unapproved-isolated-read"
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
