import ComputerUseContracts
import ComputerUseCore

@MainActor
final class PointerGestureTests: TestCase {
    let region = PointerGesture.Region(origin: .init(x: -100, y: 10), width: 200, height: 100)
    func testDragGeometryAndTiming() throws {
        let steps = try PointerGesture.drag(from: .init(x: -90, y: 20), to: .init(x: 90, y: 100),
                                            within: region, durationMilliseconds: 307, segments: 20)
        expectEqual(steps.count, 23)
        expectEqual(steps.first?.event, .move(x: -90, y: 20))
        expectEqual(steps.last?.event, .mouseUp(x: 90, y: 100))
        expectEqual(steps.map(\.delayAfterMilliseconds).reduce(0, +), 307)
        for step in steps.dropFirst(2).dropLast() {
            guard case .drag(let x, let y) = step.event else { fail("Expected drag"); continue }
            expectEqual((-90...90).contains(x) && (20...100).contains(y), true)
        }
    }
    func testInvalidGeometryAndBudgets() {
        for point in [PointerGesture.Point(x: .nan, y: 20), .init(x: 100, y: 20), .init(x: 0, y: 110)] {
            expectThrows(try PointerGesture.drag(from: point, to: .init(x: 0, y: 50), within: region))
        }
        for (duration, segments) in [(0, 20), (2001, 20), (300, 0), (300, 121), (1, 20), (2000, 1)] {
            expectThrows(try PointerGesture.drag(from: .init(x: 0, y: 20), to: .init(x: 0, y: 50),
                                                within: region, durationMilliseconds: duration, segments: segments))
        }
        expectThrows(try PointerGesture.scroll(at: .init(x: 0, y: 20), within: region, vertical: .min, horizontal: 0))
        expectThrows(try PointerGesture.scroll(at: .init(x: 0, y: 20), within: region, vertical: 0, horizontal: 0))
    }
    func testScrollConservesSignedDeltas() throws {
        for (vertical, horizontal): (Int32, Int32) in [(2000, -1999), (-101, 1), (1, 0), (0, -2000)] {
            let steps = try PointerGesture.scroll(at: .init(x: 0, y: 20), within: region,
                                                 vertical: vertical, horizontal: horizontal)
            var v: Int32 = 0; var h: Int32 = 0
            for step in steps.dropFirst() {
                guard case .scroll(let dv, let dh) = step.event else { fail("Expected scroll"); continue }
                expectEqual(abs(dv) <= 100 && abs(dh) <= 100, true)
                v += dv; h += dh
            }
            expectEqual(v, vertical); expectEqual(h, horizontal)
        }
    }
    func testDragRevocationReleasesAtLastPosition() async throws {
        let steps = try PointerGesture.drag(from: .init(x: 0, y: 20), to: .init(x: 0, y: 80),
                                            within: region, durationMilliseconds: 3, segments: 3)
        let emitter = RecordingEmitter()
        var calls = 0
        do {
            try await InputSequenceExecutor(emitter: emitter).execute(steps) {
                calls += 1
                if calls == 4 { throw HarnessError.permissionRevoked }
            }
            fail("Revocation was ignored")
        } catch { expectEqual(error as? HarnessError, .permissionRevoked) }
        expectEqual(emitter.events, [.move(x: 0, y: 20), .mouseDown(x: 0, y: 20),
                                     .drag(x: 0, y: 40), .mouseUp(x: 0, y: 40)])
    }
}
