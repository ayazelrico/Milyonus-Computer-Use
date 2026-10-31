import Foundation
import ComputerUseContracts

/// Separate fixed metadata protocol. The AX envelope and its size limit are unchanged.
package enum CaptureWorkerWire {
    private struct Request: Codable {
        var version = 1
        var kind = "fixture.capture.metadata"
        let ticket: ReadWorkerWire.Ticket
    }
    private struct Reply: Codable {
        var version = 1
        var kind = "fixture.capture.metadata.result"
        let ticket: ReadWorkerWire.Ticket
        let elapsedNanoseconds: Int64
        let metadata: CaptureWorkerMetadata?
        let error: HarnessError?
    }
    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(value)
        guard data.count <= 16384 else { throw HarnessError.resourceLimit }
        return data
    }
    private static func shape(_ data: Data, reply: Bool) throws {
        guard data.count <= 16384 else { throw HarnessError.resourceLimit }
        guard let root = try StrictJSON.object(data) as? [String: Any],
              let ticket = root["ticket"] as? [String: Any],
              Set(ticket.keys) == ["requestID", "incarnation", "connectionID", "sessionID", "generation",
                  "pid", "startSeconds", "startMicroseconds", "windowID", "timeoutNanoseconds"] else {
            throw HarnessError.protocolMismatch
        }
        if reply {
            guard Set(root.keys) == ["version", "kind", "ticket", "elapsedNanoseconds", "metadata"]
                || Set(root.keys) == ["version", "kind", "ticket", "elapsedNanoseconds", "error"] else {
                throw HarnessError.protocolMismatch
            }
            if let metadata = root["metadata"] as? [String: Any] {
                guard Set(metadata.keys) == ["windowID", "pixelWidth", "pixelHeight", "pngBytes", "sha256", "bounds", "capturedAt", "screenRecordingGranted"],
                      let bounds = metadata["bounds"] as? [String: Any], Set(bounds.keys) == ["x", "y", "width", "height"] else {
                    throw HarnessError.protocolMismatch
                }
            }
        } else {
            guard Set(root.keys) == ["version", "kind", "ticket"] else { throw HarnessError.protocolMismatch }
        }
    }
    private static func validate(_ ticket: ReadWorkerTicket) throws {
        try ReadWorkerWire.validate(ticket)
        guard ticket.target.windowID != nil else { throw HarnessError.invalidRequest }
    }
    private static func nanos(_ elapsed: Duration, ticket: ReadWorkerTicket) throws -> Int64 {
        guard elapsed >= .zero, elapsed < ticket.timeout else { throw HarnessError.protocolMismatch }
        let components = elapsed.components
        let value = components.seconds * 1_000_000_000 + components.attoseconds / 1_000_000_000
        // Measured clock durations may have sub-nanosecond components. Round down
        // only the elapsed report; request budgets retain exact validation.
        return value
    }
    package static func encodeRequest(_ ticket: ReadWorkerTicket) throws -> Data {
        try validate(ticket)
        return try encode(Request(ticket: ReadWorkerWire.Ticket(ticket)))
    }
    package static func decodeRequest(_ data: Data) throws -> ReadWorkerTicket {
        try shape(data, reply: false)
        let value = try JSONDecoder().decode(Request.self, from: data)
        guard value.version == 1, value.kind == "fixture.capture.metadata" else { throw HarnessError.protocolMismatch }
        let ticket = try value.ticket.decoded(); try validate(ticket)
        return ticket
    }
    package static func encodeReply(_ result: Result<CaptureWorkerReply, HarnessError>, ticket: ReadWorkerTicket) throws -> Data {
        try validate(ticket)
        switch result {
        case .success(let reply):
            guard reply.ticket == ticket else { throw HarnessError.protocolMismatch }
            try reply.metadata.validate(target: ticket.target)
            return try encode(Reply(ticket: ReadWorkerWire.Ticket(ticket), elapsedNanoseconds: nanos(reply.elapsed, ticket: ticket),
                                    metadata: reply.metadata, error: nil))
        case .failure(let error):
            return try encode(Reply(ticket: ReadWorkerWire.Ticket(ticket), elapsedNanoseconds: 0, metadata: nil, error: error))
        }
    }
    package static func decodeReply(_ data: Data, expected: ReadWorkerTicket) throws -> Result<CaptureWorkerReply, HarnessError> {
        try validate(expected); try shape(data, reply: true)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .millisecondsSince1970
        let value = try decoder.decode(Reply.self, from: data)
        let ticket = try value.ticket.decoded()
        guard ticket == expected, value.version == 1, value.kind == "fixture.capture.metadata.result" else {
            throw HarnessError.protocolMismatch
        }
        let elapsed = Duration.nanoseconds(value.elapsedNanoseconds)
        _ = try nanos(elapsed, ticket: ticket)
        if let error = value.error {
            guard value.metadata == nil else { throw HarnessError.protocolMismatch }
            return .failure(error)
        }
        guard let metadata = value.metadata else { throw HarnessError.protocolMismatch }
        try metadata.validate(target: ticket.target)
        return .success(CaptureWorkerReply(ticket: ticket, metadata: metadata, elapsed: elapsed))
    }
}
