import Foundation
import ComputerUseContracts

@MainActor
final class ObservationValidationTests: TestCase {
    func fixture() -> Observation {
        Observation(id: "observation", sessionId: "session", bundleId: "com.milyonus.computeruse.fixture",
                    pid: 42, capturedAt: Date(), elements: [ElementSnapshot(id: "element", role: "R",
                    identifier: nil, label: nil, value: nil, bounds: nil, enabled: true, actions: [.press])], truncated: false)
    }
    func testStructuralLimitsAndUniqueHandles() throws {
        let valid = fixture()
        try valid.validate()
        var partial = valid; partial.truncated = true; try partial.validate()
        var variants: [Observation] = []
        var changed = valid; changed.elements += changed.elements; variants.append(changed)
        changed = valid; changed.elements[0].actions = [.press, .press]; variants.append(changed)
        changed = valid; changed.elements[0].role = ""; variants.append(changed)
        changed = valid; changed.elements[0].id = "../invalid"; variants.append(changed)
        changed = valid; changed.source = "shell"; variants.append(changed)
        changed = valid; changed.capturedAt = Date(timeIntervalSinceReferenceDate: .infinity); variants.append(changed)
        changed = valid; changed.elements[0].bounds = Rect(x: 1e308, y: 0, width: 1e308, height: 1); variants.append(changed)
        for item in variants {
            expectThrows(try item.validate()) { expectEqual($0 as? HarnessError, .protocolMismatch) }
        }
        var full = valid
        full.elements = (0..<300).map { index in
            var element = valid.elements[0]; element.id = "element-\(index)"; return element
        }
        try full.validate()
        var last = valid.elements[0]; last.id = "overflow"
        full.elements.append(last)
        expectThrows(try full.validate()) { expectEqual($0 as? HarnessError, .protocolMismatch) }
    }
    func testAggregateTextUsesUTF8AndExclusiveLimit() throws {
        var value = fixture()
        value.elements[0].value = String(repeating: "a", count: 47_998)
        try value.validate() // One role byte plus value = 47,999.
        value.elements[0].label = "x"
        expectThrows(try value.validate())
        value = fixture(); value.elements[0].value = String(repeating: "😀", count: 12_000)
        expectThrows(try value.validate())
        value = fixture(); value.elements[0].identifier = String(repeating: "a", count: 24_000)
        value.elements[0].label = String(repeating: "b", count: 24_000)
        expectThrows(try value.validate())
    }
}
