import Foundation
import CoreFoundation
import ComputerUseContracts

/// The local companion contract carries one JSON value in one text content block.
/// This is intentionally narrower than a general-purpose MCP content renderer.
package enum ToolReply {
    case value(Data)
    case failure(HarnessError)

    package static func decode(_ data: Data) throws -> ToolReply {
        guard let result = try? StrictJSON.object(data) as? [String: Any],
              let content = result["content"] as? [[String: Any]], content.count == 1,
              content[0]["type"] as? String == "text",
              let text = content[0]["text"] as? String else { throw HarnessError.protocolMismatch }
        var isError = false
        if let flag = result["isError"] {
            guard let number = flag as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else {
                throw HarnessError.protocolMismatch
            }
            isError = number.boolValue
        }
        let payload = Data(text.utf8)
        if isError {
            guard let object = try? StrictJSON.object(payload) as? [String: String],
                  let code = object["error"], let error = HarnessError(rawValue: code) else {
                throw HarnessError.protocolMismatch
            }
            return .failure(error)
        }
        return .value(payload)
    }
}
