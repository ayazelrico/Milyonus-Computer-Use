import Foundation
import ComputerUseContracts

/// Opt-in feature admission for SDK consumers. Queries current capabilities before
/// each mutation, without caching permissions or replacing native authorization.
public struct NegotiatedHarnessClient: CapabilityHarnessClient, NativeTextHarnessClient,
    NativePointerHarnessClient, NativeScrollHarnessClient, NativeDragHarnessClient {
    private let base: any CapabilityHarnessClient & NativeTextHarnessClient & NativePointerHarnessClient & NativeScrollHarnessClient & NativeDragHarnessClient
    public init(base: any CapabilityHarnessClient & NativeTextHarnessClient & NativePointerHarnessClient & NativeScrollHarnessClient & NativeDragHarnessClient) {
        self.base = base
    }
    public func capabilities() async throws -> HarnessCapabilities {
        try Task.checkCancellation()
        let value = try await base.capabilities()
        try value.validate()
        try Task.checkCancellation()
        return value
    }
    public func openFixtureSession() async throws -> Session {
        _ = try await capabilities()
        return try await base.openFixtureSession()
    }
    public func status() async throws -> Session? { try await base.status() }
    public func observe(sessionID: String) async throws -> Observation { try await base.observe(sessionID: sessionID) }
    // Cancellation must remain available even when discovery is unavailable or revoked.
    public func cancel(sessionID: String) async throws { try await base.cancel(sessionID: sessionID) }
    public func act(_ request: ActionRequest) async throws -> ActionResult {
        try request.validate()
        guard request.kind == .press || request.kind == .setValue else { throw HarnessError.unsupportedCapability }
        let value = try await capabilities()
        guard value.supportedActions.contains(request.kind) else { throw HarnessError.unsupportedCapability }
        return try await base.act(request)
    }
    public func click(_ request: ActionRequest) async throws -> ActionResult {
        try request.validate()
        guard request.kind == .press else { throw HarnessError.invalidRequest }
        let value = try await capabilities()
        guard value.nativeElementClick else { throw HarnessError.unsupportedCapability }
        return try await base.click(request)
    }
    public func typeText(_ request: ActionRequest) async throws -> ActionResult {
        try request.validate()
        guard request.kind == .setValue, let text = request.text else { throw HarnessError.invalidRequest }
        let value = try await capabilities()
        guard value.nativeTextInput else { throw HarnessError.unsupportedCapability }
        guard text.utf16.count <= value.maximumNativeTextUTF16Units else { throw HarnessError.resourceLimit }
        return try await base.typeText(request)
    }
    public func scroll(_ request: ActionRequest) async throws -> ActionResult {
        try request.validate()
        guard request.kind == .scroll, let pixels = request.scrollPixels else { throw HarnessError.invalidRequest }
        let value = try await capabilities()
        guard value.experimentalNativeFixtureScroll else { throw HarnessError.unsupportedCapability }
        guard abs(pixels) <= value.maximumScrollPixels else { throw HarnessError.resourceLimit }
        return try await base.scroll(request)
    }
    public func drag(_ request: ActionRequest) async throws -> ActionResult {
        try request.validate()
        guard request.kind == .drag else { throw HarnessError.invalidRequest }
        let value = try await capabilities()
        guard value.experimentalNativeFixtureDrag else { throw HarnessError.unsupportedCapability }
        return try await base.drag(request)
    }
}
