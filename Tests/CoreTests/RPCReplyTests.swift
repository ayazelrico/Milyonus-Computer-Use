import Foundation
import ComputerUseContracts
import ComputerUseClient

@MainActor
final class RPCReplyTests: TestCase {
    func testInvalidIDsCannotConsumePendingRequest() {
        for id in ["true", "false", "1.5", "\"1\"", "null", "0", "-1", "9223372036854775808"] {
            expectThrows(try RPCReply.decode(Data("{\"jsonrpc\":\"2.0\",\"id\":\(id),\"result\":{}}".utf8))) {
                expectEqual($0 as? HarnessError, .protocolMismatch)
            }
        }
    }
    func testMalformedEnvelopesRejected() {
        for text in [
            "invalid", "[]", "{}", "{\"jsonrpc\":\"1.0\",\"id\":1,\"result\":{}}",
            "{\"jsonrpc\":\"2.0\",\"id\":1}",
            "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{},\"error\":{}}",
            "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"request\",\"result\":{}}",
            "{\"jsonrpc\":\"2.0\",\"id\":1,\"error\":{\"code\":true,\"message\":\"invalid\"}}",
            "{\"jsonrpc\":\"2.0\",\"result\":{}}",
            "{\"jsonrpc\":\"2.0\",\"method\":\"notice\",\"result\":{}}"
        ] {
            expectThrows(try RPCReply.decode(Data(text.utf8))) { expectEqual($0 as? HarnessError, .protocolMismatch) }
        }
    }
    func testValidRepliesAndNotifications() throws {
        if case .result(let id, let data) = try RPCReply.decode(Data("{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":null}".utf8)) {
            expectEqual(id, 1); expectEqual(String(decoding: data, as: UTF8.self), "null")
        } else { fail("Expected result") }
        if case .failure(let id) = try RPCReply.decode(Data("{\"jsonrpc\":\"2.0\",\"id\":2,\"error\":{\"code\":-32600,\"message\":\"Invalid request\"}}".utf8)) {
            expectEqual(id, 2)
        } else { fail("Expected RPC failure") }
        if case .notification = try RPCReply.decode(Data("{\"jsonrpc\":\"2.0\",\"method\":\"notice\",\"params\":{}}".utf8)) {
            expectEqual(true, true)
        } else { fail("Expected notification") }
    }
}
