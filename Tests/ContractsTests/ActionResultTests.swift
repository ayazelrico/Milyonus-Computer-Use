import ComputerUseContracts

@MainActor
final class ActionResultTests: TestCase {
    func testEffectVerificationMatrix() throws {
        for effect in [EffectState.applied, .notApplied, .unknown] {
            for verification in [Verification.passed, .failed, .unavailable] {
                for error in [HarnessError?.none, .cancelled] {
                    let result = ActionResult(requestId: "request", effect: effect, verification: verification, error: error)
                    let valid = (effect == .applied || verification == .unavailable)
                        && (verification != .passed || error == nil)
                    if valid { try result.validate() }
                    else {
                        expectThrows(try result.validate()) { expectEqual($0 as? HarnessError, .protocolMismatch) }
                    }
                }
            }
        }
    }
    func testMalformedResultIdentifiers() {
        for identifier in ["", "../path", "é", String(repeating: "x", count: 129)] {
            for requestField in [false, true] {
                let result = ActionResult(requestId: requestField ? identifier : "request",
                                          actionId: requestField ? "action" : identifier,
                                          effect: .applied, verification: .passed)
                expectThrows(try result.validate()) { expectEqual($0 as? HarnessError, .protocolMismatch) }
            }
        }
    }
}
