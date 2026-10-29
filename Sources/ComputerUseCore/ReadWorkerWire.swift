import Foundation
import ComputerUseContracts

/// Private fixed-operation wire values. Decode only after peer authentication;
/// a ticket carries scope/correlation, never approval or a command to execute.
package enum ReadWorkerWire {
    private struct Ticket: Codable {
        let requestID: UUID, incarnation: UUID, connectionID: UUID
        let sessionID: String
        let generation: Int
        let pid: Int32
        let startSeconds: Int64
        let startMicroseconds: Int32
        let windowID: UInt32?
        let timeoutNanoseconds: Int64

        init(_ value: ReadWorkerTicket) throws {
            requestID = value.requestID; incarnation = value.incarnation; connectionID = value.connectionID
            sessionID = value.sessionID; generation = value.generation
            pid = value.target.pid; startSeconds = value.target.startSeconds
            startMicroseconds = value.target.startMicroseconds; windowID = value.target.windowID
            timeoutNanoseconds = try nanoseconds(value.timeout)
            guard Duration.nanoseconds(timeoutNanoseconds) == value.timeout else { throw HarnessError.invalidRequest }
            _ = try decoded()
        }

        func decoded() throws -> ReadWorkerTicket {
            guard (1...10_000_000_000).contains(timeoutNanoseconds) else { throw HarnessError.protocolMismatch }
            let metadata = Session(id: sessionID, bundleId: SessionController.fixtureBundleID,
                                   generation: generation, state: .ready, expiresAt: Date(timeIntervalSince1970: 0))
            try metadata.validate() // Metadata consistency only; no grant is created.
            let target = try ReadWorkerTarget(pid: pid, startSeconds: startSeconds,
                                             startMicroseconds: startMicroseconds, windowID: windowID)
            return ReadWorkerTicket(requestID: requestID, incarnation: incarnation, connectionID: connectionID,
                                    sessionID: sessionID, generation: generation, target: target,
                                    timeout: .nanoseconds(timeoutNanoseconds))
        }
    }
    private struct Request: Codable {
        var version = 1
        var kind = "fixture.ax.observe"
        let ticket: Ticket
    }
    private struct Reply: Codable {
        var version = 1
        var kind = "fixture.ax.result"
        let ticket: Ticket
        let elapsedNanoseconds: Int64
        let observation: Observation?
        let error: HarnessError?
    }

    private static func nanoseconds(_ value: Duration) throws -> Int64 {
        guard value >= .zero, value <= .seconds(10) else { throw HarnessError.protocolMismatch }
        let parts = value.components
        return parts.seconds * 1_000_000_000 + parts.attoseconds / 1_000_000_000
    }

    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(value)
        _ = try StrictJSON.object(data)
        return data
    }

    private static func validateShape(_ data: Data, reply: Bool) throws {
        guard let root = try StrictJSON.object(data) as? [String: Any],
              let ticket = root["ticket"] as? [String: Any] else { throw HarnessError.protocolMismatch }
        let required: Set<String> = ["requestID", "incarnation", "connectionID", "sessionID", "generation",
                                     "pid", "startSeconds", "startMicroseconds", "timeoutNanoseconds"]
        let keys = Set(ticket.keys)
        guard required.isSubset(of: keys), keys.isSubset(of: required.union(["windowID"])) else {
            throw HarnessError.protocolMismatch
        }
        let rootKeys = Set(root.keys)
        if reply {
            guard rootKeys == ["version", "kind", "ticket", "elapsedNanoseconds", "observation"]
                    || rootKeys == ["version", "kind", "ticket", "elapsedNanoseconds", "error"] else {
                throw HarnessError.protocolMismatch
            }
        } else {
            guard rootKeys == ["version", "kind", "ticket"] else { throw HarnessError.protocolMismatch }
        }
    }

    package static func encodeRequest(_ ticket: ReadWorkerTicket) throws -> Data {
        try encode(Request(ticket: Ticket(ticket)))
    }

    package static func validate(_ ticket: ReadWorkerTicket) throws { _ = try Ticket(ticket) }

    package static func decodeRequest(_ data: Data) throws -> ReadWorkerTicket {
        try validateShape(data, reply: false)
        let value = try JSONDecoder().decode(Request.self, from: data)
        guard value.version == 1, value.kind == "fixture.ax.observe" else { throw HarnessError.protocolMismatch }
        return try value.ticket.decoded()
    }

    package static func encodeReply(_ result: Result<ReadWorkerReply, HarnessError>, ticket: ReadWorkerTicket) throws -> Data {
        let body = try Ticket(ticket)
        switch result {
        case .success(let value):
            guard value.ticket == ticket else { throw HarnessError.protocolMismatch }
            try value.observation.validate()
            return try encode(Reply(ticket: body, elapsedNanoseconds: nanoseconds(value.elapsed),
                                    observation: value.observation, error: nil))
        case .failure(let error):
            return try encode(Reply(ticket: body, elapsedNanoseconds: 0, observation: nil, error: error))
        }
    }

    package static func decodeReply(_ data: Data, expected: ReadWorkerTicket) throws -> Result<ReadWorkerReply, HarnessError> {
        try validateShape(data, reply: true)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .millisecondsSince1970
        let value = try decoder.decode(Reply.self, from: data)
        let ticket = try value.ticket.decoded()
        guard value.version == 1, value.kind == "fixture.ax.result", ticket == expected,
              value.elapsedNanoseconds >= 0,
              value.elapsedNanoseconds < (try nanoseconds(ticket.timeout)) else { throw HarnessError.protocolMismatch }
        if let error = value.error {
            guard value.observation == nil else { throw HarnessError.protocolMismatch }
            return .failure(error)
        }
        guard let observation = value.observation, observation.pid == ticket.target.pid,
              observation.sessionId == ticket.sessionID,
              observation.bundleId == SessionController.fixtureBundleID else { throw HarnessError.protocolMismatch }
        try observation.validate()
        return .success(ReadWorkerReply(ticket: ticket, observation: observation,
                                         elapsed: .nanoseconds(value.elapsedNanoseconds)))
    }
}
