import Foundation
import ComputerUseContracts

/// Internal lifecycle values, not an RPC surface or a native grant. The broker
/// must obtain target identity independently and revalidate it in admission.
package struct ReadWorkerTarget: Sendable, Equatable {
    package let pid: Int32
    package let startSeconds: Int64
    package let startMicroseconds: Int32
    package let windowID: UInt32?

    package init(pid: Int32, startSeconds: Int64, startMicroseconds: Int32, windowID: UInt32? = nil) throws {
        guard pid > 0, startSeconds > 0, (0..<1_000_000).contains(startMicroseconds),
              windowID != 0 else { throw HarnessError.invalidRequest }
        self.pid = pid; self.startSeconds = startSeconds
        self.startMicroseconds = startMicroseconds; self.windowID = windowID
    }
}

package struct ReadWorkerTicket: Sendable, Equatable {
    package let requestID: UUID
    package let incarnation: UUID
    package let connectionID: UUID
    package let sessionID: String
    package let generation: Int
    package let target: ReadWorkerTarget
    package let timeout: Duration

    package init(requestID: UUID, incarnation: UUID, connectionID: UUID,
                 sessionID: String, generation: Int, target: ReadWorkerTarget, timeout: Duration) {
        self.requestID = requestID; self.incarnation = incarnation; self.connectionID = connectionID
        self.sessionID = sessionID; self.generation = generation; self.target = target; self.timeout = timeout
    }
}

package struct ReadWorkerReply: Sendable {
    package let ticket: ReadWorkerTicket
    package let observation: Observation
    package let elapsed: Duration

    package init(ticket: ReadWorkerTicket, observation: Observation, elapsed: Duration) {
        self.ticket = ticket; self.observation = observation; self.elapsed = elapsed
    }
}

/// A transport owns exactly one worker incarnation. start/stop must not block
/// the broker actor. stop invalidates callbacks and begins owned-child teardown.
/// Implementations must enforce peer identity and wire bounds separately.
@MainActor
package protocol ReadWorkerTransport: AnyObject {
    func start(_ ticket: ReadWorkerTicket,
               completion: @escaping @MainActor @Sendable (Result<ReadWorkerReply, HarnessError>) -> Void) throws
    func stop()
}

/// Injectable read-only lifecycle, deliberately not connected to the production
/// desktop driver until separate-process authentication and TCC gates pass.
@MainActor
package final class ReadWorkerController {
    private struct Pending {
        let ticket: ReadWorkerTicket
        let deadline: ContinuousClock.Instant
        let transport: any ReadWorkerTransport
        let continuation: CheckedContinuation<Observation, Error>
        let admission: @MainActor () throws -> Void
    }
    private let factory: @MainActor () throws -> any ReadWorkerTransport
    private var pending: Pending?
    private var timer: Task<Void, Never>?
    private var activeReadID: UUID?
    private var cancelled = false

    package init(factory: @escaping @MainActor () throws -> any ReadWorkerTransport) {
        self.factory = factory
    }

    isolated deinit {
        timer?.cancel()
        if let pending {
            pending.transport.stop()
            pending.continuation.resume(throwing: HarnessError.cancelled)
        }
    }

    package func read(connectionID: UUID, session: Session, target: ReadWorkerTarget,
                      timeout: Duration = .seconds(10),
                      admission: @escaping @MainActor () throws -> Void) async throws -> Observation {
        guard activeReadID == nil else { throw HarnessError.leaseBusy }
        try Task.checkCancellation()
        guard timeout > .zero, timeout <= .seconds(10) else { throw HarnessError.invalidRequest }
        try session.validate()
        guard session.bundleId == SessionController.fixtureBundleID else { throw HarnessError.policyDenied }
        guard session.state == .ready else { throw HarnessError.unauthorized }
        let requestID = UUID()
        activeReadID = requestID; cancelled = false
        defer { activeReadID = nil; cancelled = false }
        let deadline = ContinuousClock.now.advanced(by: timeout)
        try admission()
        guard !cancelled else { throw HarnessError.cancelled }
        let transport = try factory()
        let ticket = ReadWorkerTicket(requestID: requestID, incarnation: UUID(), connectionID: connectionID,
                                      sessionID: session.id, generation: session.generation,
                                      target: target, timeout: timeout)
        let observation = try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                pending = Pending(ticket: ticket, deadline: deadline, transport: transport,
                                  continuation: continuation, admission: admission)
                timer = Task { [weak self] in
                    do { try await Task.sleep(until: deadline, clock: .continuous) } catch { return }
                    self?.finish(ticket.requestID, result: .failure(.timeout))
                }
                do {
                    try admission()
                    guard pending?.ticket.requestID == ticket.requestID else { return }
                    guard ContinuousClock.now < deadline else { throw HarnessError.timeout }
                    try transport.start(ticket) { [weak self] result in
                        self?.receive(ticket.requestID, result: result)
                    }
                } catch {
                    finish(ticket.requestID, result: .failure((error as? HarnessError) ?? .cancelled))
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancel(ticket.requestID)
            }
        }
        try Task.checkCancellation()
        guard !cancelled else { throw HarnessError.cancelled }
        try admission()
        try Task.checkCancellation()
        guard !cancelled else { throw HarnessError.cancelled }
        guard ContinuousClock.now < deadline else { throw HarnessError.timeout }
        return observation
    }

    /// Called by broker Stop/disconnect/revocation, never by a worker grant RPC.
    package func cancel() {
        guard let activeReadID else { return }
        cancel(activeReadID)
    }

    private func cancel(_ requestID: UUID) {
        guard activeReadID == requestID else { return }
        cancelled = true
        finish(requestID, result: .failure(.cancelled))
    }

    private func receive(_ requestID: UUID, result: Result<ReadWorkerReply, HarnessError>) {
        guard let pending, pending.ticket.requestID == requestID else { return }
        do {
            guard ContinuousClock.now < pending.deadline else { throw HarnessError.timeout }
            try pending.admission()
            let reply = try result.get()
            guard reply.ticket == pending.ticket, reply.elapsed >= .zero,
                  reply.elapsed < pending.ticket.timeout else { throw HarnessError.protocolMismatch }
            try reply.observation.validate()
            guard reply.observation.sessionId == pending.ticket.sessionID,
                  reply.observation.bundleId == SessionController.fixtureBundleID,
                  reply.observation.pid == pending.ticket.target.pid else { throw HarnessError.protocolMismatch }
            // Values only. No worker-supplied handle is installed in the native
            // target table; later integration must mint broker-owned handles.
            finish(requestID, result: .success(reply.observation))
        } catch {
            finish(requestID, result: .failure((error as? HarnessError) ?? .cancelled))
        }
    }

    private func finish(_ requestID: UUID, result: Result<Observation, HarnessError>) {
        guard let current = pending, current.ticket.requestID == requestID else { return }
        pending = nil
        timer?.cancel(); timer = nil
        // Clear ownership before stop: a transport may synchronously deliver an
        // exit callback. It must not complete this continuation a second time.
        current.transport.stop()
        switch result {
        case .success(let observation): current.continuation.resume(returning: observation)
        case .failure(let error): current.continuation.resume(throwing: error)
        }
    }
}
