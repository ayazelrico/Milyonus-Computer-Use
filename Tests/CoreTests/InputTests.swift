import Foundation
import ComputerUseContracts
import ComputerUseCore

@MainActor
final class RecordingEmitter: InputEmitter {
    var events: [InputEvent] = []
    var failAt: Int?
    func emit(_ event: InputEvent) throws {
        events.append(event)
        if events.count == failAt { throw HarnessError.effectUnknown }
    }
}
@MainActor
final class InputTests: TestCase {
    func testInputPermissionCheckedBeforeEveryEvent() async throws {
        let emitter = RecordingEmitter()
        let actual = InputSequenceExecutor(emitter: emitter)
        var checks = 0
        do {
            try await actual.execute([InputStep(.keyDown(code: 12)), InputStep(.keyUp(code: 12)), InputStep(.keyDown(code: 13))]) {
                checks += 1
                if checks == 2 { throw HarnessError.permissionRevoked }
            }
            fail("Revoked permission did not stop input")
        } catch { expectEqual(error as? HarnessError, .permissionRevoked) }
        expectEqual(emitter.events, [.keyDown(code: 12), .keyUp(code: 12)])
    }
    func testEmitterFailureStillReleasesHeldMouse() async throws {
        let emitter = RecordingEmitter(); emitter.failAt = 1
        let executor = InputSequenceExecutor(emitter: emitter)
        do { try await executor.execute([InputStep(.mouseDown(x: 10, y: 20))], authorize: {}) }
        catch { expectEqual(error as? HarnessError, .effectUnknown) }
        expectEqual(emitter.events, [.mouseDown(x: 10, y: 20), .mouseUp(x: 10, y: 20)])
    }
    func testInvalidCoordinatesDispatchNothing() async throws {
        let emitter = RecordingEmitter()
        let actual = InputSequenceExecutor(emitter: emitter)
        do { try await actual.execute([InputStep(.move(x: .nan, y: 0))], authorize: {}); fail("NaN accepted") }
        catch { expectEqual(error as? HarnessError, .invalidRequest) }
        expectEqual(emitter.events.count, 0)
    }
    func testCancelDuringDelayReleasesAndFencesNextEvent() async throws {
        let emitter = RecordingEmitter()
        let actual = InputSequenceExecutor(emitter: emitter)
        let task = Task { @MainActor in
            try await actual.execute([InputStep(.keyDown(code: 12), delayAfterMilliseconds: 100), InputStep(.keyDown(code: 13))], authorize: {})
        }
        for _ in 0..<100 where emitter.events.isEmpty { await Task.yield() }
        actual.cancel()
        do { try await task.value; fail("Cancelled sequence completed") }
        catch { expectEqual(error as? HarnessError, .cancelled) }
        expectEqual(emitter.events, [.keyDown(code: 12), .keyUp(code: 12)])
    }
    func testSequenceBudgetRejectsBeforeDispatch() async throws {
        let emitter = RecordingEmitter()
        let executor = InputSequenceExecutor(emitter: emitter)
        do {
            try await executor.execute(Array(repeating: InputStep(.move(x: 1, y: 1), delayAfterMilliseconds: 1000), count: 11), authorize: {})
            fail("Excessive sequence budget accepted")
        } catch { expectEqual(error as? HarnessError, .resourceLimit) }
        expectEqual(emitter.events.count, 0)
    }
}
