import Foundation
import ComputerUseContracts
import ComputerUseClient
import ComputerUseAcceptance

actor SyntheticGestureClient: NativeScrollHarnessClient, NativeDragHarnessClient {
    let mode: String
    var calls: [ActionRequest] = []
    var observations = 0
    var scrolled = false
    var dragged = false
    init(_ mode: String = "valid") { self.mode = mode }
    func session() -> Session {
        Session(id: "session", bundleId: HarnessProtocol.fixtureBundleID,
                generation: mode == "generation" && scrolled ? 2 : 1, state: .ready,
                expiresAt: Date().addingTimeInterval(120))
    }
    func openFixtureSession() async throws -> Session { throw HarnessError.policyDenied }
    func status() async throws -> Session? {
        if mode == "cancel" && scrolled { withUnsafeCurrentTask { $0?.cancel() } }
        return session()
    }
    func cancel(sessionID: String) async throws {}
    func act(_ request: ActionRequest) async throws -> ActionResult { throw HarnessError.unsupportedCapability }
    func scroll(_ request: ActionRequest) async throws -> ActionResult {
        calls.append(request); scrolled = true
        return ActionResult(requestId: request.requestId, effect: mode == "unknown" ? .unknown : .applied,
                            verification: mode == "unknown" ? .unavailable : .passed)
    }
    func drag(_ request: ActionRequest) async throws -> ActionResult {
        calls.append(request); dragged = true
        return ActionResult(requestId: request.requestId, effect: .applied, verification: .passed)
    }
    func observe(sessionID: String) async throws -> Observation {
        observations += 1
        let canvas = ElementSnapshot(id: "canvas-\(observations)", role: "AXGroup", identifier: "fixture.drag.canvas",
            label: nil, value: nil, bounds: Rect(x: 0, y: 0, width: 480, height: 100), enabled: true, actions: [.drag])
        var elements = [canvas,
            ElementSnapshot(id: "scroll-\(observations)", role: "AXScrollArea", identifier: "fixture.scroll", label: nil,
                value: nil, bounds: Rect(x: 0, y: 110, width: 480, height: 110), enabled: true, actions: [.scroll]),
            ElementSnapshot(id: "bar-\(observations)", role: "AXScrollBar", identifier: nil, label: nil,
                value: scrolled && mode != "unchanged" ? "0.4" : "0.1", bounds: nil, enabled: true, actions: []),
            ElementSnapshot(id: "status-\(observations)", role: "AXStaticText", identifier: "fixture.drag.status", label: nil,
                value: dragged ? (mode == "partial" ? "Drag completed 1: 120,50 to 200,50" : "Drag completed 1: 120,50 to 360,50") : "No drag completed",
                bounds: nil, enabled: true, actions: [])]
        if mode == "upward" { elements[2].value = scrolled ? "0.6" : "0.9" }
        if mode == "wrong-direction" && scrolled { elements[2].value = "0.0" }
        if mode == "bar-missing" { elements.remove(at: 2) }
        if mode == "bar-ambiguous" { elements.append(elements[2]) }
        if mode == "bar-nan" { elements[2].value = "nan" }
        if mode == "scroll-resize" && scrolled { elements[1].bounds?.width = 400 }
        if mode == "drag-resize" && dragged { elements[0].bounds?.width = 400 }
        if mode == "wrong-role" { elements[0].role = "AXButton" }
        if mode == "duplicate" { elements.append(canvas) }
        if mode == "missing" { elements.removeFirst() }
        return Observation(id: mode == "stale" ? "same" : "observation-\(observations)", sessionId: sessionID,
            bundleId: HarnessProtocol.fixtureBundleID, pid: mode == "pid" && scrolled ? 43 : 42,
            capturedAt: Date(), elements: elements, truncated: mode == "truncated")
    }
}

@MainActor
final class GestureAcceptanceTests: TestCase {
    func testIndependentCompletionAndFreshTargets() async throws {
        let client = SyntheticGestureClient()
        let result = try await GestureAcceptanceRunner(client: client).run(session: client.session())
        let calls = await client.calls
        expectEqual(result.actions, 2); expectEqual(result.independentVerification, true)
        expectEqual(result.scrollBefore, 0.1); expectEqual(result.scrollAfter, 0.4)
        expectEqual(result.dragCountBefore, 0); expectEqual(result.dragCountAfter, 1)
        expectEqual(calls.map(\.kind), [.scroll, .drag])
        expectEqual(calls.map(\.observationId), ["observation-1", "observation-2"])
        expectEqual(calls.map(\.elementId), ["scroll-1", "canvas-2"])
        expectFalse(calls[0].idempotencyKey == calls[1].idempotencyKey)
    }
    func testAdmissionRejectsBeforeMutation() async throws {
        for mode in ["missing", "duplicate", "truncated"] {
            let client = SyntheticGestureClient(mode)
            do {
                _ = try await GestureAcceptanceRunner(client: client).run(session: client.session())
                fail("Invalid initial fixture accepted: \(mode)")
            } catch { expectEqual(error as? HarnessError, mode == "truncated" ? .staleObservation : .targetAmbiguous) }
            let calls = await client.calls
            expectEqual(calls.count, 0)
        }
    }
    func testUnknownOrChangedStateNeverDispatchesDrag() async throws {
        for mode in ["unknown", "unchanged", "pid", "generation", "stale"] {
            let client = SyntheticGestureClient(mode)
            do {
                _ = try await GestureAcceptanceRunner(client: client).run(session: client.session())
                fail("Invalid scroll acceptance: \(mode)")
            } catch {
                let expected: HarnessError = mode == "generation" ? .unauthorized : (["pid", "stale"].contains(mode) ? .staleObservation : .verificationFailed)
                expectEqual(error as? HarnessError, expected)
            }
            let calls = await client.calls
            expectEqual(calls.count, 1)
        }
    }
    func testUpwardScrollUsesInteriorDirection() async throws {
        let client = SyntheticGestureClient("upward")
        let result = try await GestureAcceptanceRunner(client: client).run(session: client.session())
        expectEqual(result.scrollBefore, 0.9); expectEqual(result.scrollAfter, 0.6)
        let calls = await client.calls
        expectEqual(calls[0].scrollPixels, 200)
    }
    func testAmbiguousAndMalformedScrollbarsCannotStart() async throws {
        for mode in ["bar-missing", "bar-ambiguous", "bar-nan", "wrong-role"] {
            let client = SyntheticGestureClient(mode)
            do {
                _ = try await GestureAcceptanceRunner(client: client).run(session: client.session())
                fail("Invalid fixture accepted: \(mode)")
            } catch { expectEqual(error as? HarnessError, mode == "wrong-role" ? .staleObservation : .verificationFailed) }
            let calls = await client.calls; expectEqual(calls.count, 0)
        }
    }
    func testWrongDirectionAndResizedTargetsCannotPass() async throws {
        for mode in ["wrong-direction", "scroll-resize", "drag-resize"] {
            let client = SyntheticGestureClient(mode)
            do {
                _ = try await GestureAcceptanceRunner(client: client).run(session: client.session())
                fail("Invalid effect accepted: \(mode)")
            } catch { expectEqual(error as? HarnessError, mode == "wrong-direction" ? .verificationFailed : .staleObservation) }
            let calls = await client.calls; expectEqual(calls.count, mode == "drag-resize" ? 2 : 1)
        }
    }
    func testCancellationDuringStatusStopsNextMutation() async throws {
        let client = SyntheticGestureClient("cancel")
        let task = Task { try await GestureAcceptanceRunner(client: client).run(session: client.session()) }
        do { _ = try await task.value; fail("Cancellation ignored") }
        catch { expectEqual(error is CancellationError, true) }
        let calls = await client.calls
        expectEqual(calls.count, 1)
    }
    func testPartialDragCannotPassOrRetry() async throws {
        let client = SyntheticGestureClient("partial")
        do {
            _ = try await GestureAcceptanceRunner(client: client).run(session: client.session())
            fail("Partial drag accepted")
        } catch { expectEqual(error as? HarnessError, .verificationFailed) }
        let calls = await client.calls
        expectEqual(calls.count, 2)
    }
}
