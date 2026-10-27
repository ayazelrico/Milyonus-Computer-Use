import Foundation
import ComputerUseContracts

/// Integration boundary for Example Host. Implementations must not manufacture native grants.
public protocol HarnessClient: Sendable {
    func openFixtureSession() async throws -> Session
    func status() async throws -> Session?
    func observe(sessionID: String) async throws -> Observation
    func act(_ request: ActionRequest) async throws -> ActionResult
    func cancel(sessionID: String) async throws
}

public enum HarnessProtocol {
    public static let fixtureBundleID = "com.milyonus.computeruse.fixture"
    public static let schemaVersion = "1.0"
    public static let maximumMessageBytes = 262_144
    public static let supportedMCPVersions = ["2025-11-25", "2025-03-26"]
}

/// Optional capability; implementations without native input remain source compatible.
public protocol NativeTextHarnessClient: HarnessClient {
    func typeText(_ request: ActionRequest) async throws -> ActionResult
}

public protocol NativePointerHarnessClient: HarnessClient {
    func click(_ request: ActionRequest) async throws -> ActionResult
}

public protocol HeartbeatHarnessClient: HarnessClient {
    func heartbeat(sessionID: String, generation: Int) async throws -> Session
}

/// Dedicated connection lifecycle for native host integration.
public protocol ManagedHarnessClient: HarnessClient {
    func connect() async throws
    func shutdown() async
}

extension StdioHarnessClient: ManagedHarnessClient {}

/// Optional vertical fixture scrolling; never supplies desktop coordinates.
public protocol NativeScrollHarnessClient: HarnessClient {
    func scroll(_ request: ActionRequest) async throws -> ActionResult
}

/// Experimental fixed horizontal sweep inside the resolved fixture canvas.
public protocol NativeDragHarnessClient: HarnessClient {
    func drag(_ request: ActionRequest) async throws -> ActionResult
}

/// Read-only feature discovery. Never replaces native session approval.
public protocol CapabilityHarnessClient: HarnessClient {
    func capabilities() async throws -> HarnessCapabilities
}
