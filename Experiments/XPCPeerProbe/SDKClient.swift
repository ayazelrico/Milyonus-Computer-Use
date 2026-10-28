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
        channel.close()
        let data = try JSONSerialization.data(withJSONObject: ["outcome": outcome,
            "authenticated": authenticated, "disconnected": disconnected, "closed": !channel.isAuthenticated], options: [.sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    }
}
