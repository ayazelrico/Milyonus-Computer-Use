import Foundation
import ComputerUseContracts
import ComputerUseCore

enum OwnedReadWorkerFixture {
    static func runIfRequested() throws {
        guard CommandLine.arguments.dropFirst().first == "--owned-read-worker-stall" else { return }
        guard CommandLine.arguments.count == 3 else { exit(64) }
        signal(SIGTERM, SIG_IGN)
        try Data("ready".utf8).write(to: URL(fileURLWithPath: CommandLine.arguments[2]), options: .withoutOverwriting)
        // Fail-safe only. The parent's bounded escalation must terminate us first.
        Thread.sleep(forTimeInterval: 30)
        exit(75)
    }
}

@MainActor
private final class ManualReadWorker: ReadWorkerTransport {
    var ticket: ReadWorkerTicket?
    var callback: (@MainActor @Sendable (Result<ReadWorkerReply, HarnessError>) -> Void)?
    var stops = 0
    var onStop: (() -> Void)?
    func start(_ ticket: ReadWorkerTicket,
               completion: @escaping @MainActor @Sendable (Result<ReadWorkerReply, HarnessError>) -> Void) throws {
        self.ticket = ticket; callback = completion
    }
    func stop() {
        stops += 1
        onStop?()
        // Deliberately deliver an exit callback synchronously during teardown.
        callback?(.failure(.cancelled))
    }
    func deliver(_ ticket: ReadWorkerTicket? = nil, malformed: Bool = false) throws {
        let value = try requireValue(ticket ?? self.ticket)
        var observation = Observation(id: "worker-observation", sessionId: value.sessionID,
                                      bundleId: SessionController.fixtureBundleID, pid: value.target.pid,
                                      capturedAt: Date(), elements: [], truncated: false)
        if malformed { observation.pid = 0 }
        callback?(.success(ReadWorkerReply(ticket: value, observation: observation, elapsed: .milliseconds(1))))
    }
}

/// Process-containment fixture only. It deliberately has no AX or grant access.
@MainActor
private final class StalledReadWorker: ReadWorkerTransport {
    let child: OwnedReadWorkerProcess
    var launch: Task<Void, Never>?
    var stops = 0
    init() throws {
        child = try OwnedReadWorkerProcess(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["30"])
    }
    func start(_ ticket: ReadWorkerTicket,
               completion: @escaping @MainActor @Sendable (Result<ReadWorkerReply, HarnessError>) -> Void) throws {
        launch = Task {
            do { try await child.launch() }
            catch { completion(.failure((error as? HarnessError) ?? .cancelled)) }
        }
    }
    func stop() {
        stops += 1
        launch?.cancel(); launch = nil
        child.stop()
    }
}

@MainActor
final class ReadWorkerTests: TestCase {
    private func session() -> Session {
        Session(id: "worker-session", bundleId: SessionController.fixtureBundleID, generation: 1,
                state: .ready, expiresAt: Date().addingTimeInterval(60))
    }
    private func target() throws -> ReadWorkerTarget {
        try ReadWorkerTarget(pid: 42, startSeconds: 100, startMicroseconds: 20, windowID: 7)
    }
    private func waitUntil(_ predicate: () -> Bool) async throws {
        let limit = ContinuousClock.now.advanced(by: .seconds(2))
        while !predicate() {
            guard ContinuousClock.now < limit else { throw HarnessError.timeout }
            try await Task.sleep(for: .milliseconds(2))
        }
    }

    func testCancellationFencesLateReplyAndReplacement() async throws {
        let first = ManualReadWorker(), second = ManualReadWorker()
        var created = 0
        let controller = ReadWorkerController { created += 1; return created == 1 ? first : second }
        let target = try target(), session = session(), connectionID = UUID()
        let pending = Task { try await controller.read(connectionID: connectionID, session: session, target: target, admission: {}) }
        try await waitUntil { first.ticket != nil }
        do {
            _ = try await controller.read(connectionID: connectionID, session: session, target: target, admission: {})
            fail("Concurrent worker admitted")
        } catch { expectEqual(error as? HarnessError, .leaseBusy) }
        controller.cancel()
        do { _ = try await pending.value; fail("Cancelled read succeeded") }
        catch { expectEqual(error as? HarnessError, .cancelled) }
        expectEqual(first.stops, 1)
        let replacement = Task { try await controller.read(connectionID: connectionID, session: session, target: target, admission: {}) }
        try await waitUntil { second.ticket != nil }
        expectFalse(first.ticket?.incarnation == second.ticket?.incarnation)
        try first.deliver()
        expectEqual(second.stops, 0)
        try second.deliver()
        let result = try await replacement.value
        expectEqual(result.pid, target.pid)
        expectEqual(second.stops, 1)
        try second.deliver()
        expectEqual(second.stops, 1)
    }

    func testWrongIdentityAndMalformedResultAreRejected() async throws {
        for mode in ["incarnation", "request", "connection", "generation", "process", "malformed"] {
            let worker = ManualReadWorker(), controller = ReadWorkerController { worker }
            let target = try target(), session = session()
            let pending = Task { try await controller.read(connectionID: UUID(), session: session, target: target, admission: {}) }
            try await waitUntil { worker.ticket != nil }
            let original = try requireValue(worker.ticket)
            let reply = ReadWorkerTicket(requestID: mode == "request" ? UUID() : original.requestID,
                                         incarnation: mode == "incarnation" ? UUID() : original.incarnation,
                                         connectionID: mode == "connection" ? UUID() : original.connectionID,
                                         sessionID: original.sessionID, generation: mode == "generation" ? 2 : 1,
                                         target: mode == "process" ? try ReadWorkerTarget(pid: 42, startSeconds: 101, startMicroseconds: 20, windowID: 7) : target,
                                         timeout: original.timeout)
            try worker.deliver(reply, malformed: mode == "malformed")
            do { _ = try await pending.value; fail("Mismatched worker result admitted: \(mode)") }
            catch { expectEqual(error as? HarnessError, .protocolMismatch) }
            expectEqual(worker.stops, 1)
        }
    }

    func testAdmissionRevocationAndReentrantCancellation() async throws {
        for mode in ["beforeReply", "afterReply", "afterReplyCancel", "duringDispatch"] {
            let worker = ManualReadWorker(), controller = ReadWorkerController { worker }
            var allowed = true, admissions = 0
            let target = try target(), session = session()
            if mode == "afterReply" { worker.onStop = { allowed = false } }
            if mode == "afterReplyCancel" { worker.onStop = { controller.cancel() } }
            let pending = Task {
                try await controller.read(connectionID: UUID(), session: session, target: target) {
                    admissions += 1
                    if mode == "duringDispatch", admissions == 2 { controller.cancel() }
                    guard allowed else { throw HarnessError.unauthorized }
                }
            }
            if mode != "duringDispatch" {
                try await waitUntil { worker.ticket != nil }
                if mode == "beforeReply" { allowed = false }
                try worker.deliver()
            }
            do { _ = try await pending.value; fail("Revoked read succeeded") }
            catch { expectEqual(error as? HarnessError, mode == "duringDispatch" || mode == "afterReplyCancel" ? .cancelled : .unauthorized) }
            expectEqual(worker.stops, 1)
            if mode == "duringDispatch" { expectEqual(worker.ticket == nil, true) }
        }
    }

    func testTaskCancellationAndDeadlineDrainWorker() async throws {
        for timeout in [false, true] {
            let worker = ManualReadWorker(), controller = ReadWorkerController { worker }
            let target = try target(), session = session()
            let pending = Task {
                try await controller.read(connectionID: UUID(), session: session, target: target,
                                          timeout: timeout ? .milliseconds(60) : .seconds(10), admission: {})
            }
            try await waitUntil { worker.ticket != nil }
            if !timeout { pending.cancel() }
            do { _ = try await pending.value; fail("Expired/cancelled read succeeded") }
            catch { expectEqual(error as? HarnessError, timeout ? .timeout : .cancelled) }
            expectEqual(worker.stops, 1)
            try worker.deliver()
            expectEqual(worker.stops, 1)
        }
    }

    func testInvalidScopeNeverStartsWorker() async throws {
        var created = 0
        let controller = ReadWorkerController { created += 1; return ManualReadWorker() }
        let target = try target()
        for mode in ["bundle", "unapproved", "timeout", "admission"] {
            var session = session()
            if mode == "bundle" { session.bundleId = "other.app" }
            if mode == "unapproved" { session.state = .awaitingApproval }
            do {
                _ = try await controller.read(connectionID: UUID(), session: session, target: target,
                                              timeout: mode == "timeout" ? .seconds(11) : .seconds(10)) {
                    if mode == "admission" { throw HarnessError.unauthorized }
                }
                fail("Invalid read scope admitted")
            } catch {
                expectEqual(error as? HarnessError, mode == "bundle" ? .policyDenied : mode == "timeout" ? .invalidRequest : .unauthorized)
            }
        }
        expectEqual(created, 0)
        expectThrows(try ReadWorkerTarget(pid: 0, startSeconds: 100, startMicroseconds: 0))
        expectThrows(try ReadWorkerTarget(pid: 42, startSeconds: 100, startMicroseconds: 1_000_000))
        expectThrows(try ReadWorkerTarget(pid: 42, startSeconds: 100, startMicroseconds: 0, windowID: 0))
    }

    func testStalledOwnedProcessDoesNotBlockCancellation() async throws {
        // Frozen before execution: local cancellation acknowledgement <250 ms;
        // directly owned child exit <2 s. This is not native companion Stop.
        let worker = try StalledReadWorker(), controller = ReadWorkerController { worker }
        addTeardownBlock { worker.stop() }
        let target = try target(), session = session()
        let pending = Task { try await controller.read(connectionID: UUID(), session: session, target: target, admission: {}) }
        try await waitUntil { if case .running = worker.child.state { return true }; return false }
        let start = ContinuousClock.now
        controller.cancel()
        do { _ = try await pending.value; fail("Stalled child completed a read") }
        catch { expectEqual(error as? HarnessError, .cancelled) }
        expectEqual(start.duration(to: .now) < .milliseconds(250), true)
        try await waitUntil { if case .exited = worker.child.state { return true }; return false }
        expectEqual(worker.stops, 1)
        expectEqual(worker.child.state, .exited(status: SIGTERM, signalled: true))
    }

    func testOwnedProcessEscalatesOnlyItsUncooperativeChild() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let marker = directory.appendingPathComponent("ready")
        let child = try OwnedReadWorkerProcess(executable: URL(fileURLWithPath: CommandLine.arguments[0]),
                                              arguments: ["--owned-read-worker-stall", marker.path],
                                              terminationGrace: .milliseconds(75))
        addTeardownBlock { child.stop() }
        try await child.launch()
        try await waitUntil { FileManager.default.fileExists(atPath: marker.path) }
        guard case .running(let pid) = child.state else { throw HarnessError.protocolMismatch }
        expectEqual(pid > 0, true)
        let start = ContinuousClock.now
        child.stop(); child.stop()
        // Fixed before execution: stop itself <250 ms, final reaped exit <2 s.
        expectEqual(start.duration(to: .now) < .milliseconds(250), true)
        try await waitUntil { if case .exited = child.state { return true }; return false }
        expectEqual(child.state, .exited(status: SIGKILL, signalled: true))
        do { try await child.launch(); fail("Stopped process owner restarted") }
        catch { expectEqual(error as? HarnessError, .cancelled) }
    }

    func testOwnedProcessStopBeforeLaunchAndCancellationAreSticky() async throws {
        let stopped = try OwnedReadWorkerProcess(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["30"])
        stopped.stop()
        do { try await stopped.launch(); fail("Stopped owner launched a child") }
        catch { expectEqual(error as? HarnessError, .cancelled) }
        expectEqual(stopped.state, .idle)
        let child = try OwnedReadWorkerProcess(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["30"])
        addTeardownBlock { child.stop() }
        let launch = Task { try await child.launch() }
        launch.cancel()
        do { try await launch.value; fail("Cancelled launch succeeded") }
        catch { expectEqual(error is CancellationError || (error as? HarnessError) == .cancelled, true) }
        try await waitUntil {
            switch child.state { case .idle, .failed, .exited: return true; default: return false }
        }
        expectThrows(try OwnedReadWorkerProcess(executable: URL(fileURLWithPath: "/not-a-worker")))
        expectThrows(try OwnedReadWorkerProcess(executable: URL(fileURLWithPath: "/bin/sleep"), terminationGrace: .zero))
    }
}
