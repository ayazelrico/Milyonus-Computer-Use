import Foundation

public enum HarnessError: String, Error, Codable, Sendable {
    case invalidRequest = "INVALID_REQUEST"
    case permissionRequired = "PERMISSION_REQUIRED"
    case permissionRevoked = "PERMISSION_REVOKED"
    case unauthorized = "UNAUTHORIZED"
    case policyDenied = "POLICY_DENIED"
    case leaseBusy = "LEASE_BUSY"
    case staleObservation = "STALE_OBSERVATION"
    case targetNotFound = "TARGET_NOT_FOUND"
    case targetAmbiguous = "TARGET_AMBIGUOUS"
    case focusChanged = "FOCUS_CHANGED"
    case userInterrupted = "USER_INTERRUPTED"
    case timeout = "TIMEOUT"
    case providerCredentialsRequired = "PROVIDER_CREDENTIALS_REQUIRED"
    case providerUnavailable = "PROVIDER_UNAVAILABLE"
    case providerResponseInvalid = "PROVIDER_RESPONSE_INVALID"
    case providerRefused = "PROVIDER_REFUSED"
    case noProgress = "NO_PROGRESS"
    case verificationFailed = "VERIFICATION_FAILED"
    case effectUnknown = "EFFECT_UNKNOWN"
    case unsupportedCapability = "UNSUPPORTED_CAPABILITY"
    case protocolMismatch = "PROTOCOL_MISMATCH"
    case resourceLimit = "RESOURCE_LIMIT"
    case idempotencyConflict = "IDEMPOTENCY_CONFLICT"
    case persistenceFailed = "PERSISTENCE_FAILED"
    case cancelled = "CANCELLED"
}

public struct Rect: Codable, Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
    public var isValid: Bool {
        [x, y, width, height, x + width, y + height].allSatisfy(\.isFinite)
            && width > 0 && height > 0 && x + width > x && y + height > y
    }
    public func contains(x: Double, y: Double) -> Bool {
        isValid && x.isFinite && y.isFinite && x >= self.x && y >= self.y && x < self.x + width && y < self.y + height
    }
}

/// Pixel coordinates are relative to this crop, not to the global desktop.
public struct FrameTransform: Codable, Sendable, Equatable {
    public var desktopBounds: Rect
    public var pixelWidth: Int
    public var pixelHeight: Int
    public init(desktopBounds: Rect, pixelWidth: Int, pixelHeight: Int) {
        self.desktopBounds = desktopBounds; self.pixelWidth = pixelWidth; self.pixelHeight = pixelHeight
    }
    public func desktopPoint(pixelX: Double, pixelY: Double) throws -> (x: Double, y: Double) {
        guard desktopBounds.isValid, pixelWidth > 0, pixelHeight > 0,
              pixelX.isFinite, pixelY.isFinite, pixelX >= 0, pixelY >= 0,
              pixelX < Double(pixelWidth), pixelY < Double(pixelHeight) else { throw HarnessError.invalidRequest }
        let x = desktopBounds.x + (pixelX / Double(pixelWidth)) * desktopBounds.width
        let y = desktopBounds.y + (pixelY / Double(pixelHeight)) * desktopBounds.height
        guard desktopBounds.contains(x: x, y: y) else { throw HarnessError.invalidRequest }
        return (x, y)
    }
}

public enum ActionKind: String, Codable, Sendable, CaseIterable {
    case press, setValue, scroll, drag
}

public struct ActionRequest: Codable, Sendable, Equatable {
    public var requestId: String
    public var sessionId: String
    public var idempotencyKey: String
    public var observationId: String
    public var generation: Int
    public var elementId: String
    public var kind: ActionKind
    public var text: String?
    public var scrollPixels: Int?
    public init(requestId: String, sessionId: String, idempotencyKey: String, observationId: String,
                generation: Int, elementId: String, kind: ActionKind, text: String? = nil, scrollPixels: Int? = nil) {
        self.requestId = requestId; self.sessionId = sessionId; self.idempotencyKey = idempotencyKey
        self.observationId = observationId; self.generation = generation; self.elementId = elementId
        self.kind = kind; self.text = text; self.scrollPixels = scrollPixels
    }
    public func validate() throws {
        for value in [requestId, sessionId, idempotencyKey, observationId, elementId] {
            guard !value.isEmpty, value.utf8.count <= 128,
                  value.unicodeScalars.allSatisfy({ (48...57).contains($0.value) || (65...90).contains($0.value) || (97...122).contains($0.value) || "-_.".unicodeScalars.contains($0) })
            else { throw HarnessError.invalidRequest }
        }
        guard generation > 0 else { throw HarnessError.invalidRequest }
        switch kind {
        case .scroll:
            guard text == nil, let scrollPixels, (-2000...2000).contains(scrollPixels), scrollPixels != 0 else { throw HarnessError.invalidRequest }
        case .press, .drag: guard scrollPixels == nil, text == nil else { throw HarnessError.invalidRequest }
        case .setValue: guard scrollPixels == nil, let text, text.utf8.count <= 16_384, !text.contains("\0") else { throw HarnessError.invalidRequest }
        }
    }
}

public enum EffectState: String, Codable, Sendable { case notApplied, applied, unknown }
public enum Verification: String, Codable, Sendable { case passed, failed, unavailable }
public struct ActionResult: Codable, Sendable, Equatable {
    public var requestId: String
    public var actionId: String
    public var effect: EffectState
    public var verification: Verification
    public var error: HarnessError?
    public init(requestId: String, actionId: String = UUID().uuidString, effect: EffectState,
                verification: Verification, error: HarnessError? = nil) {
        self.requestId = requestId; self.actionId = actionId; self.effect = effect
        self.verification = verification; self.error = error
    }
    /// Verification describes an applied effect. Contradictory outcomes are a
    /// protocol failure, not evidence that an action succeeded or did not occur.
    public func validate() throws {
        for identifier in [requestId, actionId] {
            guard !identifier.isEmpty, identifier.utf8.count <= 128,
                  identifier.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0)
                      || (97...122).contains($0) || [45, 46, 95].contains($0) }) else {
                throw HarnessError.protocolMismatch
            }
        }
        guard effect == .applied || verification == .unavailable,
              verification != .passed || error == nil else { throw HarnessError.protocolMismatch }
    }

}

public struct ElementSnapshot: Codable, Sendable, Equatable {
    public var id: String
    public var role: String
    public var identifier: String?
    public var label: String?
    public var value: String?
    public var bounds: Rect?
    public var enabled: Bool
    public var actions: [ActionKind]
    public init(id: String, role: String, identifier: String?, label: String?, value: String?,
                bounds: Rect?, enabled: Bool, actions: [ActionKind]) {
        self.id = id; self.role = role; self.identifier = identifier; self.label = label; self.value = value
        self.bounds = bounds; self.enabled = enabled; self.actions = actions
    }
}

public struct Observation: Codable, Sendable {
    public var id: String
    public var sessionId: String
    public var bundleId: String
    public var pid: Int32
    public var capturedAt: Date
    public var elements: [ElementSnapshot]
    public var truncated: Bool
    public var source: String = "accessibility"
    public init(id: String, sessionId: String, bundleId: String, pid: Int32, capturedAt: Date,
                elements: [ElementSnapshot], truncated: Bool) {
        self.id = id; self.sessionId = sessionId; self.bundleId = bundleId; self.pid = pid
        self.capturedAt = capturedAt; self.elements = elements; self.truncated = truncated
    }
}

public enum SessionState: String, Codable, Sendable { case awaitingApproval, ready, paused, cancelled, expired }
public enum SessionPauseReason: String, Codable, Sendable {
    case requested, userInput, environmentChanged, heartbeatLost, executionUncertain
}
public struct Session: Codable, Sendable, Equatable {
    public var id: String
    public var bundleId: String
    public var generation: Int
    public var state: SessionState
    public var pauseReason: SessionPauseReason? = nil
    public var expiresAt: Date
    public init(id: String, bundleId: String, generation: Int, state: SessionState, expiresAt: Date) {
        self.id = id; self.bundleId = bundleId; self.generation = generation; self.state = state; self.expiresAt = expiresAt
    }
}
