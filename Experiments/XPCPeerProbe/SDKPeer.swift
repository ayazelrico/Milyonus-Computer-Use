import Foundation
import ComputerUseIPC

// Independent read-only peer for the real SDK handshake. No desktop APIs or session methods.
final class SDKPeer: NSObject, NSXPCListenerDelegate, BrokerHandshake {
    let identity: BrokerPeerIdentity
    let mode: String
    var connections: [NSXPCConnection] = []
    init(identity: BrokerPeerIdentity, mode: String) { self.identity = identity; self.mode = mode }
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.setCodeSigningRequirement(identity.requirement)
        connection.exportedInterface = NSXPCInterface(with: BrokerHandshake.self)
        connection.exportedObject = self
        connections.append(connection)
        connection.resume()
        return true
    }
    func hello(_ nonce: String, reply: @escaping (String, Int) -> Void) {
        try? FileHandle.standardOutput.write(contentsOf: Data("hello\n".utf8))
        if mode == "silent" { return }
        reply(mode == "wrongNonce" ? "wrong" : nonce, mode == "wrongVersion" ? 2 : 1)
        if mode == "disconnect" { DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { exit(0) } }
    }
}

@main struct PeerMain {
    static func main() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count == 3 else { exit(64) }
        let peer = SDKPeer(identity: try .developmentCDHash(args[1]), mode: args[2])
        let listener = NSXPCListener(machServiceName: args[0])
        listener.delegate = peer
        listener.resume()
        let deadline = ContinuousClock.now.advanced(by: .seconds(20))
        withExtendedLifetime(peer) {
            while ContinuousClock.now < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
        }
        listener.invalidate()
        peer.connections.forEach { $0.invalidate() }
    }
}
