import Foundation
import ComputerUseContracts
import ComputerUseAgent

private actor CredentialReadCounter {
    var count = 0
    func read() -> String { count += 1; return "synthetic-test-key" }
    func reads() -> Int { count }
}

@MainActor
final class PlannerAdmissionTests: TestCase {
    func testInvalidContextNeverReadsCredentialsOrSends() async throws {
        let base = ProviderTests().context()
        for anthropic in [false, true] {
            for fault in ["duplicate-handle", "duplicate-target", "truncated", "stale", "future", "oversized-text", "step-budget", "infinite-deadline"] {
                var observation = base.observation
                var steps = base.remainingSteps
                var deadline = Date().addingTimeInterval(10)
                switch fault {
                case "duplicate-handle": observation.elements.append(observation.elements[0])
                case "duplicate-target":
                    var duplicate = observation.elements[0]; duplicate.id = "another-handle"
                    observation.elements.append(duplicate)
                case "truncated": observation.truncated = true
                case "stale": observation.capturedAt = Date().addingTimeInterval(-60)
                case "future": observation.capturedAt = Date().addingTimeInterval(60)
                case "oversized-text": observation.elements[0].value = String(repeating: "x", count: 48_000)
                case "step-budget": steps = 101
                default: deadline = Date(timeIntervalSinceReferenceDate: .infinity)
                }
                let context = PlannerContext(goal: base.goal, observation: observation, remainingSteps: steps)
                let credentials = CredentialReadCounter(), transport = StubPlannerTransport(body: Data())
                let completion = CompletionCondition(elementIdentifier: "fixture.input", value: "done")
                let planner: any ActionPlanner
                if anthropic {
                    planner = try AnthropicMessagesPlanner(sessionID: "session", model: "test-model", completion: completion,
                        allowFixtureObservationEgress: true, apiKey: { await credentials.read() }, transport: transport)
                } else {
                    planner = try OpenAIResponsesPlanner(sessionID: "session", model: "test-model", completion: completion,
                        allowFixtureObservationEgress: true, apiKey: { await credentials.read() }, transport: transport)
                }
                do { _ = try await planner.next(context, deadline: deadline); fail("Invalid provider context was admitted") }
                catch {
                    let expected: HarnessError
                    switch fault {
                    case "duplicate-handle", "oversized-text": expected = .protocolMismatch
                    case "duplicate-target": expected = .targetAmbiguous
                    case "step-budget": expected = .resourceLimit
                    case "infinite-deadline": expected = .timeout
                    default: expected = .staleObservation
                    }
                    expectEqual(error as? HarnessError, expected)
                }
                let reads = await credentials.reads(), sends = await transport.count()
                expectEqual(reads, 0); expectEqual(sends, 0)
            }
        }
    }
}
