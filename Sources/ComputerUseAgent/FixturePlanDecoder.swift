import Foundation
import ComputerUseContracts

/// Provider output proposes actions only; native execution remains independently authorized.
enum FixturePlanDecoder {
    static func decode(_ step: [String: Any]) throws -> PlannerStep {
        guard Set(step.keys) == ["type", "elementIdentifier", "text"] else { throw HarnessError.providerResponseInvalid }
        let identifier = step["elementIdentifier"] as? String, value = step["text"] as? String
        switch step["type"] as? String {
        case "finish":
            guard step["elementIdentifier"] is NSNull, step["text"] is NSNull else { throw HarnessError.providerResponseInvalid }
            return .finish
        case "press":
            guard identifier == "fixture.save", step["text"] is NSNull else { throw HarnessError.providerResponseInvalid }
            return .action(PlannedAction(elementIdentifier: "fixture.save", kind: .press))
        case "setValue":
            guard identifier == "fixture.input", let value, value.utf8.count <= 16_384, !value.contains("\0") else {
                throw HarnessError.providerResponseInvalid
            }
            return .action(PlannedAction(elementIdentifier: "fixture.input", kind: .setValue, text: value))
        default: throw HarnessError.providerResponseInvalid
        }
    }
}
