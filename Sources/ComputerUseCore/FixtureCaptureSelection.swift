import ComputerUseContracts

/// Value snapshot of the metadata needed to admit a fixture capture. This does
/// not authenticate a process or authorize input, and carries no window pixels.
package struct FixtureCaptureWindow: Sendable, Equatable {
    package let windowID: UInt32
    package let processID: Int32?
    package let bundleIdentifier: String?
    package let title: String?
    package let layer: Int
    package let bounds: Rect

    package init(windowID: UInt32, processID: Int32?, bundleIdentifier: String?, title: String?, layer: Int, bounds: Rect) {
        self.windowID = windowID; self.processID = processID
        self.bundleIdentifier = bundleIdentifier; self.title = title
        self.layer = layer; self.bounds = bounds
    }
}

package enum FixtureCaptureSelection {
    /// Select from the complete enumeration so auxiliary windows can never be
    /// mistaken for the main fixture and multiple eligible windows fail closed.
    package static func selectIndex(in windows: [FixtureCaptureWindow]) throws -> Int {
        var selected: Int?
        for index in windows.indices {
            let window = windows[index]
            guard window.bundleIdentifier == "com.milyonus.computeruse.fixture",
                  window.title == "Computer Use Fixture", window.layer == 0 else { continue }
            guard selected == nil else { throw HarnessError.targetAmbiguous }
            selected = index
        }
        guard let selected, let pid = windows[selected].processID, pid > 0,
              windows[selected].windowID != 0 else { throw HarnessError.targetNotFound }
        guard windows[selected].bounds.isValid else { throw HarnessError.invalidRequest }
        return selected
    }

    package static func validateCurrent(_ windows: [FixtureCaptureWindow], expected: FixtureCaptureWindow) throws {
        guard let index = try? selectIndex(in: windows), windows[index] == expected else {
            throw HarnessError.staleObservation
        }
    }
}
