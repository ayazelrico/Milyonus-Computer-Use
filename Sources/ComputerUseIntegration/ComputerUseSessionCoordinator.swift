import Foundation
import ComputerUseContracts
import ComputerUseClient
import ComputerUseAgent

public enum ComputerUseEntryMode: Sendable { case plainChat, code, externalAgent, computerUse }
public enum ComputerUsePhase: String, Codable, Sendable {
    case idle, connecting, awaitingApproval, ready, running, paused, stopping, stopped, completed, failed
}
/// Safe UI projection: no credentials, observation text, handles or approval capability.
public struct ComputerUseViewState: Codable, Sendable {
    public var revision: Int = 0
    public var runID: UUID?
    public var phase: ComputerUsePhase = .idle
    public var sessionID: String?
    public var bundleID: String?
    public var generation: Int?
    public var pauseReason: SessionPauseReason?
    public var error: HarnessError?
}

/// Host-only coordinator. Do not expose the factory or feature flag through a WebView message.
@MainActor
public final class ComputerUseSessionCoordinator {
    public private(set) var view = ComputerUseViewState()
    private let enabled: Bool
    private let factory: @Sendable () throws -> any ManagedHarnessClient
    private let selectionSuspension: @MainActor (Bool) -> Void
    private var owner: UUID?
    private var client: (any ManagedHarnessClient)?
    private var session: Session?
    private var runner: AgentRunner?
    private var closing = false

    public init(enabled: Bool = false,
                clientFactory: @escaping @Sendable () throws -> any ManagedHarnessClient,
                selectionSuspension: @escaping @MainActor (Bool) -> Void) {
        self.enabled = enabled; factory = clientFactory; self.selectionSuspension = selectionSuspension
    }
    private func publish(_ phase: ComputerUsePhase, error: HarnessError? = nil) {
        view.revision += 1; view.phase = phase; view.error = error
        view.sessionID = session?.id; view.bundleID = session?.bundleId
        view.generation = session?.generation; view.pauseReason = session?.pauseReason
    }
    private func check(_ id: UUID) throws {
        guard owner == id, !Task.isCancelled else { throw HarnessError.cancelled }
    }
    public func begin(mode: ComputerUseEntryMode) async throws {
        guard enabled, mode == .computerUse else { throw HarnessError.policyDenied }
        guard owner == nil, !closing else { throw HarnessError.leaseBusy }
        let id = UUID(); owner = id; view.runID = id; session = nil
        selectionSuspension(true); publish(.connecting)
        do {
            let connection = try factory(); client = connection
            try await connection.connect()
            try check(id)
            let opened = try await connection.openFixtureSession()
            try check(id)
            guard opened.bundleId == "com.milyonus.computeruse.fixture", opened.state == .awaitingApproval else {
                throw HarnessError.protocolMismatch
            }
            session = opened; publish(.awaitingApproval)
        } catch {
            if owner == id { await close(id, phase: .failed, error: error as? HarnessError ?? .protocolMismatch) }
            throw error
        }
    }
    /// Call from the native host's bounded status timer; polling never grants approval.
    public func refresh() async throws {
        guard let id = owner, let client, let session else { throw HarnessError.unauthorized }
        let observedRevision = view.revision
        do {
            let updated = try await client.status()
            try check(id)
            // A newer poll or run transition wins over an older in-flight reply.
            guard view.revision == observedRevision else { return }
            guard let updated, updated.id == session.id, updated.bundleId == session.bundleId,
                  updated.generation >= session.generation else { throw HarnessError.protocolMismatch }
            self.session = updated
            switch updated.state {
            case .awaitingApproval: publish(.awaitingApproval)
            case .ready: publish(runner == nil ? .ready : .running)
            case .paused: publish(.paused)
            case .cancelled, .expired: await close(id, phase: .stopped)
            }
        } catch {
            if owner == id { await close(id, phase: .failed, error: error as? HarnessError ?? .protocolMismatch) }
            throw error
        }
    }
    public func run(goal: String, completion: CompletionCondition, planner: any ActionPlanner) async throws -> AgentOutcome {
        guard let id = owner, let client, let session, view.phase == .ready, runner == nil else {
            throw HarnessError.unauthorized
        }
        let execution = AgentRunner(client: client); runner = execution; publish(.running)
        do {
            let outcome = try await execution.run(goal: goal, session: session, completion: completion, planner: planner)
            try check(id)
            await close(id, phase: .completed)
            return outcome
        } catch {
            if owner == id { await close(id, phase: .failed, error: error as? HarnessError ?? .protocolMismatch) }
            throw error
        }
    }
    public func stop() async {
        guard let id = owner else { return }
        await close(id, phase: .stopped)
    }
    private func close(_ id: UUID, phase: ComputerUsePhase, error: HarnessError? = nil) async {
        guard owner == id else { return }
        owner = nil; closing = true
        let connection = client, execution = runner
        client = nil; runner = nil; publish(.stopping)
        // Kill the dedicated transport before awaiting planner cancellation.
        await connection?.shutdown()
        await execution?.cancel()
        session = nil; closing = false
        selectionSuspension(false); publish(phase, error: error)
    }
}
