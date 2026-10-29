import AppKit
import CryptoKit
import ComputerUseContracts
import ComputerUseMacOS

@main struct CaptureClient {
    @MainActor static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args == ["absent"] || args == ["marker"] || args == ["ambiguous"] else { exit(64) }
        var record: [String: Any] = ["status": "failed", "imageWrittenToDisk": false,
            "imageSentToProvider": false, "permissionRequested": false]
        do {
            record["screenRecordingGranted"] = CGPreflightScreenCaptureAccess()
            if args[0] != "absent" {
                let deadline = ContinuousClock.now.advanced(by: .seconds(5))
                var inventory: [[String: String]] = []
                repeat {
                    inventory = try await ScreenCapture.fixtureWindowInventory()
                    if inventory.filter( { $0["title"] == "Computer Use Fixture" && $0["layer"] == "0"
                        && $0["onScreen"] == "true" && (Double($0["width"] ?? "") ?? 0) > 0
                        && (Double($0["height"] ?? "") ?? 0) > 0 }).count >= (args[0] == "ambiguous" ? 2 : 1) { break }
                    try await Task.sleep(for: .milliseconds(100))
                } while ContinuousClock.now < deadline
                record["fixtureWindowInventory"] = inventory
            }
            let frame: CapturedFrame
            do { frame = try await ScreenCapture.captureFixture() }
            catch {
                let expected: HarnessError = args[0] == "ambiguous" ? .targetAmbiguous : .targetNotFound
                if args[0] != "marker", error as? HarnessError == expected {
                    record["status"] = args[0] == "ambiguous" ? "passed-ambiguous-fixture" : "passed-absent-fixture"
                    record["refusal"] = expected.rawValue
                    emit(record, success: true)
                }
                throw error
            }
            guard args[0] == "marker", let bitmap = NSBitmapImageRep(data: frame.png),
                  bitmap.pixelsWide == frame.transform.pixelWidth,
                  bitmap.pixelsHigh == frame.transform.pixelHeight else { throw HarnessError.verificationFailed }
            // Decode locally and verify the fixture's three adjacent solid-color
            // patches. This checks rendered content, not a model's description.
            var match: (Int, Int)?
            let scaleX = Double(bitmap.pixelsWide) / frame.transform.desktopBounds.width
            let patch = Int((40 * scaleX).rounded())
            guard patch >= 8, patch <= 256 else { throw HarnessError.verificationFailed }
            func matches(_ x: Int, _ y: Int, _ channel: Int) -> Bool {
                guard x >= 0, x < bitmap.pixelsWide, y >= 0, y < bitmap.pixelsHigh,
                      let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return false }
                let values = [color.redComponent, color.greenComponent, color.blueComponent]
                let dominant = values[channel]
                // Verify marker identity and adjacency, not display-profile color fidelity.
                return dominant > 0.8 && values.enumerated().allSatisfy {
                    $0.offset == channel || dominant - $0.element > 0.4
                }
            }
            for y in stride(from: 4, to: bitmap.pixelsHigh - 4, by: 4) {
                for x in stride(from: 4, to: bitmap.pixelsWide - 2 * patch - 4, by: 4) {
                    if (0..<3).allSatisfy({ channel in
                        [-3, 0, 3].allSatisfy { dx in
                            [-3, 0, 3].allSatisfy { dy in matches(x + channel * patch + dx, y + dy, channel) }
                        }
                    }) { match = (x, y); break }
                }
                if match != nil { break }
            }
            record["decodedPixelWidth"] = bitmap.pixelsWide
            record["decodedPixelHeight"] = bitmap.pixelsHigh
            record["expectedPatchPixels"] = patch
            var colorCounts = [0, 0, 0]
            for y in stride(from: 0, to: bitmap.pixelsHigh, by: 4) {
                for x in stride(from: 0, to: bitmap.pixelsWide, by: 4) {
                    for channel in 0..<3 where matches(x, y, channel) { colorCounts[channel] += 1 }
                }
            }
            record["markerColorSampleCounts"] = colorCounts
            record["colorFidelityAccepted"] = false
            record["markerRule"] = "dominant channel > 0.8, separation > 0.4, three adjacent 3x3 patches"
            record["diagnosticSamples"] = [0.43, 0.5, 0.56].map { fraction -> [String: Any] in
                let x = Int(Double(bitmap.pixelsWide) * fraction), y = Int(Double(bitmap.pixelsHigh) * 0.8)
                guard let c = bitmap.colorAt(x: x, y: y) else { return ["color": "missing"] }
                guard let rgb = c.usingColorSpace(.sRGB) else { return ["colorSpace": c.colorSpace.description] }
                return ["red": rgb.redComponent, "green": rgb.greenComponent, "blue": rgb.blueComponent, "alpha": rgb.alphaComponent]
            }
            guard let match else { throw HarnessError.verificationFailed }
            record["status"] = "passed-fixture-marker"
            record["windowID"] = frame.windowID
            record["pixelWidth"] = bitmap.pixelsWide
            record["pixelHeight"] = bitmap.pixelsHigh
            record["markerPixelX"] = match.0; record["markerPixelY"] = match.1
            record["pngBytes"] = frame.png.count
            record["sha256"] = SHA256.hash(data: frame.png).map { String(format: "%02x", $0) }.joined()
            record["desktopBounds"] = ["x": frame.transform.desktopBounds.x, "y": frame.transform.desktopBounds.y,
                "width": frame.transform.desktopBounds.width, "height": frame.transform.desktopBounds.height]
            emit(record, success: true)
        } catch {
            record["error"] = (error as? HarnessError)?.rawValue ?? String(describing: type(of: error))
            emit(record, success: false)
        }
    }
    static func emit(_ record: [String: Any], success: Bool) -> Never {
        print(String(decoding: (try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])) ?? Data("{}".utf8), as: UTF8.self))
        exit(success ? 0 : 1)
    }
}
