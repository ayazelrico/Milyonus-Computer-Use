import Foundation

/// Describes implemented transport features, not a native approval or release certificate.
public struct HarnessCapabilities: Codable, Sendable, Equatable {
    public var version: Int = 1
    public var permissions: [String: Bool]
    public var supportedActions: [ActionKind] = [.press, .setValue]
    public var nativeTextInput: Bool = true
    public var nativeElementClick: Bool = true
    public var maximumNativeTextUTF16Units: Int = 1024
    public var experimentalNativeFixtureDrag: Bool = true
    public var experimentalNativeFixtureScroll: Bool = true
    public var maximumScrollPixels: Int = 2000
    public var mutationApps: [String] = ["com.milyonus.computeruse.fixture"]
    public var imageEgress: Bool = false
    public var requiresNativeApproval: Bool = true
    public var heartbeatIntervalSeconds: Int = 5
    public var heartbeatTimeoutSeconds: Int = 15
    public var productionReady: Bool = false

    public init(permissions: [String: Bool]) { self.permissions = permissions }

    /// This SDK supports only the current fixture policy and fixed heartbeat schedule.
    /// Unexpected policy expansion must not silently become authorization.
    public func validate() throws {
        guard version == 1,
              Set(permissions.keys) == ["accessibility", "screenRecording"],
              supportedActions.count == Set(supportedActions).count,
              supportedActions.allSatisfy({ $0 == .press || $0 == .setValue }),
              mutationApps == ["com.milyonus.computeruse.fixture"],
              requiresNativeApproval, !imageEgress, !productionReady,
              (1...1024).contains(maximumNativeTextUTF16Units),
              (1...2000).contains(maximumScrollPixels),
              heartbeatIntervalSeconds == 5, heartbeatTimeoutSeconds == 15 else {
            throw HarnessError.protocolMismatch
        }
    }
}
