import Foundation
import ComputerUseIPC

private actor HeldRequest {
    private var continuation: CheckedContinuation<Data, Never>?
    func hold() async -> Data { await withCheckedContinuation { continuation = $0 } }
    func control(_ data: Data) -> Data {
        let command = String(decoding: data, as: UTF8.self)
        if command == "status" { return Data((continuation == nil ? "idle" : "waiting").utf8) }
        if command == "heartbeat" { return Data("alive".utf8) }
        if command == "stop" {
            let pending = continuation; continuation = nil
            pending?.resume(returning: Data("stopped".utf8))
            return Data("cancelled".utf8)
        }
        return Data("unsupported".utf8)
    }
}

@main struct ListenerMain {
    static func main() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count == 3 else { exit(64) }
        let held = HeldRequest()
        let listener = try BrokerHandshakeListener(serviceName: args[0], peer: .developmentCDHash(args[1]), onDisconnect: { _ in
            try? FileHandle.standardOutput.write(contentsOf: Data("disconnected\n".utf8))
        }, requestHandler: { context, data in
            guard context.isConnected else { return Data() }
            if args[2] == "control" { return await held.hold() }
            return data
        }, controlHandler: { _, data in await held.control(data) })
        try listener.start()
        let deadline = ContinuousClock.now.advanced(by: .seconds(20))
        while ContinuousClock.now < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
        listener.close()
    }
}
