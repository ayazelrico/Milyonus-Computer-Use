import Foundation
import ComputerUseContracts
import ComputerUseCore

@MainActor
private final class ManualCaptureWorker: CaptureWorkerTransport {
    var ticket: ReadWorkerTicket?
    var callback: (@MainActor @Sendable (Result<CaptureWorkerReply, HarnessError>) -> Void)?
    var stops = 0
    var onStop: (() -> Void)?
    func start(_ ticket: ReadWorkerTicket,
               completion: @escaping @MainActor @Sendable (Result<CaptureWorkerReply, HarnessError>) -> Void) throws {
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
        let metadata = CaptureWorkerMetadata(windowID: malformed ? 99 : (value.target.windowID ?? 0),
            pixelWidth: 100, pixelHeight: 100, pngBytes: 100,
            sha256: String(repeating: "a", count: 64), bounds: Rect(x: 0, y: 0, width: 100, height: 100),
            capturedAt: Date(), screenRecordingGranted: true)
        callback?(.success(CaptureWorkerReply(ticket: value, metadata: metadata, elapsed: .milliseconds(1))))
    }
}

@MainActor
final class CaptureWorkerControllerTests: TestCase {
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
        let first = ManualCaptureWorker(), second = ManualCaptureWorker()
        var created = 0
        let controller = CaptureWorkerController { created += 1; return created == 1 ? first : second }
        let target = try target(), session = session(), connectionID = UUID()
        let pending = Task { try await controller.capture(connectionID: connectionID, session: session, target: target, admission: {}) }
        try await waitUntil { first.ticket != nil }
        do {
            _ = try await controller.capture(connectionID: connectionID, session: session, target: target, admission: {})
            fail("Concurrent worker admitted")
        } catch { expectEqual(error as? HarnessError, .leaseBusy) }
        controller.cancel()
        do { _ = try await pending.value; fail("Cancelled read succeeded") }
        catch { expectEqual(error as? HarnessError, .cancelled) }
        expectEqual(first.stops, 1)
        let replacement = Task { try await controller.capture(connectionID: connectionID, session: session, target: target, admission: {}) }
        try await waitUntil { second.ticket != nil }
        expectFalse(first.ticket?.incarnation == second.ticket?.incarnation)
        try first.deliver()
        expectEqual(second.stops, 0)
        try second.deliver()
        let result = try await replacement.value
        expectEqual(result.windowID, target.windowID)
        expectEqual(second.stops, 1)
        try second.deliver()
        expectEqual(second.stops, 1)
    }

    func testWrongIdentityAndMalformedResultAreRejected() async throws {
        for mode in ["incarnation", "request", "connection", "generation", "process", "malformed"] {
            let worker = ManualCaptureWorker(), controller = CaptureWorkerController { worker }
            let target = try target(), session = session()
            let pending = Task { try await controller.capture(connectionID: UUID(), session: session, target: target, admission: {}) }
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
            let worker = ManualCaptureWorker(), controller = CaptureWorkerController { worker }
            var allowed = true, admissions = 0
            let target = try target(), session = session()
            if mode == "afterReply" { worker.onStop = { allowed = false } }
            if mode == "afterReplyCancel" { worker.onStop = { controller.cancel() } }
            let pending = Task {
                try await controller.capture(connectionID: UUID(), session: session, target: target) {
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
            let worker = ManualCaptureWorker(), controller = CaptureWorkerController { worker }
            let target = try target(), session = session()
            let pending = Task {
                try await controller.capture(connectionID: UUID(), session: session, target: target,
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
        let controller = CaptureWorkerController { created += 1; return ManualCaptureWorker() }
        let target = try target()
        for mode in ["bundle", "unapproved", "timeout", "admission", "window"] {
            var session = session()
            if mode == "bundle" { session.bundleId = "other.app" }
            if mode == "unapproved" { session.state = .awaitingApproval }
            do {
                _ = try await controller.capture(connectionID: UUID(), session: session, target: mode == "window" ? try ReadWorkerTarget(pid: 42, startSeconds: 100, startMicroseconds: 20) : target,
                                              timeout: mode == "timeout" ? .seconds(11) : .seconds(10)) {
                    if mode == "admission" { throw HarnessError.unauthorized }
                }
                fail("Invalid read scope admitted")
            } catch {
                expectEqual(error as? HarnessError, mode == "bundle" ? .policyDenied : (mode == "timeout" || mode == "window") ? .invalidRequest : .unauthorized)
            }
        }
        expectEqual(created, 0)
        expectThrows(try ReadWorkerTarget(pid: 0, startSeconds: 100, startMicroseconds: 0))
        expectThrows(try ReadWorkerTarget(pid: 42, startSeconds: 100, startMicroseconds: 1_000_000))
        expectThrows(try ReadWorkerTarget(pid: 42, startSeconds: 100, startMicroseconds: 0, windowID: 0))
    }

}
