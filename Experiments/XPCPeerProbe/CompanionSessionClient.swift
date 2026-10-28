import Foundation
import ComputerUseIPC

@main struct CompanionSessionClient {
    @MainActor static func main() async throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count == 2 else { exit(64) }
        let channel = AuthenticatedBrokerConnection()
        let peer = try BrokerPeerIdentity.developmentCDHash(args[1])
        func call(_ name: String) async throws -> [String: Any] {
            let request = try JSONSerialization.data(withJSONObject: ["name": name, "arguments": [:] as [String: String]])
            let reply = try await channel.request(request)
            guard let object = try JSONSerialization.jsonObject(with: reply) as? [String: Any], object["error"] == nil,
                  let result = object["result"] as? [String: Any] else { throw BrokerConnectionError.requestFailed }
            return result
        }
        try await channel.connect(serviceName: args[0], peer: peer)
        let capabilities = try await call("system_capabilities")
        guard (capabilities["supportedActions"] as? [String]) == [],
              capabilities["nativeTextInput"] as? Bool == false else { throw BrokerConnectionError.protocolMismatch }
        let first = try await call("session_open")
        guard first["state"] as? String == "awaitingApproval", let firstID = first["id"] as? String else {
            throw BrokerConnectionError.protocolMismatch
        }
        let forbidden = try JSONSerialization.data(withJSONObject: ["name": "session_open", "arguments": [:] as [String: String]])
        let rejected = try await channel.control(forbidden)
        guard let refusal = try JSONSerialization.jsonObject(with: rejected) as? [String: Any],
              refusal["error"] as? String == "UNSUPPORTED_CAPABILITY" else { throw BrokerConnectionError.protocolMismatch }
        let cancel = try JSONSerialization.data(withJSONObject: ["name": "session_cancel", "arguments": ["sessionId": firstID]])
        let cancelled = try await channel.control(cancel)
        guard let response = try JSONSerialization.jsonObject(with: cancelled) as? [String: Any],
              let cancelledSession = response["result"] as? [String: Any],
              cancelledSession["state"] as? String == "cancelled" else { throw BrokerConnectionError.protocolMismatch }
        let pending = try await call("session_open")
        guard pending["state"] as? String == "awaitingApproval" else { throw BrokerConnectionError.protocolMismatch }
        channel.close()
        try await Task.sleep(for: .milliseconds(500))
        try await channel.connect(serviceName: args[0], peer: peer)
        let second = try await call("session_open")
        guard second["state"] as? String == "awaitingApproval", let secondID = second["id"] as? String,
              firstID != secondID else { throw BrokerConnectionError.protocolMismatch }
        channel.close()
        let permissions = capabilities["permissions"] as? [String: Bool] ?? [:]
        let report: [String: Any] = ["status": "passed", "newSessionAfterDisconnect": true,
            "nativeApprovalGranted": false, "desktopActions": 0, "desktopCapabilitiesDisabled": true,
            "controlCancelVerified": true, "controlOpenRejected": true,
            "accessibilityGranted": permissions["accessibility"] ?? false,
            "screenRecordingGranted": permissions["screenRecording"] ?? false]
        print(String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), as: UTF8.self))
    }
}
