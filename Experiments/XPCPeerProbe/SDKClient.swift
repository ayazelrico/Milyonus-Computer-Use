import Foundation
import ComputerUseIPC

@main struct SDKClientMain {
    @MainActor static func main() async throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count == 3 else { exit(64) }
        let channel = AuthenticatedBrokerConnection()
        var outcome = "authenticated"
        do {
            let task = Task { try await channel.connect(serviceName: args[0], peer: .developmentCDHash(args[1]), timeoutSeconds: 2) }
            if args[2] == "cancel" {
                try await Task.sleep(for: .milliseconds(100))
                task.cancel()
            }
            try await task.value
        }
        catch { outcome = String(describing: error) }
        let authenticated = channel.isAuthenticated
        var disconnected = false
        if args[2] == "disconnect" {
            let deadline = ContinuousClock.now.advanced(by: .seconds(3))
            while channel.isAuthenticated && ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            disconnected = !channel.isAuthenticated
        }
        var requestVerified = false
        if ["library", "session"].contains(args[2]), authenticated {
            let challenge = Data((args[2] == "session" ? "open" : "bounded-test-request").utf8)
            let expected = args[2] == "session" ? Data("awaitingApproval".utf8) : challenge
            requestVerified = try await channel.request(challenge) == expected
        }
        channel.close()
        let data = try JSONSerialization.data(withJSONObject: ["outcome": outcome,
            "requestVerified": requestVerified, "authenticated": authenticated, "disconnected": disconnected, "closed": !channel.isAuthenticated], options: [.sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    }
}
