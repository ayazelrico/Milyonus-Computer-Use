import Foundation
import ComputerUseContracts
import ComputerUseCore

@MainActor
final class JournalAdmissionTests: TestCase {
    func fixture() throws -> (URL, ActionRequest, [String: Any]) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("journal.json")
        let action = ActionRequest(requestId: "request", sessionId: "session", idempotencyKey: "key",
                                   observationId: "observation", generation: 1, elementId: "element", kind: .press)
        try ActionLedger(url: path).begin(action)
        let document = try requireValue(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
        let entries = try requireValue(document["entries"] as? [[String: Any]])
        return (path, action, try requireValue(entries.first))
    }
    func write(_ entries: [[String: Any]], to path: URL) throws -> Data {
        let bytes = try JSONSerialization.data(withJSONObject: ["version": 1, "entries": entries], options: [.sortedKeys])
        try bytes.write(to: path)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)
        return bytes
    }
    func testContradictoryResultsCannotCompleteOrReopen() throws {
        for effect in [EffectState.unknown, .notApplied, .applied] {
            let (path, action, original) = try fixture()
            let result = ActionResult(requestId: action.requestId, effect: effect,
                                      verification: .passed, error: effect == .applied ? .cancelled : nil)
            let ledger = try ActionLedger(url: path)
            let before = try Data(contentsOf: path)
            expectThrows(try ledger.finish(action, result: result)) {
                expectEqual($0 as? HarnessError, .protocolMismatch)
            }
            expectEqual(try Data(contentsOf: path), before)
            expectThrows(try ledger.previous(action)) { expectEqual($0 as? HarnessError, .effectUnknown) }
            var entry = original
            entry["result"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(result))
            let malformed = try write([entry], to: path)
            expectThrows(try ActionLedger(url: path)) { expectEqual($0 as? HarnessError, .persistenceFailed) }
            expectEqual(try Data(contentsOf: path), malformed)
        }
    }
    func testMalformedEntriesRejectedWithoutRepair() throws {
        let (path, _, original) = try fixture()
        var variants: [[String: Any]] = []
        for key in ["", "../path", String(repeating: "a", count: 129), "非ASCII"] {
            var entry = original; entry["key"] = key; variants.append(entry)
        }
        for fingerprint in ["", String(repeating: "0", count: 63), String(repeating: "G", count: 64)] {
            var entry = original; entry["fingerprint"] = fingerprint; variants.append(entry)
        }
        for field in ["requestId", "actionId"] {
            for value in ["", "../invalid", String(repeating: "a", count: 129)] {
                var result: [String: Any] = ["requestId": "request", "actionId": "action",
                                            "effect": "applied", "verification": "passed"]
                result[field] = value
                var entry = original; entry["result"] = result; variants.append(entry)
            }
        }
        for entry in variants {
            let bytes = try write([entry], to: path)
            expectThrows(try ActionLedger(url: path)) { expectEqual($0 as? HarnessError, .persistenceFailed) }
            expectEqual(try Data(contentsOf: path), bytes)
        }
    }
    func testEntryCountAndDuplicateKeysRejected() throws {
        let (path, _, original) = try fixture()
        var excessive = (0..<2001).map { index -> [String: Any] in
            var entry = original; entry["key"] = "key-\(index)"; return entry
        }
        for entries in [[original, original], excessive] {
            let bytes = try write(entries, to: path)
            expectThrows(try ActionLedger(url: path)) { expectEqual($0 as? HarnessError, .persistenceFailed) }
            expectEqual(try Data(contentsOf: path), bytes)
        }
        excessive.removeAll()
    }
    func testFullJournalAllowsCompletionButRejectsNewIntent() throws {
        let (path, action, original) = try fixture()
        let entries = [original] + (1..<2000).map { index -> [String: Any] in
            var entry = original; entry["key"] = "key-\(index)"; return entry
        }
        _ = try write(entries, to: path)
        let ledger = try ActionLedger(url: path)
        let result = ActionResult(requestId: action.requestId, effect: .applied, verification: .passed)
        try ledger.finish(action, result: result)
        let bytes = try Data(contentsOf: path)
        expectEqual(try ledger.previous(action), result)
        var another = action; another.idempotencyKey = "new-key"
        expectThrows(try ledger.begin(another)) { expectEqual($0 as? HarnessError, .resourceLimit) }
        expectEqual(try Data(contentsOf: path), bytes)
        expectEqual(try ActionLedger(url: path).previous(action), result)
    }
    func testOversizedJournalRejectedWithoutTruncation() throws {
        let (path, _, _) = try fixture()
        let bytes = Data(repeating: 32, count: 2_000_001)
        try bytes.write(to: path)
        expectThrows(try ActionLedger(url: path)) { expectEqual($0 as? HarnessError, .persistenceFailed) }
        expectEqual(try Data(contentsOf: path), bytes)
    }
    func testInvalidNewRecordsNeverPersist() throws {
        let (path, action, _) = try fixture()
        let ledger = try ActionLedger(url: path)
        let before = try Data(contentsOf: path)
        var invalid = action; invalid.idempotencyKey = "../invalid"
        expectThrows(try ledger.begin(invalid)) { expectEqual($0 as? HarnessError, .invalidRequest) }
        let result = ActionResult(requestId: action.requestId, actionId: "", effect: .applied, verification: .passed)
        expectThrows(try ledger.finish(action, result: result)) { expectEqual($0 as? HarnessError, .protocolMismatch) }
        expectEqual(try Data(contentsOf: path), before)
        expectThrows(try ledger.previous(action)) { expectEqual($0 as? HarnessError, .effectUnknown) }
        // Validation refusal does not poison an otherwise healthy ledger.
        let valid = ActionResult(requestId: action.requestId, effect: .applied, verification: .passed)
        try ledger.finish(action, result: valid)
        expectEqual(try ActionLedger(url: path).previous(action), valid)
    }
}
