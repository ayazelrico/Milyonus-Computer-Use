import Foundation
import ComputerUseContracts
import ComputerUseCore
import ComputerUseMacOS

@MainActor
final class ReadWorkerWireTests: TestCase {
    private func ticket(target: ReadWorkerTarget? = nil) throws -> ReadWorkerTicket {
        ReadWorkerTicket(requestID: UUID(), incarnation: UUID(), connectionID: UUID(), sessionID: "read-session",
                         generation: 1, target: try target ?? ReadWorkerTarget(pid: 42, startSeconds: 100, startMicroseconds: 20),
                         timeout: .seconds(10))
    }

    func testFixedRequestAndBoundReplyRoundTrip() throws {
        let value = try ticket()
        let request = try ReadWorkerWire.encodeRequest(value)
        expectEqual(try ReadWorkerWire.decodeRequest(request), value)
        let observation = Observation(id: "read-observation", sessionId: value.sessionID,
            bundleId: SessionController.fixtureBundleID, pid: value.target.pid, capturedAt: Date(),
            elements: [ElementSnapshot(id: "raw-worker-element", role: "AXStaticText", identifier: nil,
                label: "Fixture", value: "Türkçe 🧪", bounds: nil, enabled: true, actions: [])], truncated: false)
        let reply = ReadWorkerReply(ticket: value, observation: observation, elapsed: .milliseconds(5))
        let data = try ReadWorkerWire.encodeReply(.success(reply), ticket: value)
        let decoded = try ReadWorkerWire.decodeReply(data, expected: value).get()
        expectEqual(decoded.ticket, value)
        expectEqual(decoded.observation.elements.first?.value, "Türkçe 🧪")
        expectEqual(decoded.elapsed, .milliseconds(5))
        let refusal = try ReadWorkerWire.encodeReply(.failure(.permissionRequired), ticket: value)
        expectThrows(try ReadWorkerWire.decodeReply(refusal, expected: value).get()) {
            expectEqual($0 as? HarnessError, .permissionRequired)
        }
        let unrelated = try ticket()
        expectThrows(try ReadWorkerWire.decodeReply(data, expected: unrelated))
        expectThrows(try ReadWorkerWire.decodeReply(refusal, expected: unrelated))
    }

    func testRequestCannotCarryMutationOrExpandedScope() throws {
        let request = try ReadWorkerWire.encodeRequest(ticket())
        var object = try JSONSerialization.jsonObject(with: request) as! [String: Any]
        object["script"] = "not-executable"
        expectThrows(try ReadWorkerWire.decodeRequest(JSONSerialization.data(withJSONObject: object)))
        object.removeValue(forKey: "script"); object["kind"] = "desktop.action"
        expectThrows(try ReadWorkerWire.decodeRequest(JSONSerialization.data(withJSONObject: object)))
        object["kind"] = "fixture.ax.observe"
        var scope = object["ticket"] as! [String: Any]
        scope["bundleId"] = "other.app"; object["ticket"] = scope
        expectThrows(try ReadWorkerWire.decodeRequest(JSONSerialization.data(withJSONObject: object)))
        scope.removeValue(forKey: "bundleId"); scope["timeoutNanoseconds"] = 10_000_000_001
        object["ticket"] = scope
        expectThrows(try ReadWorkerWire.decodeRequest(JSONSerialization.data(withJSONObject: object)))
        let duplicate = String(decoding: request, as: UTF8.self)
            .replacingOccurrences(of: "\"version\":1", with: "\"version\":1,\"version\":1")
        expectEqual(duplicate.utf8.count > request.count, true)
        expectThrows(try ReadWorkerWire.decodeRequest(Data(duplicate.utf8)))
        expectThrows(try ReadWorkerWire.decodeRequest(Data(repeating: 32, count: 262_145))) {
            expectEqual($0 as? HarnessError, .resourceLimit)
        }
    }

    func testReplyCannotMixFailureWithObservationOrExtendDeadline() throws {
        let value = try ticket()
        let observation = Observation(id: "observation", sessionId: value.sessionID,
            bundleId: SessionController.fixtureBundleID, pid: 42, capturedAt: Date(), elements: [], truncated: false)
        let valid = try ReadWorkerWire.encodeReply(.success(ReadWorkerReply(ticket: value, observation: observation,
                                                                           elapsed: .milliseconds(1))), ticket: value)
        var object = try JSONSerialization.jsonObject(with: valid) as! [String: Any]
        object["error"] = "PERMISSION_REQUIRED"
        expectThrows(try ReadWorkerWire.decodeReply(JSONSerialization.data(withJSONObject: object), expected: value))
        object.removeValue(forKey: "error"); object["elapsedNanoseconds"] = 10_000_000_000
        expectThrows(try ReadWorkerWire.decodeReply(JSONSerialization.data(withJSONObject: object), expected: value))
        object["elapsedNanoseconds"] = 1
        var snapshot = object["observation"] as! [String: Any]
        snapshot["pid"] = 99; object["observation"] = snapshot
        expectThrows(try ReadWorkerWire.decodeReply(JSONSerialization.data(withJSONObject: object), expected: value))
    }

    func testKernelIdentityAndCollectorRefusalsWithoutAXAccess() throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let current = try ReadWorkerProcessIdentity.read(pid: pid)
        expectEqual(current.pid, pid)
        expectEqual(current.startSeconds > 0, true)
        expectEqual((0..<1_000_000).contains(current.startMicroseconds), true)
        expectEqual(try ReadWorkerProcessIdentity.read(pid: pid), current)
        expectThrows(try ReadWorkerProcessIdentity.read(pid: Int32.max))
        // This executable is not the fixture: reject before querying AX trust or
        // reading an AX tree. No native session/grant is manufactured by the test.
        expectThrows(try FixtureReadWorker.collect(ticket(target: current))) {
            expectEqual($0 as? HarnessError, .policyDenied)
        }
        let replaced = try ReadWorkerTarget(pid: pid, startSeconds: current.startSeconds + 1,
                                            startMicroseconds: current.startMicroseconds)
        expectThrows(try FixtureReadWorker.collect(ticket(target: replaced))) {
            expectEqual($0 as? HarnessError, .staleObservation)
        }
        let window = try ReadWorkerTarget(pid: pid, startSeconds: current.startSeconds,
                                          startMicroseconds: current.startMicroseconds, windowID: 7)
        expectThrows(try FixtureReadWorker.collect(ticket(target: window))) {
            expectEqual($0 as? HarnessError, .unsupportedCapability)
        }
    }
}
