import Foundation
import ComputerUseContracts
import ComputerUseCore
import ComputerUseClient

public struct GestureAcceptanceResult: Codable, Sendable {
    public let actions: Int
    public let pid: Int32
    public let scrollBefore: Double
    public let scrollAfter: Double
    public let dragCountBefore: Int
    public let dragCountAfter: Int
    public let independentVerification: Bool
}

/// Deterministic acceptance only; does not open/approve sessions, retry mutations,
/// activate windows, or call a provider. The transport maintains heartbeats separately.
public struct GestureAcceptanceRunner: Sendable {
    private let client: any NativeScrollHarnessClient & NativeDragHarnessClient
    public init(client: any NativeScrollHarnessClient & NativeDragHarnessClient) { self.client = client }
    private func ready(_ session: Session) async throws {
        try Task.checkCancellation()
        guard let current = try await client.status(), current.id == session.id,
              current.bundleId == HarnessProtocol.fixtureBundleID, current.state == .ready,
              current.generation == session.generation else { throw HarnessError.unauthorized }
        try Task.checkCancellation()
    }
    private func observe(_ session: Session, pid: Int32? = nil) async throws -> Observation {
        try await ready(session)
        let observation = try await client.observe(sessionID: session.id)
        guard observation.sessionId == session.id, observation.bundleId == HarnessProtocol.fixtureBundleID,
              observation.pid > 0, pid == nil || observation.pid == pid, !observation.truncated else {
            throw HarnessError.staleObservation
        }
        return observation
    }
    private func element(_ identifier: String, in observation: Observation, kind: ActionKind? = nil) throws -> ElementSnapshot {
        let matches = observation.elements.filter { $0.identifier == identifier }
        guard matches.count == 1, let element = matches.first else { throw HarnessError.targetAmbiguous }
        if let kind {
            guard element.enabled, element.actions.contains(kind) else { throw HarnessError.unsupportedCapability }
            let expectedRole = kind == .scroll ? "AXScrollArea" : "AXGroup"
            guard element.role == expectedRole else { throw HarnessError.staleObservation }
        }
        return element
    }
    private func scrollValue(_ observation: Observation) throws -> Double {
        let bars = observation.elements.filter { $0.role == "AXScrollBar" }
        guard bars.count == 1, let string = bars.first?.value, let value = Double(string),
              value.isFinite, (0...1).contains(value) else { throw HarnessError.verificationFailed }
        return value
    }
    private func verify(_ result: ActionResult, request: ActionRequest) throws {
        guard result.requestId == request.requestId, !result.actionId.isEmpty,
              result.effect == .applied, result.verification == .passed, result.error == nil else {
            throw HarnessError.verificationFailed
        }
    }
    public func run(session: Session) async throws -> GestureAcceptanceResult {
        guard session.state == .ready, session.bundleId == HarnessProtocol.fixtureBundleID else { throw HarnessError.unauthorized }
        let first = try await observe(session)
        let scroll = try element("fixture.scroll", in: first, kind: .scroll)
        guard let scrollBounds = scroll.bounds, scrollBounds.isValid else { throw HarnessError.targetNotFound }
        // Check that both fixture surfaces exist before the first mutation.
        let initialCanvas = try element("fixture.drag.canvas", in: first, kind: .drag)
        guard let initialBounds = initialCanvas.bounds, initialBounds.isValid,
              initialBounds.width >= 40, initialBounds.height >= 20,
              let initialStatus = try element("fixture.drag.status", in: first).value else { throw HarnessError.verificationFailed }
        _ = try FixtureDragReceipt.previousCount(initialStatus)
        let before = try scrollValue(first)
        let pixels = before <= 0.5 ? -200 : 200
        let scrollRequest = ActionRequest(requestId: UUID().uuidString, sessionId: session.id,
            idempotencyKey: UUID().uuidString, observationId: first.id, generation: session.generation,
            elementId: scroll.id, kind: .scroll, scrollPixels: pixels)
        try await ready(session)
        try verify(await client.scroll(scrollRequest), request: scrollRequest)
        let second = try await observe(session, pid: first.pid)
        guard second.id != first.id else { throw HarnessError.staleObservation }
        let scrolledTarget = try element("fixture.scroll", in: second, kind: .scroll)
        guard scrolledTarget.bounds == scrollBounds else { throw HarnessError.staleObservation }
        let after = try scrollValue(second)
        guard pixels < 0 ? after > before : after < before else { throw HarnessError.verificationFailed }
        let canvas = try element("fixture.drag.canvas", in: second, kind: .drag)
        guard let bounds = canvas.bounds, bounds.isValid, bounds.width >= 40, bounds.height >= 20 else { throw HarnessError.targetNotFound }
        let status = try element("fixture.drag.status", in: second)
        guard let text = status.value else { throw HarnessError.verificationFailed }
        let previous = try FixtureDragReceipt.previousCount(text)
        let dragRequest = ActionRequest(requestId: UUID().uuidString, sessionId: session.id,
            idempotencyKey: UUID().uuidString, observationId: second.id, generation: session.generation,
            elementId: canvas.id, kind: .drag)
        try await ready(session)
        try verify(await client.drag(dragRequest), request: dragRequest)
        let third = try await observe(session, pid: first.pid)
        guard third.id != second.id, third.id != first.id else { throw HarnessError.staleObservation }
        let finalCanvas = try element("fixture.drag.canvas", in: third, kind: .drag)
        guard finalCanvas.bounds == bounds,
              let finalText = try element("fixture.drag.status", in: third).value else { throw HarnessError.staleObservation }
        let receipt = try FixtureDragReceipt(finalText)
        guard receipt.matches(previousCount: previous, width: bounds.width, height: bounds.height) else {
            throw HarnessError.verificationFailed
        }
        try await ready(session)
        return GestureAcceptanceResult(actions: 2, pid: first.pid, scrollBefore: before, scrollAfter: after,
            dragCountBefore: previous, dragCountAfter: receipt.count, independentVerification: true)
    }
}
