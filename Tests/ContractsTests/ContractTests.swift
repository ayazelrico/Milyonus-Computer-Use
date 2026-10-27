import Foundation
import ComputerUseContracts

@MainActor
final class ContractTests: TestCase {
    func request(kind: ActionKind = .press, text: String? = nil) -> ActionRequest {
        ActionRequest(requestId: "request-1", sessionId: "session-1", idempotencyKey: "key-1", observationId: "obs-1",
                      generation: 1, elementId: "element-1", kind: kind, text: text)
    }
    func testPressRejectsText() { expectThrows(try request(text: "hidden payload").validate()) }
    func testSetValueRequiresText() { expectThrows(try request(kind: .setValue).validate()) }
    func testUnicodeInputRoundTrip() throws {
        let value = request(kind: .setValue, text: "İstanbul ıİ şğü 👩🏽‍💻 e\u{301}")
        try value.validate()
        expectEqual(try JSONDecoder().decode(ActionRequest.self, from: JSONEncoder().encode(value)), value)
    }
    func testUTF8LimitUsesBytes() { expectThrows(try request(kind: .setValue, text: String(repeating: "💻", count: 4097)).validate()) }
    func testNullRejected() { expectThrows(try request(kind: .setValue, text: "hello\0world").validate()) }
    func testPathLikeIdentifierRejected() {
        var value = request(); value.elementId = "../../secret"
        expectThrows(try value.validate())
    }
    func testZeroGenerationRejected() {
        var value = request(); value.generation = 0
        expectThrows(try value.validate())
    }
    func testUnknownActionRejected() throws {
        var object = try requireValue(JSONSerialization.jsonObject(with: JSONEncoder().encode(request())) as? [String: Any])
        object["kind"] = "shell"
        expectThrows(try JSONDecoder().decode(ActionRequest.self, from: JSONSerialization.data(withJSONObject: object)))
    }
    func testRetinaNegativeOriginAndCrop() throws {
        let transform = FrameTransform(desktopBounds: Rect(x: -1400, y: 200, width: 600, height: 400), pixelWidth: 1200, pixelHeight: 800)
        let point = try transform.desktopPoint(pixelX: 400, pixelY: 600)
        expectEqual(point.x, -1200); expectEqual(point.y, 500)
    }
    func testPixelBoundsAndNonfiniteRejected() {
        let transform = FrameTransform(desktopBounds: Rect(x: 0, y: 0, width: 10, height: 10), pixelWidth: 20, pixelHeight: 20)
        for pair in [(Double.nan, 0.0), (Double.infinity, 1.0), (-1.0, 0.0), (20.0, 0.0), (0.0, 20.0)] {
            expectThrows(try transform.desktopPoint(pixelX: pair.0, pixelY: pair.1))
        }
    }
    func testCoordinatePropertyAcrossScales() throws {
        for scale in [1, 2, 3] {
            for x in stride(from: 0, to: 600, by: 13) {
                let transform = FrameTransform(desktopBounds: Rect(x: -600, y: -400, width: 600, height: 400),
                                               pixelWidth: 600 * scale, pixelHeight: 400 * scale)
                let point = try transform.desktopPoint(pixelX: Double(x * scale), pixelY: Double(17 * scale))
                expectEqual(point.x, Double(x - 600)); expectEqual(point.y, -383)
            }
        }
    }
}
