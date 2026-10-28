import Foundation
import ComputerUseContracts
import ComputerUseClient
import ComputerUseIPC

@main struct TypedSessionClient {
    @MainActor static func main() async throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count == 2 || (args.count == 3 && args[2] == "approval") else { exit(64) }
        let client = XPCSessionClient(serviceName: args[0], peer: try .developmentCDHash(args[1]))
        try await client.connect()
        let capabilities = try await client.capabilities()
        let session = try await client.openFixtureSession()
        if args.count == 3 {
            guard capabilities.permissions["accessibility"] == true else { throw HarnessError.permissionRequired }
            try FileHandle.standardError.write(contentsOf: Data("Awaiting manual native session approval in companion.\n".utf8))
            let deadline = ContinuousClock.now.advanced(by: .seconds(120))
            var approved: Session?
            while ContinuousClock.now < deadline {
                if let current = try await client.status(), current.state == .ready { approved = current; break }
                try await Task.sleep(for: .milliseconds(250))
            }
            guard let approved else { throw HarnessError.timeout }
            let heartbeat = try await client.heartbeat(sessionID: approved.id, generation: approved.generation)
            guard heartbeat.state == .ready else { throw HarnessError.protocolMismatch }
            // Close an actually approved connection. A new connection must start awaitingApproval.
            await client.shutdown()
            try await Task.sleep(for: .milliseconds(500))
            try await client.connect()
            let next = try await client.openFixtureSession()
            guard next.state == .awaitingApproval, next.id != approved.id else { throw HarnessError.protocolMismatch }
            try await client.cancel(sessionID: next.id)
            await client.shutdown()
            print("{\"status\":\"passed\",\"typedSDK\":true,\"nativeApprovalGranted\":true,\"heartbeatVerified\":true,\"newSessionAfterDisconnect\":true,\"desktopActions\":0}")
            return
        }
        guard session.state == .awaitingApproval else { throw HarnessError.protocolMismatch }
        guard try await client.status()?.id == session.id else { throw HarnessError.protocolMismatch }
        do { _ = try await client.openFixtureSession(); throw HarnessError.protocolMismatch }
        catch HarnessError.leaseBusy {}
        do { _ = try await client.observe(sessionID: session.id); throw HarnessError.protocolMismatch }
        catch HarnessError.unsupportedCapability {}
        try await client.cancel(sessionID: session.id)
        let pending = try await client.openFixtureSession()
        await client.shutdown()
        try await Task.sleep(for: .milliseconds(500))
        try await client.connect()
        let next = try await client.openFixtureSession()
        guard next.state == .awaitingApproval, next.id != pending.id else { throw HarnessError.protocolMismatch }
        try await client.cancel(sessionID: next.id)
        await client.shutdown()
        let report: [String: Any] = ["status": "passed", "typedSDK": true,
            "nativeApprovalGranted": false, "desktopActions": 0, "newSessionAfterDisconnect": true,
            "accessibilityGranted": capabilities.permissions["accessibility"] ?? false,
            "screenRecordingGranted": capabilities.permissions["screenRecording"] ?? false]
        print(String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), as: UTF8.self))
    }
}
