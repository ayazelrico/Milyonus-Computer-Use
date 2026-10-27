import ComputerUseContracts
import ComputerUseCore

@MainActor
final class FixtureCaptureSelectionTests: TestCase {
    private func window(id: UInt32 = 42, pid: Int32? = 100,
                        bundle: String? = "com.milyonus.computeruse.fixture",
                        title: String? = "Computer Use Fixture", layer: Int = 0,
                        bounds: Rect = Rect(x: -100, y: 10, width: 620, height: 380)) -> FixtureCaptureWindow {
        FixtureCaptureWindow(windowID: id, processID: pid, bundleIdentifier: bundle,
                             title: title, layer: layer, bounds: bounds)
    }
    func testOnlyUniqueMainFixtureIsSelected() throws {
        let unrelated = [window(bundle: "another.app"), window(title: "Auxiliary"),
                         window(layer: 1), window(bundle: nil), window(title: nil)]
        expectThrows(try FixtureCaptureSelection.selectIndex(in: unrelated)) {
            expectEqual($0 as? HarnessError, .targetNotFound)
        }
        expectEqual(try FixtureCaptureSelection.selectIndex(in: unrelated + [window()]), unrelated.count)
        try FixtureCaptureSelection.validateCurrent([window()] + unrelated, expected: window())
        expectThrows(try FixtureCaptureSelection.selectIndex(in: [window(), window(id: 43)])) {
            expectEqual($0 as? HarnessError, .targetAmbiguous)
        }
        expectThrows(try FixtureCaptureSelection.selectIndex(in: [window(), window()])) {
            expectEqual($0 as? HarnessError, .targetAmbiguous)
        }
    }
    func testInvalidIdentityAndGeometryCannotBeSelected() {
        for invalid in [window(id: 0), window(pid: nil), window(pid: 0), window(pid: -1)] {
            expectThrows(try FixtureCaptureSelection.selectIndex(in: [invalid])) {
                expectEqual($0 as? HarnessError, .targetNotFound)
            }
        }
        for bounds in [Rect(x: .nan, y: 0, width: 1, height: 1),
                       Rect(x: 0, y: 0, width: 0, height: 1),
                       Rect(x: 1e308, y: 0, width: 1e308, height: 1)] {
            expectThrows(try FixtureCaptureSelection.selectIndex(in: [window(bounds: bounds)])) {
                expectEqual($0 as? HarnessError, .invalidRequest)
            }
        }
    }
    func testCaptureRejectsReplacementMovementAndNewAmbiguity() throws {
        let original = window()
        for current in [[FixtureCaptureWindow](), [window(id: 43)], [window(pid: 101)],
                        [window(bundle: "another.app")], [window(title: "Renamed")], [window(layer: 1)],
                        [window(bounds: Rect(x: -99, y: 10, width: 620, height: 380))],
                        [window(bounds: Rect(x: -100, y: 10, width: 621, height: 380))],
                        [original, window(id: 43)], [original, window(id: 43, pid: 101)]] {
            expectThrows(try FixtureCaptureSelection.validateCurrent(current, expected: original)) {
                expectEqual($0 as? HarnessError, .staleObservation)
            }
        }
        // Unrelated window churn and enumeration order do not invalidate the capture.
        try FixtureCaptureSelection.validateCurrent([window(id: 99, title: "Auxiliary"), original], expected: original)
        expectEqual(try FixtureCaptureSelection.selectIndex(in: [original]), 0)
    }
}
