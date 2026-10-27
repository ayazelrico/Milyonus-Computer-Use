import Foundation
import ComputerUseContracts
import ComputerUseClient

@MainActor
final class ToolReplyTests: TestCase {
    func testMalformedToolEnvelopesRejected() throws {
        let text: [String: Any] = ["type": "text", "text": "null"]
        let variants: [[String: Any]] = [
            [:], ["content": []], ["content": [text, text]],
            ["content": [["text": "null"]]],
            ["content": [["type": "text", "text": 42]]],
            ["content": [text], "isError": 0],
            ["content": [text], "isError": 1],
            ["content": [text], "isError": "false"],
            ["content": [text], "isError": NSNull()],
            ["content": [text], "isError": true],
            ["content": [["type": "text", "text": "{\"error\":\"UNKNOWN\"}"]], "isError": true]
        ]
        for variant in variants {
            let bytes = try JSONSerialization.data(withJSONObject: variant)
            expectThrows(try ToolReply.decode(bytes)) { expectEqual($0 as? HarnessError, .protocolMismatch) }
        }
    }
    func testValueAndDomainFailureRemainDistinct() throws {
        for raw in [
            "{\"content\":[{\"type\":\"text\",\"text\":\"null\"}]}",
            "{\"content\":[{\"type\":\"text\",\"text\":\"null\"}],\"isError\":false}"
        ] {
            if case .value(let payload) = try ToolReply.decode(Data(raw.utf8)) {
                expectEqual(String(decoding: payload, as: UTF8.self), "null")
            } else { fail("Expected value") }
        }
        // Even a domain PROTOCOL_MISMATCH is kept distinct from invalid wire encoding.
        let envelope: [String: Any] = ["content": [["type": "text", "text": "{\"error\":\"PROTOCOL_MISMATCH\"}"]],
                                       "isError": true]
        if case .failure(let error) = try ToolReply.decode(JSONSerialization.data(withJSONObject: envelope)) {
            expectEqual(error, .protocolMismatch)
        } else { fail("Expected domain failure") }
    }
}
