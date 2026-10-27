import Foundation
import ComputerUseContracts
import ComputerUseClient

public struct CompletionCondition: Sendable {
    public let elementIdentifier: String
    public let value: String
    /// The host supplies this condition before inference. The planner cannot redefine success.
    public init(elementIdentifier: String, value: String) {
        self.elementIdentifier = elementIdentifier; self.value = value
    }
}
public struct PlannedAction: Codable, Sendable {
    public let elementIdentifier: String
    public let kind: ActionKind
    public let text: String?
    public init(elementIdentifier: String, kind: ActionKind, text: String? = nil) {
        self.elementIdentifier = elementIdentifier; self.kind = kind; self.text = text
    }
}
public enum PlannerStep: Sendable { case action(PlannedAction), finish }
public struct PlannerContext: Sendable {
    public let goal: String
    public let observation: Observation
    public let lastResult: ActionResult?
    public let remainingSteps: Int
    public init(goal: String, observation: Observation, lastResult: ActionResult? = nil, remainingSteps: Int) {
        self.goal = goal; self.observation = observation; self.lastResult = lastResult; self.remainingSteps = remainingSteps
    }
}
public protocol ActionPlanner: Sendable {
    /// Implementations must enforce the supplied deadline on their inference transport.
    /// Observation text is untrusted data and must not become system instructions.
    func next(_ context: PlannerContext, deadline: Date) async throws -> PlannerStep
}
public struct AgentOutcome: Sendable {
    public let actions: Int
    public let finalObservation: Observation
}

/// Provider-independent orchestration. Native authorization always remains in the companion.
/// No provider credentials, automatic fallback, or automatic mutation retry lives here.
public actor AgentRunner {
    private let client: any HarnessClient
    private var activeRun: UUID?
    private var sessionID: String?
    public init(client: any HarnessClient) { self.client = client }
    public func cancel() async {
        activeRun = nil
        let cancelledSessionID = sessionID
        sessionID = nil
        if let cancelledSessionID { try? await client.cancel(sessionID: cancelledSessionID) }
    }
    private func check(_ run: UUID, start: ContinuousClock.Instant, budget: Duration) throws {
        guard activeRun == run, !Task.isCancelled else { throw HarnessError.cancelled }
        guard start.duration(to: .now) < budget else { throw HarnessError.timeout }
    }
    private func unique(_ identifier: String, in observation: Observation) throws -> ElementSnapshot {
        let matches = observation.elements.filter { $0.identifier == identifier }
        guard !matches.isEmpty else { throw HarnessError.targetNotFound }
        guard matches.count == 1 else { throw HarnessError.targetAmbiguous }
        return matches[0]
    }
    private func validate(_ observation: Observation, session: Session, pid: Int32?) throws {
        try observation.validate()
        let age = Date().timeIntervalSince(observation.capturedAt)
        guard !observation.truncated, age >= -1, age < 10,
              observation.sessionId == session.id, observation.bundleId == session.bundleId,
              observation.pid > 0, pid == nil || pid == observation.pid else { throw HarnessError.staleObservation }
    }
    private func visibleState(_ observation: Observation) -> [ElementSnapshot] {
        observation.elements.map { element in
            var value = element; value.id = "ephemeral"
            return value
        }
    }
    public func run(goal: String, session: Session, completion: CompletionCondition, planner: any ActionPlanner,
                    maximumSteps: Int = 20, timeoutSeconds: Int = 120, maximumNoProgressActions: Int = 3) async throws -> AgentOutcome {
        guard activeRun == nil else { throw HarnessError.leaseBusy }
        guard !goal.isEmpty, goal.utf8.count <= 16_384, (1...100).contains(maximumSteps),
              (1...300).contains(timeoutSeconds), (1...20).contains(maximumNoProgressActions) else { throw HarnessError.invalidRequest }
        try session.validate()
        guard session.state == .ready else { throw HarnessError.unauthorized }
        let run = UUID(); activeRun = run; sessionID = session.id
        let start = ContinuousClock.now, budget = Duration.seconds(timeoutSeconds)
        let deadline = Date().addingTimeInterval(Double(timeoutSeconds))
        var lastResult: ActionResult?
        var actions = 0
        var previousState: [ElementSnapshot]?
        var unchangedActions = 0
        var observedPID: Int32?
        defer { if activeRun == run { activeRun = nil; sessionID = nil } }
        do {
            for stepIndex in 0..<maximumSteps {
                try check(run, start: start, budget: budget)
                guard let current = try await client.status(), current.id == session.id,
                      current.bundleId == session.bundleId, current.state == .ready,
                      current.generation == session.generation else { throw HarnessError.unauthorized }
                try current.validate()
                let observation = try await client.observe(sessionID: session.id)
                try validate(observation, session: session, pid: observedPID)
                observedPID = observation.pid
                let state = visibleState(observation)
                if let previousState {
                    unchangedActions = state == previousState ? unchangedActions + 1 : 0
                    guard unchangedActions < maximumNoProgressActions else { throw HarnessError.noProgress }
                }
                try check(run, start: start, budget: budget)
                let proposal = try await planner.next(PlannerContext(goal: goal, observation: observation,
                    lastResult: lastResult, remainingSteps: maximumSteps - stepIndex), deadline: deadline)
                try check(run, start: start, budget: budget)
                // Model latency must not cause use of an old AX handle or coordinate frame.
                let fresh = try await client.observe(sessionID: session.id)
                try check(run, start: start, budget: budget)
                try validate(fresh, session: session, pid: observedPID)
                guard fresh.id != observation.id else { throw HarnessError.staleObservation }
                guard let authorized = try await client.status(), authorized.id == session.id,
                      authorized.bundleId == session.bundleId, authorized.state == .ready,
                      authorized.generation == session.generation else { throw HarnessError.unauthorized }
                try authorized.validate()
                try check(run, start: start, budget: budget)
                // Status lookup may itself consume the snapshot's freshness window.
                try validate(fresh, session: session, pid: observedPID)
                switch proposal {
                case .finish:
                    let target = try unique(completion.elementIdentifier, in: fresh)
                    guard target.value == completion.value else { throw HarnessError.verificationFailed }
                    return AgentOutcome(actions: actions, finalObservation: fresh)
                case .action(let planned):
                    let prior = try unique(planned.elementIdentifier, in: observation)
                    let target = try unique(planned.elementIdentifier, in: fresh)
                    guard prior.role == target.role, prior.bounds == target.bounds,
                          prior.value == target.value, target.enabled,
                          target.actions.contains(planned.kind) else { throw HarnessError.staleObservation }
                    let request = ActionRequest(requestId: UUID().uuidString, sessionId: session.id,
                        idempotencyKey: UUID().uuidString, observationId: fresh.id, generation: session.generation,
                        elementId: target.id, kind: planned.kind, text: planned.text)
                    try request.validate()
                    try check(run, start: start, budget: budget)
                    let result = try await client.act(request)
                    try check(run, start: start, budget: budget)
                    try result.validate()
                    guard result.requestId == request.requestId else { throw HarnessError.protocolMismatch }
                    actions += 1; lastResult = result
                    previousState = visibleState(fresh)
                    guard result.effect != .unknown else { throw HarnessError.effectUnknown }
                    guard result.error == nil, result.effect == .applied else { throw result.error ?? HarnessError.verificationFailed }
                    guard result.verification == .passed else { throw HarnessError.verificationFailed }
                }
            }
            throw HarnessError.resourceLimit
        } catch {
            if activeRun == run {
                activeRun = nil; sessionID = nil
                try? await client.cancel(sessionID: session.id)
            }
            throw error
        }
    }
}
