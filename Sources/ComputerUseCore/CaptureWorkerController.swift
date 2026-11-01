import Foundation
import ComputerUseContracts

/// A transport owns exactly one worker incarnation. start/stop must not block
/// the broker actor. stop invalidates callbacks and begins owned-child teardown.
/// Implementations must enforce peer identity and wire bounds separately.
@MainActor
package protocol CaptureWorkerTransport: AnyObject {
    func start(_ ticket: ReadWorkerTicket,
               completion: @escaping @MainActor @Sendable (Result<CaptureWorkerReply, HarnessError>) -> Void) throws
    func stop()
}

/// Metadata-only lifecycle. The caller owns native approval and must revalidate
/// session, permission, foreground and exact target through admission. No pixels
/// or worker handles become action authority.
@MainActor
package final class CaptureWorkerController {
    private struct Pending {
        let ticket: ReadWorkerTicket
        let deadline: ContinuousClock.Instant
        let transport: any CaptureWorkerTransport
        let continuation: CheckedContinuation<CaptureWorkerMetadata, Error>
        let admission: @MainActor () throws -> Void
    }
    private let factory: @MainActor () throws -> any CaptureWorkerTransport
    private var pending: Pending?
    private var timer: Task<Void, Never>?
    private var activeReadID: UUID?
    private var cancelled = false

    package init(factory: @escaping @MainActor () throws -> any CaptureWorkerTransport) {
        self.factory = factory
    }

    isolated deinit {
        timer?.cancel()
        if let pending {
            pending.transport.stop()
            pending.continuation.resume(throwing: HarnessError.cancelled)
        }
    }

    package func capture(connectionID: UUID, session: Session, target: ReadWorkerTarget,
                      timeout: Duration = .seconds(10),
                      admission: @escaping @MainActor () throws -> Void) async throws -> CaptureWorkerMetadata {
        guard activeReadID == nil else { throw HarnessError.leaseBusy }
        try Task.checkCancellation()
        guard target.windowID != nil, timeout > .zero, timeout <= .seconds(10) else { throw HarnessError.invalidRequest }
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
        let metadata = try await withTaskCancellationHandler {
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
        return metadata
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

    private func receive(_ requestID: UUID, result: Result<CaptureWorkerReply, HarnessError>) {
        guard let pending, pending.ticket.requestID == requestID else { return }
        do {
            guard ContinuousClock.now < pending.deadline else { throw HarnessError.timeout }
            try pending.admission()
            let reply = try result.get()
            guard reply.ticket == pending.ticket, reply.elapsed >= .zero,
                  reply.elapsed < pending.ticket.timeout else { throw HarnessError.protocolMismatch }
            try reply.metadata.validate(target: pending.ticket.target)
            finish(requestID, result: .success(reply.metadata))
        } catch {
            finish(requestID, result: .failure((error as? HarnessError) ?? .cancelled))
        }
    }

    private func finish(_ requestID: UUID, result: Result<CaptureWorkerMetadata, HarnessError>) {
        guard let current = pending, current.ticket.requestID == requestID else { return }
        pending = nil
        timer?.cancel(); timer = nil
        // Clear ownership before stop: a transport may synchronously deliver an
        // exit callback. It must not complete this continuation a second time.
        current.transport.stop()
        switch result {
        case .success(let metadata): current.continuation.resume(returning: metadata)
        case .failure(let error): current.continuation.resume(throwing: error)
        }
    }
}
