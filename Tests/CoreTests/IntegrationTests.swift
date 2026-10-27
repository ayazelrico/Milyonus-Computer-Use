import Foundation
import ComputerUseContracts
import ComputerUseClient
import ComputerUseAgent
import ComputerUseIntegration

actor IntegrationGate {
    private var opened = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if opened { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func open() {
        opened = true
        let pending = waiters; waiters.removeAll()
        for waiter in pending { waiter.resume() }
    }
}
actor IntegrationClient: ManagedHarnessClient {
    let entered = IntegrationGate(), release = IntegrationGate()
    let statusEntered = IntegrationGate(), statusRelease = IntegrationGate()
    var gateNextStatus = false
    func holdNextStatus() { gateNextStatus = true }
    let gated: Bool
    var connects = 0, closes = 0, opens = 0
    var session = Session(id: "integration", bundleId: "com.milyonus.computeruse.fixture", generation: 1,
                          state: .awaitingApproval, expiresAt: Date().addingTimeInterval(300))
    init(gated: Bool = false) { self.gated = gated }
    func connect() async throws {
        connects += 1; await entered.open()
        if gated { await release.wait() }
    }
    func shutdown() async { closes += 1 }
    func counts() -> [Int] { [connects, opens, closes] }
    func setState(_ state: SessionState) { session.state = state }
    func openFixtureSession() async throws -> Session { opens += 1; return session }
    func status() async throws -> Session? {
        let snapshot = session
        if gateNextStatus {
            gateNextStatus = false
            await statusEntered.open(); await statusRelease.wait()
        }
        return snapshot
    }
    private var observationSequence = 0
    func observe(sessionID: String) async throws -> Observation {
        observationSequence += 1
        return Observation(id: "observation-\(observationSequence)", sessionId: session.id, bundleId: session.bundleId, pid: 1, capturedAt: Date(),
            elements: [ElementSnapshot(id: "input", role: "AXTextField", identifier: "input", label: nil,
                value: "done", bounds: nil, enabled: true, actions: [.setValue])], truncated: false)
    }
    func act(_ request: ActionRequest) async throws -> ActionResult { throw HarnessError.policyDenied }
    func cancel(sessionID: String) async throws { session.state = .cancelled }
}

actor SuspendedIntegrationPlanner: ActionPlanner {
    let entered = IntegrationGate(), release = IntegrationGate()
    func next(_ context: PlannerContext, deadline: Date) async throws -> PlannerStep {
        await entered.open(); await release.wait()
        return .finish
    }
}

@MainActor
final class IntegrationTests: TestCase {
    func testDisabledFeatureCannotLaunch() async throws {
        let client = IntegrationClient()
        let coordinator = ComputerUseSessionCoordinator(clientFactory: { client }, selectionSuspension: { _ in })
        do { try await coordinator.begin(mode: .computerUse); fail("Disabled integration launched") }
        catch { expectEqual(error as? HarnessError, .policyDenied) }
        let counts = await client.counts(); expectEqual(counts, [0, 0, 0])
    }
    func testExistingModesCannotLaunch() async throws {
        let client = IntegrationClient()
        let coordinator = ComputerUseSessionCoordinator(enabled: true, clientFactory: { client }, selectionSuspension: { _ in })
        for mode: ComputerUseEntryMode in [.plainChat, .code, .ultra] {
            do { try await coordinator.begin(mode: mode); fail("Existing mode launched computer use") }
            catch { expectEqual(error as? HarnessError, .policyDenied) }
        }
        let counts = await client.counts(); expectEqual(counts, [0, 0, 0])
    }
    func testApprovalAndExclusiveOwnership() async throws {
        let client = IntegrationClient(); var suspension: [Bool] = []
        let coordinator = ComputerUseSessionCoordinator(enabled: true, clientFactory: { client }, selectionSuspension: { suspension.append($0) })
        try await coordinator.begin(mode: .computerUse)
        expectEqual(coordinator.view.phase, .awaitingApproval)
        do { try await coordinator.begin(mode: .computerUse); fail("Concurrent session opened") }
        catch { expectEqual(error as? HarnessError, .leaseBusy) }
        do {
            _ = try await coordinator.run(goal: "Confirm", completion: CompletionCondition(elementIdentifier: "input", value: "done"), planner: ScriptedPlanner([.finish]))
            fail("Unapproved run started")
        } catch { expectEqual(error as? HarnessError, .unauthorized) }
        await coordinator.stop(); await coordinator.stop()
        expectEqual(coordinator.view.phase, .stopped)
        expectEqual(suspension, [true, false])
        let counts = await client.counts(); expectEqual(counts, [1, 1, 1])
    }
    func testStopInvalidatesLateConnection() async throws {
        let client = IntegrationClient(gated: true); var suspension: [Bool] = []
        let coordinator = ComputerUseSessionCoordinator(enabled: true, clientFactory: { client }, selectionSuspension: { suspension.append($0) })
        let pending = Task { try await coordinator.begin(mode: .computerUse) }
        await client.entered.wait()
        await coordinator.stop()
        let revision = coordinator.view.revision
        await client.release.open()
        do { try await pending.value; fail("Late connection revived session") }
        catch { expectEqual(error as? HarnessError, .cancelled) }
        expectEqual(coordinator.view.phase, .stopped)
        expectEqual(coordinator.view.revision, revision)
        expectEqual(suspension, [true, false])
        let counts = await client.counts(); expectEqual(counts, [1, 0, 1])
    }
    func testVerifiedCompletionClosesTransport() async throws {
        let client = IntegrationClient(); var suspension: [Bool] = []
        let coordinator = ComputerUseSessionCoordinator(enabled: true, clientFactory: { client }, selectionSuspension: { suspension.append($0) })
        try await coordinator.begin(mode: .computerUse)
        await client.setState(.ready); try await coordinator.refresh()
        expectEqual(coordinator.view.phase, .ready)
        let outcome = try await coordinator.run(goal: "Confirm input", completion: CompletionCondition(elementIdentifier: "input", value: "done"), planner: ScriptedPlanner([.finish]))
        expectEqual(outcome.actions, 0)
        expectEqual(coordinator.view.phase, .completed)
        expectEqual(suspension, [true, false])
        let counts = await client.counts(); expectEqual(counts, [1, 1, 1])
    }
    func testPauseDoesNotResumeAutomatically() async throws {
        let client = IntegrationClient()
        let coordinator = ComputerUseSessionCoordinator(enabled: true, clientFactory: { client }, selectionSuspension: { _ in })
        try await coordinator.begin(mode: .computerUse)
        await client.setState(.paused); try await coordinator.refresh()
        expectEqual(coordinator.view.phase, .paused)
        try await coordinator.refresh(); expectEqual(coordinator.view.phase, .paused)
        await coordinator.stop()
    }
    func testOlderPollCannotOverwriteNewerState() async throws {
        let client = IntegrationClient()
        let coordinator = ComputerUseSessionCoordinator(enabled: true, clientFactory: { client }, selectionSuspension: { _ in })
        try await coordinator.begin(mode: .computerUse)
        await client.holdNextStatus()
        let stale = Task { try await coordinator.refresh() }
        await client.statusEntered.wait()
        await client.setState(.ready); try await coordinator.refresh()
        let revision = coordinator.view.revision
        await client.statusRelease.open(); try await stale.value
        expectEqual(coordinator.view.phase, .ready)
        expectEqual(coordinator.view.revision, revision)
        await coordinator.stop()
    }

    func testStopDuringPlanningCannotBecomeCompleted() async throws {
        let client = IntegrationClient(), planner = SuspendedIntegrationPlanner()
        let coordinator = ComputerUseSessionCoordinator(enabled: true, clientFactory: { client }, selectionSuspension: { _ in })
        try await coordinator.begin(mode: .computerUse)
        await client.setState(.ready); try await coordinator.refresh()
        let pending = Task {
            try await coordinator.run(goal: "Confirm", completion: CompletionCondition(elementIdentifier: "input", value: "done"), planner: planner)
        }
        await planner.entered.wait()
        await coordinator.stop()
        let revision = coordinator.view.revision
        expectEqual(coordinator.view.phase, .stopped)
        await planner.release.open()
        do { _ = try await pending.value; fail("Late planner completion revived stopped run") }
        catch { expectEqual(error as? HarnessError, .cancelled) }
        expectEqual(coordinator.view.phase, .stopped)
        expectEqual(coordinator.view.revision, revision)
        let counts = await client.counts(); expectEqual(counts, [1, 1, 1])
    }

}
