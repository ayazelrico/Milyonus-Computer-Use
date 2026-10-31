import Foundation
import ComputerUseContracts
import ComputerUseCore
import ComputerUseMacOS
import ComputerUseWorker

@MainActor
final class CaptureWorkerTests: TestCase {
    private func ticket(window: UInt32? = 7) throws -> ReadWorkerTicket {
        ReadWorkerTicket(requestID: UUID(), incarnation: UUID(), connectionID: UUID(), sessionID: "capture-scope",
            generation: 1, target: try ReadWorkerTarget(pid: 42, startSeconds: 100, startMicroseconds: 2, windowID: window),
            timeout: .seconds(10))
    }
    private func metadata(window: UInt32 = 7, bytes: Int = 1024, hash: String = String(repeating: "a", count: 64), granted: Bool = true) -> CaptureWorkerMetadata {
        CaptureWorkerMetadata(windowID: window, pixelWidth: 1240, pixelHeight: 824, pngBytes: bytes,
            sha256: hash, bounds: Rect(x: 100, y: 100, width: 620, height: 412),
            capturedAt: Date(timeIntervalSince1970: 1_800_000_000), screenRecordingGranted: granted)
    }
    func testWireSeparatesCaptureFromAXAndBindsReply() throws {
        let scope = try ticket()
        let request = try CaptureWorkerWire.encodeRequest(scope)
        expectEqual(try CaptureWorkerWire.decodeRequest(request), scope)
        expectThrows(try ReadWorkerWire.decodeRequest(request))
        expectThrows(try CaptureWorkerWire.decodeRequest(ReadWorkerWire.encodeRequest(scope)))
        expectThrows(try CaptureWorkerWire.encodeRequest(ticket(window: nil)))
        let value = metadata()
        let data = try CaptureWorkerWire.encodeReply(.success(CaptureWorkerReply(ticket: scope, metadata: value,
            elapsed: .milliseconds(5))), ticket: scope)
        expectEqual(try CaptureWorkerWire.decodeReply(data, expected: scope).get().metadata, value)
        let fractional = try CaptureWorkerWire.encodeReply(.success(CaptureWorkerReply(ticket: scope, metadata: value,
            elapsed: Duration(secondsComponent: 0, attosecondsComponent: 1_500_000_000))), ticket: scope)
        expectEqual(try CaptureWorkerWire.decodeReply(fractional, expected: scope).get().elapsed, .nanoseconds(1))
        expectThrows(try CaptureWorkerWire.decodeReply(data, expected: ticket()))
        let refused = try CaptureWorkerWire.encodeReply(.failure(.permissionRequired), ticket: scope)
        expectThrows(try CaptureWorkerWire.decodeReply(refused, expected: scope).get()) {
            expectEqual($0 as? HarnessError, .permissionRequired)
        }
        expectThrows(try CaptureWorkerWire.decodeReply(refused, expected: ticket()))
    }
    func testNoPixelsUnknownFieldsOrInvalidFrameMetadata() throws {
        let scope = try ticket()
        for invalid in [metadata(window: 8), metadata(bytes: 0), metadata(bytes: 8 * 1024 * 1024 + 1),
                        metadata(hash: "bad"), metadata(granted: false)] {
            expectThrows(try CaptureWorkerWire.encodeReply(.success(CaptureWorkerReply(ticket: scope,
                metadata: invalid, elapsed: .milliseconds(1))), ticket: scope))
        }
        let request = try CaptureWorkerWire.encodeRequest(scope)
        var root = try JSONSerialization.jsonObject(with: request) as! [String: Any]
        root["png"] = "not-accepted"
        expectThrows(try CaptureWorkerWire.decodeRequest(JSONSerialization.data(withJSONObject: root)))
        let duplicate = String(decoding: request, as: UTF8.self).replacingOccurrences(of: "\"version\":1", with: "\"version\":1,\"version\":1")
        expectThrows(try CaptureWorkerWire.decodeRequest(Data(duplicate.utf8)))
        expectThrows(try CaptureWorkerWire.decodeRequest(Data(repeating: 32, count: 16385)))
        expectThrows(try CaptureWorkerWire.encodeReply(.success(CaptureWorkerReply(ticket: scope,
            metadata: metadata(), elapsed: .seconds(10))), ticket: scope))
        let data = try CaptureWorkerWire.encodeReply(.success(CaptureWorkerReply(ticket: scope,
            metadata: metadata(), elapsed: .milliseconds(1))), ticket: scope)
        var reply = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        var frame = reply["metadata"] as! [String: Any]; frame["png"] = "forbidden"
        reply["metadata"] = frame
        expectThrows(try CaptureWorkerWire.decodeReply(JSONSerialization.data(withJSONObject: reply), expected: scope))
        reply["metadata"] = NSNull()
        expectThrows(try CaptureWorkerWire.decodeReply(JSONSerialization.data(withJSONObject: reply), expected: scope))
    }
    func testCollectorRejectsWrongProcessBeforeCaptureAndRoleRejectsInvalidParent() async throws {
        let own = try ReadWorkerProcessIdentity.read(pid: ProcessInfo.processInfo.processIdentifier)
        for changed in [false, true] {
            let target = try ReadWorkerTarget(pid: own.pid, startSeconds: own.startSeconds + (changed ? 1 : 0),
                startMicroseconds: own.startMicroseconds, windowID: 7)
            let scope = ReadWorkerTicket(requestID: UUID(), incarnation: UUID(), connectionID: UUID(), sessionID: "negative-capture",
                generation: 1, target: target, timeout: .seconds(10))
            do { _ = try await FixtureCaptureWorker.collect(scope); fail("Non-fixture capture admitted") }
            catch { expectEqual(error as? HarnessError, changed ? .staleObservation : .policyDenied) }
        }
        do {
            try await FixtureWorkerRuntime.run(arguments: [FixtureWorkerRuntime.captureRole, "com.milyonus.test", String(Int32.max)])
            fail("Invalid capture parent admitted")
        } catch { expectEqual(error as? HarnessError, .unauthorized) }
    }
}
