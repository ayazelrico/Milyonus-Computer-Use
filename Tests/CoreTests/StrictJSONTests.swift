import Foundation
import ComputerUseContracts
import ComputerUseClient

@MainActor
final class StrictJSONTests: TestCase {
    func testDuplicateMembersRejectedAtEveryDepth() {
        for text in [
            #"{"id":1,"id":2}"#,
            #"{"id":1,"\u0069d":2}"#,
            #"{"result":{"isError":false,"isError":true}}"#,
            #"[{"error":"UNAUTHORIZED","error":"CANCELLED"}]"#,
            #"{"a":[{"x":0,"x":1}]}"#,
            #"{"é":1,"\u00e9":2}"#,
            #"{"a\"b":1,"a\"b":2}"#
        ] {
            expectThrows(try StrictJSON.object(Data(text.utf8))) {
                expectEqual($0 as? HarnessError, .protocolMismatch)
            }
        }
    }
    func testValidJSONStringsAndSiblingKeysPreserved() throws {
        for text in [
            #"{"left":{"id":1},"right":{"id":2}}"#,
            #"[{"id":1},{"id":2}]"#,
            #"{"text":"embedded \"id\":1, \"id\":2","slash":"\\","unicode":"\ud83d\ude00"}"#,
            #"{"empty":{},"list":[],"values":[null,true,false,-1,1.25,1e3]}"#,
            #"null"#, #"42"#, #""text""#
        ] {
            let data = Data(text.utf8)
            let strict = try StrictJSON.object(data)
            let baseline = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            expectEqual(try JSONSerialization.data(withJSONObject: strict, options: [.sortedKeys, .fragmentsAllowed]),
                        try JSONSerialization.data(withJSONObject: baseline, options: [.sortedKeys, .fragmentsAllowed]))
        }
    }
    func testNestingAndByteBounds() throws {
        _ = try StrictJSON.object(Data((String(repeating: "[", count: 64) + "null" + String(repeating: "]", count: 64)).utf8))
        expectThrows(try StrictJSON.object(Data((String(repeating: "[", count: 65) + "null" + String(repeating: "]", count: 65)).utf8))) {
            expectEqual($0 as? HarnessError, .resourceLimit)
        }
        expectThrows(try StrictJSON.object(Data(repeating: 32, count: HarnessProtocol.maximumMessageBytes + 1))) {
            expectEqual($0 as? HarnessError, .resourceLimit)
        }
    }
    func testMalformedSyntaxAndNonUTF8Rejected() {
        for text in ["", "{", "[1,]", "{\"a\":1,}", "{\"a\":}", "true false", "\"unterminated", "{a:1}"] {
            expectThrows(try StrictJSON.object(Data(text.utf8))) { expectEqual($0 as? HarnessError, .protocolMismatch) }
        }
        for bytes: [UInt8] in [[0xff, 0xfe, 0x7b, 0, 0x7d, 0], [49, 0], [0xff]] {
            expectThrows(try StrictJSON.object(Data(bytes))) { expectEqual($0 as? HarnessError, .protocolMismatch) }
        }
    }
    func testAmbiguousRequestsRejectedBeforeDispatch() throws {
        for text in [
            #"{"jsonrpc":"2.0","id":1,"method":"ping","method":"tools/call"}"#,
            #"{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"session_status","name":"session_open"}}"#,
            #"{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"desktop_action","arguments":{"generation":1,"generation":2}}}"#
        ] {
            expectThrows(try StrictJSON.object(Data(text.utf8))) {
                expectEqual($0 as? HarnessError, .protocolMismatch)
            }
        }
        let text = #"{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"session_status","arguments":{}}}"#
        let object = try requireValue(StrictJSON.object(Data(text.utf8)) as? [String: Any])
        expectEqual(object["method"] as? String, "tools/call")
    }

}
