import Foundation
import ComputerUseContracts
import ComputerUseCore

@MainActor
final class ScrollExecutionTests: TestCase {
    func testScrollContractRoundTripAndBounds() throws {
        var request = ActionRequest(requestId: "r", sessionId: "s", idempotencyKey: "k", observationId: "o",
                                    generation: 1, elementId: "e", kind: .scroll, scrollPixels: -2000)
        for pixels in [-2000, -1, 1, 2000] {
            request.scrollPixels = pixels
            try request.validate()
            expectEqual(try JSONDecoder().decode(ActionRequest.self, from: JSONEncoder().encode(request)), request)
        }
        for pixels in [nil, 0, -2001, 2001, Int.min, Int.max] as [Int?] {
            request.scrollPixels = pixels
            expectThrows(try request.validate())
        }
        request.scrollPixels = 20; request.text = "unexpected"
        expectThrows(try request.validate())
        request.text = nil; request.kind = .press
        expectThrows(try request.validate())
        request.kind = .setValue; request.text = "value"
        expectThrows(try request.validate())
    }
    func testScrollMethodGatePrecedesJournal() async throws {
        let setup = ExecutionTests(); defer { setup.tearDown() }
        let (engine, _, driver, original, directory) = try setup.setup()
        var request = original; request.kind = .scroll; request.scrollPixels = -100
        expectThrows(try engine.execute(request)) { expectEqual($0 as? HarnessError, .unsupportedCapability) }
        do {
            _ = try await engine.executeAsync(original, method: .nativeScroll) { _ in
                fail("Wrong kind dispatched"); return ActionResult(requestId: original.requestId, effect: .applied, verification: .passed)
            }
            fail("Wrong method accepted")
        } catch { expectEqual(error as? HarnessError, .unsupportedCapability) }
        expectEqual(driver.applied, 0)
        expectFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("journal.json").path))
    }
    func testScrollDuplicateAndChangedDelta() async throws {
        let setup = ExecutionTests(); defer { setup.tearDown() }
        let (engine, _, _, original, _) = try setup.setup()
        var request = original; request.kind = .scroll; request.scrollPixels = -100
        var effects = 0
        let first = try await engine.executeAsync(request, method: .nativeScroll) { _ in
            effects += 1
            return ActionResult(requestId: request.requestId, effect: .applied, verification: .passed)
        }
        let second = try await engine.executeAsync(request, method: .nativeScroll) { _ in
            effects += 1
            return ActionResult(requestId: request.requestId, effect: .applied, verification: .passed)
        }
        expectEqual(first.actionId, second.actionId); expectEqual(effects, 1)
        request.scrollPixels = -101
        do {
            _ = try await engine.executeAsync(request, method: .nativeScroll) { _ in
                fail("Changed delta dispatched"); return first
            }
            fail("Changed delta reused key")
        } catch { expectEqual(error as? HarnessError, .idempotencyConflict) }
    }
    func testUnknownScrollPausesWithoutReplay() async throws {
        let setup = ExecutionTests(); defer { setup.tearDown() }
        let (engine, sessions, _, original, _) = try setup.setup()
        var request = original; request.kind = .scroll; request.scrollPixels = -100
        let result = try await engine.executeAsync(request, method: .nativeScroll) { _ in throw HarnessError.focusChanged }
        expectEqual(result.effect, .unknown)
        expectEqual(sessions.session?.state, .paused)
        expectEqual(sessions.session?.pauseReason, .executionUncertain)
        do {
            _ = try await engine.executeAsync(request, method: .nativeScroll) { _ in
                fail("Unknown scroll replayed"); return result
            }
            fail("Paused session accepted")
        } catch { expectEqual(error as? HarnessError, .unauthorized) }
    }
}
