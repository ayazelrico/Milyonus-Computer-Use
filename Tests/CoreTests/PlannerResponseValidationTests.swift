import Foundation
import ComputerUseContracts

@MainActor
final class PlannerResponseValidationTests: TestCase {
    func openAI(_ text: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["status": "completed", "output": [["type": "message", "role": "assistant",
            "status": "completed", "content": [["type": "output_text", "text": text]]]]])
    }
    func anthropic(_ input: String) -> Data {
        Data(("{\"type\":\"message\",\"role\":\"assistant\",\"stop_reason\":\"tool_use\",\"content\":[{\"type\":\"tool_use\",\"name\":\"propose_fixture_step\",\"input\":" + input + "}]}").utf8)
    }
    func testOpenAIDuplicateMembersRejectedAtBothJSONLayers() async throws {
        let valid = #"{"type":"finish","elementIdentifier":null,"text":null}"#
        let outer = try openAI(valid)
        let duplicates = [
            Data(("{\"status\":\"incomplete\"," + String(decoding: outer.dropFirst(), as: UTF8.self)).utf8),
            try openAI(#"{"type":"press","type":"finish","elementIdentifier":null,"text":null}"#),
            try openAI(#"{"type":"finish","ty\u0070e":"finish","elementIdentifier":null,"text":null}"#),
            try openAI(#"{"type":"finish","elementIdentifier":null,"text":null,"text":null}"#)
        ]
        for body in duplicates { try await ProviderTests().assertError(.providerResponseInvalid, body: body) }
    }
    func testAnthropicDuplicateMembersRejectedInEnvelopeAndInput() async throws {
        let valid = #"{"type":"finish","elementIdentifier":null,"text":null}"#
        let outer = anthropic(valid)
        let duplicates = [
            Data(("{\"stop_reason\":\"refusal\"," + String(decoding: outer.dropFirst(), as: UTF8.self)).utf8),
            anthropic(#"{"type":"press","type":"finish","elementIdentifier":null,"text":null}"#),
            anthropic(#"{"type":"finish","ty\u0070e":"finish","elementIdentifier":null,"text":null}"#),
            anthropic(#"{"type":"finish","elementIdentifier":null,"text":null,"text":null}"#)
        ]
        for body in duplicates { try await AnthropicProviderTests().assertError(.providerResponseInvalid, body: body) }
    }
    func testDeepIgnoredMetadataCannotBypassBounds() async throws {
        let nested = String(repeating: "[", count: 70) + "0" + String(repeating: "]", count: 70)
        let valid = #"{"type":"finish","elementIdentifier":null,"text":null}"#
        let open = try openAI(valid), anthropicBody = anthropic(valid)
        for (isAnthropic, body) in [(false, open), (true, anthropicBody)] {
            let deep = Data(("{\"unused\":" + nested + "," + String(decoding: body.dropFirst(), as: UTF8.self)).utf8)
            if isAnthropic { try await AnthropicProviderTests().assertError(.providerResponseInvalid, body: deep) }
            else { try await ProviderTests().assertError(.providerResponseInvalid, body: deep) }
        }
    }
}
