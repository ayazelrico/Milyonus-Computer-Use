import Foundation
import ComputerUseContracts

/// Shared admission before fixture observation egress. This grants no native
/// authority and does not replace independent post-action verification.
enum FixturePlannerAdmission {
    static func validate(_ context: PlannerContext, sessionID: String) throws {
        guard context.observation.sessionId == sessionID,
              context.observation.bundleId == "com.milyonus.computeruse.fixture" else { throw HarnessError.policyDenied }
        guard !context.goal.isEmpty, context.goal.utf8.count <= 16_384,
              (1...100).contains(context.remainingSteps), context.observation.elements.count <= 300 else {
            throw HarnessError.resourceLimit
        }
        try context.observation.validate()
        let age = Date().timeIntervalSince(context.observation.capturedAt)
        guard !context.observation.truncated, age >= -1, age < 10 else { throw HarnessError.staleObservation }
        let exported = Set(["fixture.input", "fixture.save", "fixture.status"])
        var seen = Set<String>()
        for element in context.observation.elements {
            guard let identifier = element.identifier, exported.contains(identifier) else { continue }
            guard seen.insert(identifier).inserted else { throw HarnessError.targetAmbiguous }
        }
    }
}
