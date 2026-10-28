import Foundation
import ComputerUseIPC
import ComputerUseCore

@MainActor final class SessionHost {
    let sessions = SessionController(heartbeatTimeout: 15)
    lazy var owner = ConnectionSessionOwner(sessions: sessions, invalidateTargets: {})
    func request(_ context: BrokerConnectionContext, _ data: Data) -> Data {
        guard data == Data("open".utf8) else { return Data("unsupported".utf8) }
        do {
            let session = try owner.open(connectionID: context.id, isConnected: { context.isConnected })
            return Data(session.state.rawValue.utf8)
        } catch { return Data("refused".utf8) }
    }
    func disconnect(_ id: UUID) {
        owner.disconnect(id)
        if sessions.current()?.state == .cancelled {
            try? FileHandle.standardOutput.write(contentsOf: Data("session-cancelled\n".utf8))
        }
        try? FileHandle.standardOutput.write(contentsOf: Data("disconnected\n".utf8))
    }
}

@main struct SessionListenerMain {
    @MainActor static func main() async throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count == 3 else { exit(64) }
        let host = SessionHost()
        let listener = try BrokerHandshakeListener(serviceName: args[0], peer: .developmentCDHash(args[1]),
            onDisconnect: { id in Task { @MainActor in host.disconnect(id) } },
            requestHandler: { context, data in await host.request(context, data) })
        try listener.start()
        try await Task.sleep(for: .seconds(20))
        listener.close()
    }
}
