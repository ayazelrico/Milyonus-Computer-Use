import Foundation
import ComputerUseContracts

@MainActor
public protocol DesktopDriver: AnyObject {
    func observe(session: Session) throws -> Observation
    func preflight(_ request: ActionRequest, session: Session) throws
    func execute(_ request: ActionRequest, session: Session) throws -> ActionResult
    func invalidate()
}

/// One execution claim spans preflight, journal intent, native effects, and verification.
/// Asynchronous native sequences retain the claim while allowing native Stop to run.
@MainActor
public final class ExecutionEngine {
    private let sessions: SessionController
    private let driver: any DesktopDriver
    private let ledger: ActionLedger
    private let maximumActions: Int
    private let onFailure: (HarnessError) -> Void
    private var countedSession: String?
    private var actionCount = 0
    private var executing = false
    public init(sessions: SessionController, driver: any DesktopDriver, ledger: ActionLedger, maximumActions: Int = 100, onFailure: @escaping (HarnessError) -> Void = { _ in }) {
        self.sessions = sessions; self.driver = driver; self.ledger = ledger; self.maximumActions = maximumActions; self.onFailure = onFailure
    }
    public func observe(sessionID: String, admission: () throws -> Void = {}) throws -> Observation {
        try admission()
        guard !executing else { throw HarnessError.leaseBusy }
        let session = try sessions.requireReady(sessionID)
        do {
            try Task.checkCancellation()
            let result = try driver.observe(session: session)
            try admission()
            try Task.checkCancellation()
            // A synchronous platform read may outlast its lease. Do not publish
            // data collected under an expired or replaced session generation.
            _ = try sessions.requireReady(sessionID, generation: session.generation)
            try result.validate()
            guard result.sessionId == session.id, result.bundleId == session.bundleId else {
                throw HarnessError.protocolMismatch
            }
            return result
        } catch {
            driver.invalidate()
            throw error
        }
    }
    private func prepare(_ request: ActionRequest, method: ExecutionMethod = .semantic, admission: () throws -> Void) throws -> (Session, ActionResult?) {
        try admission()
        try request.validate()
        try Task.checkCancellation()
        guard (request.kind == .drag) == (method == .nativeDrag) else { throw HarnessError.unsupportedCapability }
        guard (request.kind == .scroll) == (method == .nativeScroll) else { throw HarnessError.unsupportedCapability }
        guard !executing else { throw HarnessError.leaseBusy }
        let session = try sessions.requireReady(request.sessionId, generation: request.generation)
        if let previous = try ledger.previous(request, method: method) { return (session, previous) }
        if countedSession != session.id { countedSession = session.id; actionCount = 0 }
        guard actionCount < maximumActions else { throw HarnessError.resourceLimit }
        do {
            try driver.preflight(request, session: session)
            try admission()
            try Task.checkCancellation()
            _ = try sessions.requireReady(session.id, generation: session.generation)
        } catch {
            driver.invalidate()
            throw error
        }
        do { try ledger.begin(request, method: method) }
        catch {
            if error as? HarnessError == .persistenceFailed { sessions.pause(reason: .executionUncertain) }
            throw error
        }
        actionCount += 1; executing = true
        return (session, nil)
    }
    private func finish(_ request: ActionRequest, result: ActionResult, method: ExecutionMethod = .semantic, admission: () throws -> Void) throws -> ActionResult {
        driver.invalidate()
        do { try result.validate() }
        catch { sessions.pause(reason: .executionUncertain); throw error }
        var recorded = result
        if recorded.verification == .passed {
            do {
                try admission()
                try Task.checkCancellation()
                _ = try sessions.requireReady(request.sessionId, generation: request.generation)
            } catch {
                // Keep the reported effect: revocation after dispatch cannot prove
                // that an already-applied effect did not happen. Only verification
                // admission is withdrawn; the immutable receipt prevents replay.
                recorded.verification = .unavailable
                recorded.error = error is CancellationError ? .cancelled : (error as? HarnessError ?? .unauthorized)
            }
        }
        do { try ledger.finish(request, result: recorded, method: method) }
        catch { sessions.pause(reason: .executionUncertain); throw error }
        if recorded.effect == .unknown { sessions.pause(reason: .executionUncertain) }
        return recorded
    }
    public func execute(_ request: ActionRequest, admission: () throws -> Void = {}) throws -> ActionResult {
        let (session, previous) = try prepare(request, admission: admission)
        if let previous { return previous }
        defer { executing = false }
        if let refusal = dispatchRefusal(request, session: session, admission: admission) {
            return try finish(request, result: refusal, admission: admission)
        }
        let result: ActionResult
        do { result = try driver.execute(request, session: session) }
        catch { onFailure((error as? HarnessError) ?? .effectUnknown); result = uncertain(request) }
        return try finish(request, result: result, admission: admission)
    }
    public func executeAsync(_ request: ActionRequest, method: ExecutionMethod = .semantic, admission: () throws -> Void = {},
                             operation: @MainActor (Session) async throws -> ActionResult) async throws -> ActionResult {
        let (session, previous) = try prepare(request, method: method, admission: admission)
        if let previous { return previous }
        defer { executing = false }
        if let refusal = dispatchRefusal(request, session: session, admission: admission) {
            return try finish(request, result: refusal, method: method, admission: admission)
        }
        let result: ActionResult
        do { result = try await operation(session) }
        catch { onFailure((error as? HarnessError) ?? .effectUnknown); result = uncertain(request) }
        return try finish(request, result: result, method: method, admission: admission)
    }
    /// Journal persistence can consume the remaining lease. Before entering any
    /// effect-producing callback, refusal is known not to have applied an effect.
    private func dispatchRefusal(_ request: ActionRequest, session: Session, admission: () throws -> Void) -> ActionResult? {
        do {
            try admission()
            try Task.checkCancellation()
            _ = try sessions.requireReady(session.id, generation: session.generation)
            return nil
        } catch {
            let reason = error is CancellationError ? HarnessError.cancelled : (error as? HarnessError ?? .unauthorized)
            return ActionResult(requestId: request.requestId, effect: .notApplied, verification: .unavailable, error: reason)
        }
    }
    private func uncertain(_ request: ActionRequest) -> ActionResult {
        ActionResult(requestId: request.requestId, effect: .unknown, verification: .unavailable, error: .effectUnknown)
    }
}
