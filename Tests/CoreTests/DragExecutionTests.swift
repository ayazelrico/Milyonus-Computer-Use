import Foundation
import ComputerUseContracts
import ComputerUseCore

@MainActor
final class DragExecutionTests: TestCase {
    func testReceiptRequiresCounterAndBothEndpoints() throws {
        let receipt = try FixtureDragReceipt("Drag completed 2: 120,50 to 360,50")
        expectEqual(receipt.matches(previousCount: 1, width: 480, height: 100), true)
        expectFalse(receipt.matches(previousCount: 2, width: 480, height: 100))
        expectFalse(receipt.matches(previousCount: Int.max, width: 480, height: 100))
        expectFalse(receipt.matches(previousCount: 1, width: .nan, height: 100))
        expectFalse(receipt.matches(previousCount: 1, width: 800, height: 100))
        let partial = try FixtureDragReceipt("Drag completed 2: 120,50 to 200,50")
        expectFalse(partial.matches(previousCount: 1, width: 480, height: 100))
        expectEqual(try FixtureDragReceipt.previousCount("No drag completed"), 0)
        for value in ["Drag in progress", "Drag rejected", "Drag completed 0: 120,50 to 360,50",
                      "Drag completed 1: 120,50,360 to 50", "Drag completed 1: -1,50 to 360,50",
                      "Drag completed 1: 120,50 to 360,100001", "Drag completed 999999999999999999999: 1,2 to 3,4"] {
            expectThrows(try FixtureDragReceipt.previousCount(value))
        }
    }
    func testCancelledDragReleasesBeforeEndpoint() async throws {
        let emitter = RecordingEmitter()
        let executor = InputSequenceExecutor(emitter: emitter)
        let steps = try PointerGesture.drag(from: .init(x: 120, y: 50), to: .init(x: 360, y: 50),
                                            within: .init(origin: .init(x: 0, y: 0), width: 480, height: 100))
        let task = Task { @MainActor in try await executor.execute(steps, authorize: {}) }
        for _ in 0..<1000 where emitter.events.count < 3 { await Task.yield() }
        executor.cancel()
        do { try await task.value; fail("Cancelled drag completed") }
        catch { expectEqual(error as? HarnessError, .cancelled) }
        expectEqual(emitter.events.first, .move(x: 120, y: 50))
        expectFalse(emitter.events.contains(.drag(x: 360, y: 50)))
        guard let lastDrag = emitter.events.last(where: {
            if case .drag = $0 { return true }; return false
        }), case .drag(let x, let y) = lastDrag else { fail("No drag event before cancellation"); return }
        expectEqual(emitter.events.last, .mouseUp(x: x, y: y))
    }
    func testDragContractForbidsOtherPayloads() throws {
        var request = ActionRequest(requestId: "r", sessionId: "s", idempotencyKey: "k", observationId: "o",
                                    generation: 1, elementId: "e", kind: .drag)
        try request.validate()
        expectEqual(try JSONDecoder().decode(ActionRequest.self, from: JSONEncoder().encode(request)), request)
        request.text = "unexpected"; expectThrows(try request.validate())
        request.text = nil; request.scrollPixels = 10; expectThrows(try request.validate())
    }
    func testDragMethodAdmissionAndDuplicateSuppression() async throws {
        let setup = ExecutionTests(); defer { setup.tearDown() }
        let (engine, _, _, original, directory) = try setup.setup()
        var request = original; request.kind = .drag
        expectThrows(try engine.execute(request)) { expectEqual($0 as? HarnessError, .unsupportedCapability) }
        for method in [ExecutionMethod.nativeClick, .nativeScroll, .nativeText] {
            do {
                _ = try await engine.executeAsync(request, method: method) { _ in
                    fail("Wrong route dispatched"); return ActionResult(requestId: request.requestId, effect: .applied, verification: .passed)
                }
                fail("Wrong route accepted")
            } catch { expectEqual(error as? HarnessError, .unsupportedCapability) }
        }
        expectFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("journal.json").path))
        var effects = 0
        let first = try await engine.executeAsync(request, method: .nativeDrag) { _ in
            effects += 1; return ActionResult(requestId: request.requestId, effect: .applied, verification: .passed)
        }
        let second = try await engine.executeAsync(request, method: .nativeDrag) { _ in
            effects += 1; return first
        }
        expectEqual(effects, 1); expectEqual(first.actionId, second.actionId)
    }
    func testDragFailurePausesAndRetainsUnknownIntentResult() async throws {
        let setup = ExecutionTests(); defer { setup.tearDown() }
        let (engine, sessions, _, original, directory) = try setup.setup()
        var request = original; request.kind = .drag
        let result = try await engine.executeAsync(request, method: .nativeDrag) { _ in throw HarnessError.userInterrupted }
        expectEqual(result.effect, .unknown)
        expectEqual(sessions.session?.pauseReason, .executionUncertain)
        let ledger = try ActionLedger(url: directory.appendingPathComponent("journal.json"))
        expectEqual(try ledger.previous(request, method: .nativeDrag), result)
        expectThrows(try ledger.previous(request, method: .nativeClick)) { expectEqual($0 as? HarnessError, .idempotencyConflict) }
    }
}
