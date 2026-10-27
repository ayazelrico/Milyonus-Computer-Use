import Foundation
import ComputerUseContracts
import ComputerUseClient

actor NegotiationFixture: CapabilityHarnessClient, NativeTextHarnessClient, NativePointerHarnessClient, NativeScrollHarnessClient, NativeDragHarnessClient {
    var advertised = HarnessCapabilities(permissions: ["accessibility": false, "screenRecording": false])
    var reads = 0
    var actions: [String] = []
    var cancelled = false
    var failDiscovery = false
    var unknown = false
    func configure(_ value: HarnessCapabilities, fail: Bool = false, unknown: Bool = false) {
        advertised = value; failDiscovery = fail; self.unknown = unknown
    }
    func capabilities() async throws -> HarnessCapabilities {
        reads += 1
        if failDiscovery { throw HarnessError.providerUnavailable }
        return advertised
    }
    func openFixtureSession() async throws -> Session { throw HarnessError.unauthorized }
    func status() async throws -> Session? { nil }
    func observe(sessionID: String) async throws -> Observation { throw HarnessError.unauthorized }
    func cancel(sessionID: String) async throws { cancelled = true }
    func result(_ name: String, _ request: ActionRequest) -> ActionResult {
        actions.append(name)
        return ActionResult(requestId: request.requestId, effect: unknown ? .unknown : .applied,
                            verification: unknown ? .unavailable : .passed)
    }
    func act(_ request: ActionRequest) async throws -> ActionResult { result("act", request) }
    func click(_ request: ActionRequest) async throws -> ActionResult { result("click", request) }
    func typeText(_ request: ActionRequest) async throws -> ActionResult { result("type", request) }
    func scroll(_ request: ActionRequest) async throws -> ActionResult { result("scroll", request) }
    func drag(_ request: ActionRequest) async throws -> ActionResult { result("drag", request) }
}

@MainActor
final class NegotiatedClientTests: TestCase {
    func request(_ kind: ActionKind) -> ActionRequest {
        ActionRequest(requestId: "r", sessionId: "s", idempotencyKey: "k", observationId: "o", generation: 1,
                      elementId: "e", kind: kind, text: kind == .setValue ? "hello" : nil,
                      scrollPixels: kind == .scroll ? -200 : nil)
    }
    func testDisabledFeaturesNeverDispatch() async throws {
        let base = NegotiationFixture()
        var caps = await base.advertised
        caps.supportedActions = []; caps.nativeTextInput = false; caps.nativeElementClick = false
        caps.experimentalNativeFixtureScroll = false; caps.experimentalNativeFixtureDrag = false
        await base.configure(caps)
        let gated = NegotiatedHarnessClient(base: base)
        for method in ["act", "click", "type", "scroll", "drag"] {
            do {
                switch method {
                case "act": _ = try await gated.act(request(.press))
                case "click": _ = try await gated.click(request(.press))
                case "type": _ = try await gated.typeText(request(.setValue))
                case "scroll": _ = try await gated.scroll(request(.scroll))
                default: _ = try await gated.drag(request(.drag))
                }
                fail("Disabled feature dispatched")
            } catch { expectEqual(error as? HarnessError, .unsupportedCapability) }
        }
        let actions = await base.actions; expectEqual(actions, [])
    }
    func testFreshLimitsAndRevocation() async throws {
        let base = NegotiationFixture(); let client = NegotiatedHarnessClient(base: base)
        _ = try await client.scroll(request(.scroll))
        var caps = await base.advertised; caps.maximumScrollPixels = 100; caps.maximumNativeTextUTF16Units = 2
        await base.configure(caps)
        do { _ = try await client.scroll(request(.scroll)); fail("Old limit reused") }
        catch { expectEqual(error as? HarnessError, .resourceLimit) }
        do { _ = try await client.typeText(request(.setValue)); fail("Text limit ignored") }
        catch { expectEqual(error as? HarnessError, .resourceLimit) }
        let actions = await base.actions; expectEqual(actions, ["scroll"])
        let reads = await base.reads; expectEqual(reads, 3)
    }
    func testUnknownResultIsNotRetriedAndCancelBypassesDiscovery() async throws {
        let base = NegotiationFixture(); let client = NegotiatedHarnessClient(base: base)
        let caps = await base.advertised
        await base.configure(caps, unknown: true)
        let result = try await client.drag(request(.drag)); expectEqual(result.effect, .unknown)
        await base.configure(caps, fail: true)
        do { _ = try await client.drag(request(.drag)); fail("Discovery failure ignored") }
        catch { expectEqual(error as? HarnessError, .providerUnavailable) }
        try await client.cancel(sessionID: "s")
        let cancelled = await base.cancelled; expectEqual(cancelled, true)
        let actions = await base.actions; expectEqual(actions, ["drag"])
    }
}
