import Foundation
import CoreFoundation
import ComputerUseContracts

/// Validates envelopes before any pending continuation is consumed.
package enum RPCReply {
    case notification
    case result(Int, Data)
    case failure(Int)

    package static func decode(_ data: Data) throws -> RPCReply {
        guard let message = try? StrictJSON.object(data) as? [String: Any],
              message["jsonrpc"] as? String == "2.0" else { throw HarnessError.protocolMismatch }
        if message["id"] == nil {
            guard message["method"] is String, message["result"] == nil, message["error"] == nil else {
                throw HarnessError.protocolMismatch
            }
            return .notification
        }
        guard message["method"] == nil, let number = message["id"] as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              let id = message["id"] as? Int, id > 0,
              number == NSNumber(value: id),
              (message["result"] != nil) != (message["error"] != nil) else { throw HarnessError.protocolMismatch }
        if let result = message["result"] {
            return .result(id, try JSONSerialization.data(withJSONObject: result, options: .fragmentsAllowed))
        }
        guard let error = message["error"] as? [String: Any],
              let code = error["code"] as? NSNumber,
              CFGetTypeID(code) != CFBooleanGetTypeID(),
              let integer = error["code"] as? Int, code == NSNumber(value: integer),
              error["message"] is String else { throw HarnessError.protocolMismatch }
        return .failure(id)
    }
}
