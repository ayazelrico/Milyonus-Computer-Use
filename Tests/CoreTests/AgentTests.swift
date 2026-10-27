import Foundation
import ComputerUseContracts
import ComputerUseClient
import ComputerUseAgent

actor FakeHarnessClient: HarnessClient {
    private var session = Session(id: "session", bundleId: "fixture", generation: 1, state: .ready, expiresAt: Date().addingTimeInterval(300))
    private var value = "initial"
    private var actions = 0
    private var reads = 0
    private var unknown = false
    private var unavailableVerification = false
    private var revokeOnFreshRead = false
    func setUnavailableVerification() { unavailableVerification = true }
    func setRevokeOnFreshRead() { revokeOnFreshRead = true }
    private var fault: String?
    func setFault(_ value: String) { fault = value }
    private var wrongScope = false
    func setWrongScope() { wrongScope = true }
    func setUnknown() { unknown = true }
    func count() -> Int { actions }
    func openFixtureSession() async throws -> Session { session }
    func status() async throws -> Session? {
        var result = session
        if fault == "bad-session" { result.pauseReason = .heartbeatLost }
        if fault == "wrong-status-scope" { result.bundleId = "unrelated" }
        return result
    }
    func observe(sessionID: String) async throws -> Observation {
        guard session.state == .ready else { throw HarnessError.unauthorized }
        reads += 1
        if revokeOnFreshRead && reads == 2 { session.generation += 1 }
        let element = ElementSnapshot(id: "element-\(reads)", role: "AXTextField", identifier: "input", label: nil,
            value: value, bounds: Rect(x: 0, y: 0, width: 100, height: 30), enabled: true, actions: [.setValue])
        var result = Observation(id: "obs-\(reads)", sessionId: session.id, bundleId: wrongScope ? "other-app" : session.bundleId, pid: 1,
                           capturedAt: Date(), elements: [element], truncated: false)
        if fault == "duplicate" { result.elements.append(element) }
        if fault == "truncated" || (fault == "fresh-truncated" && reads == 2) { result.truncated = true }
        if fault == "stale" { result.capturedAt = Date().addingTimeInterval(-60) }
        if fault == "future" { result.capturedAt = Date().addingTimeInterval(60) }
        if fault == "reused-id" { result.id = "obs-1" }
        return result
    }
    func act(_ request: ActionRequest) async throws -> ActionResult {
        guard request.observationId == "obs-\(reads)", request.elementId == "element-\(reads)" else { throw HarnessError.staleObservation }
        actions += 1; value = request.text ?? value
        if fault == "bad-result" {
            return ActionResult(requestId: request.requestId, actionId: "", effect: .applied, verification: .passed)
        }
        return ActionResult(requestId: request.requestId, effect: unknown ? .unknown : .applied, verification: unknown || unavailableVerification ? .unavailable : .passed)
    }
    func cancel(sessionID: String) async throws { session.state = .cancelled }
}
actor ScriptedPlanner: ActionPlanner {
    var steps: [PlannerStep]
    private var calls = 0
    func callCount() -> Int { calls }
    init(_ steps: [PlannerStep]) { self.steps = steps }
    func next(_ context: PlannerContext, deadline: Date) async throws -> PlannerStep {
        calls += 1
        guard !steps.isEmpty else { throw HarnessError.invalidRequest }
        return steps.removeFirst()
    }
}
@MainActor
final class AgentTests: TestCase {
    func testInvalidAdapterDataNeverReachesPlanner() async throws {
        for fault in ["duplicate", "truncated", "stale", "future", "bad-session", "wrong-status-scope"] {
            let client = FakeHarnessClient(); await client.setFault(fault)
            let runner = AgentRunner(client: client), session = try await client.openFixtureSession()
            let planner = ScriptedPlanner([.finish])
            do {
                _ = try await runner.run(goal: "Read input", session: session,
                    completion: CompletionCondition(elementIdentifier: "input", value: "initial"), planner: planner)
                fail("Invalid adapter data was admitted")
            } catch {
                let expected: HarnessError = ["duplicate", "bad-session"].contains(fault) ? .protocolMismatch
                    : fault == "wrong-status-scope" ? .unauthorized : .staleObservation
                expectEqual(error as? HarnessError, expected)
            }
            let calls = await planner.callCount(), actions = await client.count()
            expectEqual(calls, 0); expectEqual(actions, 0)
            let state = try await client.status()?.state
            expectEqual(state, .cancelled)
        }
    }
    func testFreshObservationCannotBeTruncatedOrReused() async throws {
        for fault in ["fresh-truncated", "reused-id"] {
            for finish in [false, true] {
                let client = FakeHarnessClient(); await client.setFault(fault)
                let runner = AgentRunner(client: client), session = try await client.openFixtureSession()
                let planner = ScriptedPlanner([finish ? .finish : .action(PlannedAction(elementIdentifier: "input", kind: .setValue, text: "done"))])
                do {
                    _ = try await runner.run(goal: "Read input", session: session,
                        completion: CompletionCondition(elementIdentifier: "input", value: "initial"), planner: planner)
                    fail("Invalid fresh observation admitted")
                } catch { expectEqual(error as? HarnessError, .staleObservation) }
                let calls = await planner.callCount(), actions = await client.count()
                expectEqual(calls, 1); expectEqual(actions, 0)
            }
        }
    }
    func testMalformedCustomAdapterResultStopsWithoutRetry() async throws {
        let client = FakeHarnessClient(); await client.setFault("bad-result")
        let runner = AgentRunner(client: client), session = try await client.openFixtureSession()
        let planner = ScriptedPlanner([.action(PlannedAction(elementIdentifier: "input", kind: .setValue, text: "done")), .finish])
        do {
            _ = try await runner.run(goal: "Set input", session: session,
                completion: CompletionCondition(elementIdentifier: "input", value: "done"), planner: planner)
            fail("Malformed adapter result admitted")
        } catch { expectEqual(error as? HarnessError, .protocolMismatch) }
        let calls = await planner.callCount(), actions = await client.count()
        expectEqual(calls, 1); expectEqual(actions, 1)
        let state = try await client.status()?.state
        expectEqual(state, .cancelled)
    }
    func testPlannerActionUsesFreshHandlesAndHostCompletion() async throws {
        let client = FakeHarnessClient()
        let actualRunner = AgentRunner(client: client)
        let session = try await client.openFixtureSession()
        let planner = ScriptedPlanner([.action(PlannedAction(elementIdentifier: "input", kind: .setValue, text: "done")), .finish])
        let outcome = try await actualRunner.run(goal: "Set the input to done", session: session,
            completion: CompletionCondition(elementIdentifier: "input", value: "done"), planner: planner)
        expectEqual(outcome.actions, 1)
        let count = await client.count(); expectEqual(count, 1)
    }
    func testFalsePlannerCompletionFailsIndependentVerification() async throws {
        let client = FakeHarnessClient(), planner = ScriptedPlanner([.finish])
        let runner = AgentRunner(client: client), session = try await client.openFixtureSession()
        do {
            _ = try await runner.run(goal: "Set input", session: session,
                completion: CompletionCondition(elementIdentifier: "input", value: "done"), planner: planner)
            fail("False completion was accepted")
        } catch { expectEqual(error as? HarnessError, .verificationFailed) }
        let state = try await client.status()?.state; expectEqual(state, .cancelled)
        let count = await client.count(); expectEqual(count, 0)
    }
    func testUnknownEffectNeverRetries() async throws {
        let client = FakeHarnessClient(); await client.setUnknown()
        let runner = AgentRunner(client: client), session = try await client.openFixtureSession()
        let planner = ScriptedPlanner([.action(PlannedAction(elementIdentifier: "input", kind: .setValue, text: "done")), .finish])
        do {
            _ = try await runner.run(goal: "Set input", session: session,
                completion: CompletionCondition(elementIdentifier: "input", value: "done"), planner: planner)
            fail("Unknown effect was accepted")
        } catch { expectEqual(error as? HarnessError, .effectUnknown) }
        let count = await client.count(); expectEqual(count, 1)
    }
    func testNoProgressStopsRepeatedNoOpActions() async throws {
        let client = FakeHarnessClient()
        // Use the same transport for orchestration and test observations.
        let actualRunner = AgentRunner(client: client), session = try await client.openFixtureSession()
        let action = PlannerStep.action(PlannedAction(elementIdentifier: "input", kind: .setValue, text: "initial"))
        let planner = ScriptedPlanner(Array(repeating: action, count: 10))
        do {
            _ = try await actualRunner.run(goal: "Change input", session: session,
                completion: CompletionCondition(elementIdentifier: "input", value: "done"), planner: planner)
            fail("No-progress loop was accepted")
        } catch { expectEqual(error as? HarnessError, .noProgress) }
        let count = await client.count(); expectEqual(count, 3)
        let state = try await client.status()?.state; expectEqual(state, .cancelled)
    }
    func testObservationScopeMismatchNeverReachesPlanner() async throws {
        let client = FakeHarnessClient(); await client.setWrongScope()
        let runner = AgentRunner(client: client), session = try await client.openFixtureSession()
        do {
            _ = try await runner.run(goal: "Change input", session: session,
                completion: CompletionCondition(elementIdentifier: "input", value: "done"), planner: ScriptedPlanner([]))
            fail("Wrong app observation was accepted")
        } catch { expectEqual(error as? HarnessError, .staleObservation) }
        let count = await client.count(); expectEqual(count, 0)
    }
    func testStepBudgetCancelsSession() async throws {
        let client = FakeHarnessClient()
        let actualRunner = AgentRunner(client: client), session = try await client.openFixtureSession()
        let planner = ScriptedPlanner([.action(PlannedAction(elementIdentifier: "input", kind: .setValue, text: "done"))])
        do {
            _ = try await actualRunner.run(goal: "Set input", session: session,
                completion: CompletionCondition(elementIdentifier: "input", value: "done"), planner: planner, maximumSteps: 1)
            fail("Step budget was not enforced")
        } catch { expectEqual(error as? HarnessError, .resourceLimit) }
        let state = try await client.status()?.state; expectEqual(state, .cancelled)
    }
    func testUnavailableVerificationStopsWithoutRetry() async throws {
        let client = FakeHarnessClient(); await client.setUnavailableVerification()
        let runner = AgentRunner(client: client), session = try await client.openFixtureSession()
        let planner = ScriptedPlanner([.action(PlannedAction(elementIdentifier: "input", kind: .setValue, text: "done")), .finish])
        do {
            _ = try await runner.run(goal: "Set input", session: session,
                completion: CompletionCondition(elementIdentifier: "input", value: "done"), planner: planner)
            fail("Unverified effect was accepted")
        } catch { expectEqual(error as? HarnessError, .verificationFailed) }
        let count = await client.count(); expectEqual(count, 1)
        let state = try await client.status()?.state; expectEqual(state, .cancelled)
    }
    func testGenerationChangeBeforeFinishIsRejected() async throws {
        let client = FakeHarnessClient(); await client.setRevokeOnFreshRead()
        let runner = AgentRunner(client: client), session = try await client.openFixtureSession()
        do {
            _ = try await runner.run(goal: "Confirm input", session: session,
                completion: CompletionCondition(elementIdentifier: "input", value: "initial"), planner: ScriptedPlanner([.finish]))
            fail("Completion crossed a revoked generation")
        } catch { expectEqual(error as? HarnessError, .unauthorized) }
        let count = await client.count(); expectEqual(count, 0)
        let state = try await client.status()?.state; expectEqual(state, .cancelled)
    }

}
