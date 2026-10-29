import AppKit
import Darwin
import CryptoKit
import ComputerUseContracts
import ComputerUseMacOS

@main struct CaptureClient {
    @MainActor static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        let transition = ["move", "resize", "close", "cancel", "deadline"].contains(args.first ?? "")
        guard (args.count == 1 && ["absent", "marker", "ambiguous"].contains(args[0]))
            || (transition && args.count == 2 && Int32(args[1]) != nil) else { exit(64) }
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
            do {
                if transition {
                    let ownedPID = Int32(args[1])!
                    var initial = proc_bsdinfo()
                    let size = Int32(MemoryLayout<proc_bsdinfo>.size)
                    guard ownedPID > 0, proc_pidinfo(ownedPID, PROC_PIDTBSDINFO, 0, &initial, size) == size,
                          initial.pbi_ppid == UInt32(getppid()) else { throw HarnessError.unauthorized }
                    frame = try await ScreenCapture.captureFixture { pid, windowID, bounds in
                        var current = proc_bsdinfo()
                        guard pid == ownedPID, proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &current, size) == size,
                              current.pbi_ppid == initial.pbi_ppid,
                              current.pbi_start_tvsec == initial.pbi_start_tvsec,
                              current.pbi_start_tvusec == initial.pbi_start_tvusec else { throw HarnessError.unauthorized }
                        record["imageReturnedBeforeTransitionUptime"] = ProcessInfo.processInfo.systemUptime
                        record["targetPID"] = pid; record["targetWindowID"] = windowID
                        record["expectedBounds"] = ["x": bounds.x, "y": bounds.y, "width": bounds.width, "height": bounds.height]
                        if args[0] == "cancel" || args[0] == "deadline" {
                            if args[0] == "cancel" {
                                withUnsafeCurrentTask { $0?.cancel() }
                            } else {
                                try await Task.sleep(for: .seconds(10))
                            }
                            record["transitionObservedUptime"] = ProcessInfo.processInfo.systemUptime
                            record["transitionObserved"] = true
                            return
                        }
                        guard kill(pid, args[0] == "close" ? SIGUSR1 : SIGUSR2) == 0 else { throw HarnessError.targetNotFound }
                        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
                        var observed = false
                        repeat {
                            let windows = try await ScreenCapture.fixtureWindowInventory()
                            let same = windows.first { $0["id"] == String(windowID) && $0["pid"] == String(pid) }
                            if args[0] == "close" {
                                observed = same == nil
                            } else if args[0] == "resize", let same,
                                      let width = Double(same["width"] ?? ""), let height = Double(same["height"] ?? "") {
                                observed = abs(width - bounds.width) >= 40 && abs(height - bounds.height) >= 30
                                if observed { record["observedBounds"] = same }
                            } else if let same, let x = Double(same["x"] ?? ""), let y = Double(same["y"] ?? "") {
                                observed = abs(x - bounds.x) >= 40 || abs(y - bounds.y) >= 20
                                if observed { record["observedBounds"] = same }
                            }
                            if observed { break }
                            try await Task.sleep(for: .milliseconds(20))
                        } while ContinuousClock.now < deadline
                        guard observed else { throw HarnessError.timeout }
                        record["transitionObservedUptime"] = ProcessInfo.processInfo.systemUptime
                        record["transitionObserved"] = true
                    }
                } else { frame = try await ScreenCapture.captureFixture() }
            }
            catch {
                if args[0] == "cancel", error is CancellationError,
                   record["transitionObserved"] as? Bool == true {
                    record["status"] = "passed-cancel-before-publication"
                    record["refusal"] = "CancellationError"
                    record["framePublished"] = false
                    record["refusalObservedUptime"] = ProcessInfo.processInfo.systemUptime
                    record["boundary"] = "after-framework-image-before-final-revalidation"
                    emit(record, success: true)
                }
                let expected: HarnessError = args[0] == "deadline" ? .timeout : transition ? .staleObservation : args[0] == "ambiguous" ? .targetAmbiguous : .targetNotFound
                if args[0] != "marker", error as? HarnessError == expected {
                    if transition {
                        guard record["transitionObserved"] as? Bool == true else { throw error }
                        record["refusalObservedUptime"] = ProcessInfo.processInfo.systemUptime
                        record["framePublished"] = false
                        record["boundary"] = "after-framework-image-before-final-revalidation"
                    }
                    record["status"] = transition ? "passed-" + args[0] + "-before-publication" : args[0] == "ambiguous" ? "passed-ambiguous-fixture" : "passed-absent-fixture"
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
