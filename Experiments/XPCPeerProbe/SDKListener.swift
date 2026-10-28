import Foundation
import ComputerUseIPC

@main struct ListenerMain {
    static func main() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count == 3 else { exit(64) }
        let listener = try BrokerHandshakeListener(serviceName: args[0], peer: .developmentCDHash(args[1]), onDisconnect: { _ in
            try? FileHandle.standardOutput.write(contentsOf: Data("disconnected\n".utf8))
        }, requestHandler: { context, data in
            guard context.isConnected else { return Data() }
            return data
        })
        try listener.start()
        let deadline = ContinuousClock.now.advanced(by: .seconds(20))
        while ContinuousClock.now < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
        listener.close()
    }
}
