import Foundation
import Security
import Darwin
import ComputerUseContracts
import ComputerUseCore
import ComputerUseMacOS
import ComputerUseIPC

/// Development-only same-executable role. The peer requirement is derived from
/// the loaded image, never from argv, RPC, environment or observation content.
package enum FixtureWorkerIdentity {
    package static func current() throws -> BrokerPeerIdentity {
        var code: SecCode?, image: SecStaticCode?, info: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &image) == errSecSuccess, let image,
              SecCodeCopySigningInformation(image, [], &info) == errSecSuccess,
              let hash = (info as? [String: Any])?[kSecCodeInfoUnique as String] as? Data,
              hash.count == 20 else { throw HarnessError.unauthorized }
        return try .developmentCDHash(hash.map { String(format: "%02x", $0) }.joined())
    }
}

package enum FixtureWorkerRuntime {
    package static let role = "--fixture-read-worker-v1"
    package static let next = Data("fixture-read-next-v1".utf8)

    @MainActor package static func run(arguments: [String]) async throws {
        guard arguments.count == 3, arguments[0] == role,
              let parent = Int32(arguments[2]), parent > 0, getppid() == parent,
              BrokerPeerIdentity.validIdentifier(arguments[1]) else { throw HarnessError.unauthorized }
        let peer = try FixtureWorkerIdentity.current()
        // A stalled AX call must not keep an orphan alive indefinitely. Broker
        // cancellation/deadline remains the authoritative shorter boundary.
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 20) { exit(70) }
        let channel = AuthenticatedBrokerConnection()
        defer { channel.close() }
        let bootstrapDeadline = ContinuousClock.now.advanced(by: .seconds(2))
        while true {
            guard getppid() == parent else { throw HarnessError.unauthorized }
            do {
                try await channel.connect(serviceName: arguments[1], peer: peer,
                                          expectedProcessIdentifier: parent, timeoutSeconds: 1)
                break
            } catch {
                channel.close()
                guard (error as? BrokerConnectionError) == .authenticationFailed,
                      ContinuousClock.now < bootstrapDeadline else { throw error }
                // Only the public nonce is retried while the parent publishes
                // the selected PID. No ticket, observation or action is replayed.
                try await Task.sleep(for: .milliseconds(20))
            }
        }
        guard getppid() == parent else { throw HarnessError.unauthorized }
        let request = try await channel.request(next, timeoutSeconds: 3)
        let ticket = try ReadWorkerWire.decodeRequest(request)
        guard getppid() == parent else { throw HarnessError.unauthorized }
        let result: Result<ReadWorkerReply, HarnessError>
        do { result = .success(try FixtureReadWorker.collect(ticket)) }
        catch { result = .failure((error as? HarnessError) ?? .protocolMismatch) }
        let data = try ReadWorkerWire.encodeReply(result, ticket: ticket)
        guard getppid() == parent else { throw HarnessError.unauthorized }
        // The broker may terminate this read-only role as soon as it accepts the
        // result. Losing the acknowledgement never causes a result/action retry.
        _ = try await channel.request(data, timeoutSeconds: 3)
    }
}
