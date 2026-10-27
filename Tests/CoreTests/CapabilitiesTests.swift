import Foundation
import ComputerUseContracts
import ComputerUseClient

@MainActor
final class CapabilitiesTests: TestCase {
    func testCurrentContractDoesNotRequirePermissions() throws {
        let value = HarnessCapabilities(permissions: ["accessibility": false, "screenRecording": false])
        try value.validate()
        expectEqual(try JSONDecoder().decode(HarnessCapabilities.self, from: JSONEncoder().encode(value)), value)
        expectEqual(value.supportedActions, [.press, .setValue])
        expectEqual(value.experimentalNativeFixtureDrag, true)
        expectEqual(value.requiresNativeApproval, true)
        expectEqual(value.productionReady, false)
    }
    func testIncompatiblePolicyAndLimitsRejected() throws {
        let base = HarnessCapabilities(permissions: ["accessibility": true, "screenRecording": false])
        let changes: [(inout HarnessCapabilities) -> Void] = [
            { $0.version = 2 }, { $0.permissions = [:] }, { $0.supportedActions = [.drag] },
            { $0.supportedActions = [.press, .press] }, { $0.mutationApps.append("other.app") },
            { $0.requiresNativeApproval = false }, { $0.imageEgress = true }, { $0.productionReady = true },
            { $0.maximumNativeTextUTF16Units = 0 }, { $0.maximumNativeTextUTF16Units = 1025 },
            { $0.maximumScrollPixels = -1 }, { $0.maximumScrollPixels = 2001 },
            { $0.heartbeatIntervalSeconds = 15 }, { $0.heartbeatTimeoutSeconds = 5 }
        ]
        for change in changes {
            var value = base; change(&value)
            expectThrows(try value.validate()) { expectEqual($0 as? HarnessError, .protocolMismatch) }
        }
        var reduced = base
        reduced.supportedActions = []; reduced.experimentalNativeFixtureDrag = false
        reduced.maximumScrollPixels = 100
        try reduced.validate()
    }
    func testMalformedCapabilitiesCloseTransport() async throws {
        let factory = StdioFailureTests(); defer { factory.tearDown() }
        for mode in ["caps-policy", "caps-boolean"] {
            let client = try factory.client(mode: mode)
            do {
                try await client.connect()
                do { _ = try await client.capabilities(); fail("Invalid capabilities accepted") }
                catch { expectEqual(error as? HarnessError, .protocolMismatch) }
                do { _ = try await client.capabilities(); fail("Transport remained open") }
                catch { expectEqual(error as? HarnessError, .cancelled) }
            } catch { await client.shutdown(); throw error }
            await client.shutdown()
        }
    }
    func testCapabilityReadsDoNotOpenSession() async throws {
        let factory = StdioFailureTests(); defer { factory.tearDown() }
        let client = try factory.client(mode: "caps-valid")
        do {
            try await client.connect()
            for _ in 0..<2 {
                let value = try await client.capabilities()
                expectEqual(value.permissions["accessibility"], false)
                expectEqual(value.requiresNativeApproval, true)
            }
        } catch { await client.shutdown(); throw error }
        await client.shutdown()
    }
}
