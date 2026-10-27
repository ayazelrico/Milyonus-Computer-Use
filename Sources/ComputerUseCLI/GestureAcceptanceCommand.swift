import Foundation
import AppKit
import CryptoKit
import ComputerUseContracts
import ComputerUseClient
import ComputerUseAcceptance

/// Explicit native test command. Callers must arrange the packaged gesture fixture;
/// no script clicks the native approval control or changes system permissions.
@MainActor
func runGestureAcceptance(companionPath: String) async -> Bool {
    let started = Date()
    var evidence: [String: Any] = ["suite": "native-sdk-gesture-fixture", "status": "failed",
        "realInference": false, "nativeAcceptance": false, "fixtureOnly": true,
        "startedAt": ISO8601DateFormatter().string(from: started)]
    var client: StdioHarnessClient?
    do {
        guard companionPath.hasPrefix("/") else { throw HarnessError.invalidRequest }
        let fixtures = NSRunningApplication.runningApplications(withBundleIdentifier: HarnessProtocol.fixtureBundleID)
        guard fixtures.count == 1, let fixture = fixtures.first, let fixtureURL = fixture.executableURL else {
            throw HarnessError.targetAmbiguous
        }
        let fixturePID = fixture.processIdentifier
        evidence["fixturePID"] = fixturePID
        evidence["fixtureSHA256"] = SHA256.hash(data: try Data(contentsOf: fixtureURL)).map { String(format: "%02x", $0) }.joined()
        let url = URL(fileURLWithPath: companionPath)
        evidence["companionSHA256"] = SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
        let transport = try StdioHarnessClient(companionExecutable: url, diagnostics: true)
        client = transport
        try await transport.connect()
        let capabilities = try await transport.capabilities()
        guard capabilities.experimentalNativeFixtureScroll, capabilities.experimentalNativeFixtureDrag,
              capabilities.maximumScrollPixels >= 200 else { throw HarnessError.unsupportedCapability }
        guard capabilities.permissions["accessibility"] == true else { throw HarnessError.permissionRequired }
        let pending = try await transport.openFixtureSession()
        try FileHandle.standardError.write(contentsOf: Data("Gesture acceptance awaits native approval. Use the packaged --gesture-fixture window; do not type into it. No provider request.\n".utf8))
        let deadline = ContinuousClock.now.advanced(by: .seconds(120))
        var approved: Session?
        while ContinuousClock.now < deadline {
            try Task.checkCancellation()
            guard let current = try await transport.status(), current.id == pending.id,
                  ![.cancelled, .expired, .paused].contains(current.state) else { throw HarnessError.cancelled }
            if current.state == .ready { approved = current; break }
            try await Task.sleep(for: .milliseconds(250))
        }
        guard let approved else { throw HarnessError.timeout }
        // Only read-only activation retries. No mutation is retried on any outcome.
        for attempt in 0..<20 {
            do { _ = try await transport.observe(sessionID: approved.id); break }
            catch HarnessError.focusChanged {
                if attempt == 19 { throw HarnessError.focusChanged }
                try await Task.sleep(for: .milliseconds(100))
            }
        }
        let result = try await GestureAcceptanceRunner(client: NegotiatedHarnessClient(base: transport)).run(session: approved)
        guard result.pid == fixturePID else { throw HarnessError.staleObservation }
        try await transport.cancel(sessionID: approved.id)
        evidence["result"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(result))
        evidence["status"] = "passed"
        evidence["nativeAcceptance"] = true
    } catch {
        evidence["error"] = (error as? HarnessError)?.rawValue ?? (error is CancellationError ? "CANCELLED" : "INTERNAL_ERROR")
    }
    if let client { await client.shutdown() }
    evidence["finishedAt"] = ISO8601DateFormatter().string(from: Date())
    evidence["scope"] = "Two fixture actions only; not the complete interruption, hardware or release matrix."
    if let data = try? JSONSerialization.data(withJSONObject: evidence, options: [.sortedKeys]) {
        print(String(decoding: data, as: UTF8.self))
    }
    return evidence["status"] as? String == "passed"
}
