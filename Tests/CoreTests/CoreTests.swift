import Foundation
import Darwin
import ComputerUseContracts
import ComputerUseCore

@MainActor
final class CoreTests: TestCase {
    @MainActor func testUnapprovedSessionCannotExecute() throws {
        let controller = SessionController()
        let session = try controller.open(bundleID: SessionController.fixtureBundleID)
        expectThrows(try controller.requireReady(session.id))
    }
    @MainActor func testArbitraryAppDenied() {
        expectThrows(try SessionController().open(bundleID: "com.apple.Terminal"))
    }
    @MainActor func testOnlyOneSession() throws {
        let controller = SessionController()
        _ = try controller.open(bundleID: SessionController.fixtureBundleID)
        expectThrows(try controller.open(bundleID: SessionController.fixtureBundleID))
    }
    @MainActor func testApprovalAndGenerationFencing() throws {
        let controller = SessionController()
        let session = try controller.open(bundleID: SessionController.fixtureBundleID)
        try controller.approveFromNativeUI()
        expectEqual(try controller.requireReady(session.id).state, .ready)
        controller.pause()
        expectThrows(try controller.requireReady(session.id))
        try controller.requestResume(session.id)
        expectThrows(try controller.requireReady(session.id))
        try controller.approveFromNativeUI()
        expectThrows(try controller.requireReady(session.id, generation: session.generation))
        expectEqual(try controller.requireReady(session.id).generation, 3)
    }
    @MainActor func testCancellationCannotBeRevived() throws {
        let controller = SessionController()
        let session = try controller.open(bundleID: SessionController.fixtureBundleID)
        try controller.approveFromNativeUI(); controller.cancel()
        expectThrows(try controller.approveFromNativeUI())
        expectThrows(try controller.requestResume(session.id))
        expectThrows(try controller.requireReady(session.id))
    }
    @MainActor func testMonotonicExpiry() throws {
        var clock = 100.0
        let controller = SessionController(monotonic: { clock })
        let session = try controller.open(bundleID: SessionController.fixtureBundleID)
        try controller.approveFromNativeUI()
        clock = 401
        expectThrows(try controller.requireReady(session.id))
        expectEqual(controller.session?.state, .expired)
    }
    @MainActor func testExpiredApprovalRejected() throws {
        var clock = 0.0
        let controller = SessionController(monotonic: { clock })
        _ = try controller.open(bundleID: SessionController.fixtureBundleID)
        clock = 301
        expectThrows(try controller.approveFromNativeUI())
    }
    @MainActor func testWrongSessionCannotReadReadyState() throws {
        let controller = SessionController()
        _ = try controller.open(bundleID: SessionController.fixtureBundleID)
        try controller.approveFromNativeUI()
        expectThrows(try controller.requireReady("other"))
    }
    func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
    func request() -> ActionRequest {
        ActionRequest(requestId: "r1", sessionId: "s1", idempotencyKey: "k1", observationId: "o1", generation: 1,
                      elementId: "e1", kind: .setValue, text: "secret-test-string")
    }
    func testUnresolvedIntentSurvivesRestart() throws {
        let path = try temporaryDirectory().appendingPathComponent("journal.json")
        let ledger = try ActionLedger(url: path)
        try ledger.begin(request())
        let reopened = try ActionLedger(url: path)
        expectThrows(try reopened.previous(request())) { expectEqual($0 as? HarnessError, .effectUnknown) }
    }
    func testDuplicateResultWithoutReexecution() throws {
        let ledger = try ActionLedger(url: temporaryDirectory().appendingPathComponent("journal.json"))
        let value = request()
        try ledger.begin(value)
        let result = ActionResult(requestId: "r1", effect: .applied, verification: .passed)
        try ledger.finish(value, result: result)
        var retry = value; retry.requestId = "r2"
        let previous = try requireValue(ledger.previous(retry))
        expectEqual(previous.actionId, result.actionId); expectEqual(previous.requestId, "r2")
    }
    func testSameKeyDifferentPayloadConflict() throws {
        let ledger = try ActionLedger(url: temporaryDirectory().appendingPathComponent("journal.json"))
        let value = request(); try ledger.begin(value)
        var changed = value; changed.text = "different"
        expectThrows(try ledger.previous(changed)) { expectEqual($0 as? HarnessError, .idempotencyConflict) }
    }
    func testJournalDoesNotContainText() throws {
        let path = try temporaryDirectory().appendingPathComponent("journal.json")
        let ledger = try ActionLedger(url: path); try ledger.begin(request())
        expectFalse(try String(contentsOf: path, encoding: .utf8).contains("secret-test-string"))
        let attributes = try FileManager.default.attributesOfItem(atPath: path.path)
        expectEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }
    func testCorruptJournalFailsClosed() throws {
        let path = try temporaryDirectory().appendingPathComponent("journal.json")
        try Data("corrupt".utf8).write(to: path)
        expectThrows(try ActionLedger(url: path))
        expectEqual(try String(contentsOf: path, encoding: .utf8), "corrupt")
    }
    func testDuplicateBeginRejected() throws {
        let ledger = try ActionLedger(url: temporaryDirectory().appendingPathComponent("journal.json"))
        try ledger.begin(request()); expectThrows(try ledger.begin(request()))
    }
    func testCrossProcessLeaseContention() throws {
        let path = try temporaryDirectory().appendingPathComponent("lease")
        let lease = try ProcessLease(url: path)
        try withExtendedLifetime(lease) { expectThrows(try ProcessLease(url: path)) }
    }
    func testLeaseRejectsSymlink() throws {
        let directory = try temporaryDirectory()
        let target = directory.appendingPathComponent("target")
        try Data().write(to: target)
        let link = directory.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        expectThrows(try ProcessLease(url: link))
    }
    @MainActor func testExpiredSessionDoesNotBlockNewSession() throws {
        var clock = 0.0
        let controller = SessionController(monotonic: { clock })
        let first = try controller.open(bundleID: SessionController.fixtureBundleID)
        clock = 301
        let second = try controller.open(bundleID: SessionController.fixtureBundleID)
        expectFalse(first.id == second.id)
    }
    @MainActor func testRepeatedPauseDoesNotChangeGeneration() throws {
        let controller = SessionController()
        _ = try controller.open(bundleID: SessionController.fixtureBundleID)
        try controller.approveFromNativeUI(); controller.pause()
        let generation = controller.session?.generation
        controller.pause()
        expectEqual(controller.session?.generation, generation)
    }
    func testFutureJournalVersionPreserved() throws {
        let path = try temporaryDirectory().appendingPathComponent("journal.json")
        let bytes = Data("{\"version\":999,\"entries\":[]}".utf8)
        try bytes.write(to: path)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)
        expectThrows(try ActionLedger(url: path)) { expectEqual($0 as? HarnessError, .protocolMismatch) }
        expectEqual(try Data(contentsOf: path), bytes)
    }
    func testJournalRejectsSymlink() throws {
        let directory = try temporaryDirectory()
        let target = directory.appendingPathComponent("target")
        try Data("{\"version\":1,\"entries\":[]}".utf8).write(to: target)
        let link = directory.appendingPathComponent("journal.json")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        expectThrows(try ActionLedger(url: link))
    }
    func testJournalRejectsPublicDirectory() throws {
        let directory = try temporaryDirectory()
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
        expectThrows(try ActionLedger(url: directory.appendingPathComponent("journal.json")))
    }
    func testIntentPersistenceFailureDoesNotRemainInMemory() throws {
        let directory = try temporaryDirectory()
        let ledger = try ActionLedger(url: directory.appendingPathComponent("journal.json"))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
        expectThrows(try ledger.begin(request()))
        expectEqual(try ledger.previous(request()), nil)
    }
    func testCompletedJournalSurvivesRestart() throws {
        let path = try temporaryDirectory().appendingPathComponent("journal.json")
        let ledger = try ActionLedger(url: path)
        let action = request()
        let result = ActionResult(requestId: action.requestId, effect: .applied, verification: .passed)
        try ledger.begin(action); try ledger.finish(action, result: result)
        expectEqual(try ActionLedger(url: path).previous(action), result)
    }

    func testJournalRejectsFIFOWithoutWaitingForWriter() throws {
        let path = try temporaryDirectory().appendingPathComponent("journal.pipe")
        expectEqual(mkfifo(path.path, 0o600), 0)
        let start = ContinuousClock.now
        expectThrows(try ActionLedger(url: path)) { expectEqual($0 as? HarnessError, .persistenceFailed) }
        expectEqual(start.duration(to: .now) < .seconds(1), true)
    }
    func testJournalRejectsHardLink() throws {
        let directory = try temporaryDirectory(), target = directory.appendingPathComponent("target")
        _ = try ActionLedger(url: target)
        try Data("{\"version\":1,\"entries\":[]}".utf8).write(to: target)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
        let alias = directory.appendingPathComponent("alias")
        expectEqual(link(target.path, alias.path), 0)
        expectThrows(try ActionLedger(url: alias)) { expectEqual($0 as? HarnessError, .persistenceFailed) }
    }
    func testLeaseRejectsPublicFileAndHardLink() throws {
        let directory = try temporaryDirectory(), path = directory.appendingPathComponent("writer.lock")
        try Data().write(to: path)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: path.path)
        expectThrows(try ProcessLease(url: path)) { expectEqual($0 as? HarnessError, .unauthorized) }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)
        let alias = directory.appendingPathComponent("alias")
        expectEqual(link(path.path, alias.path), 0)
        expectThrows(try ProcessLease(url: path)) { expectEqual($0 as? HarnessError, .unauthorized) }
    }
    func testLeaseRejectsPublicParent() throws {
        let directory = try temporaryDirectory()
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
        expectThrows(try ProcessLease(url: directory.appendingPathComponent("writer.lock"))) {
            expectEqual($0 as? HarnessError, .persistenceFailed)
        }
    }

    func testCompletionRejectsChangedIntent() throws {
        let path = try temporaryDirectory().appendingPathComponent("journal.json")
        let ledger = try ActionLedger(url: path), original = request()
        try ledger.begin(original)
        let before = try Data(contentsOf: path)
        var changed = original; changed.text = "different"
        let result = ActionResult(requestId: original.requestId, effect: .applied, verification: .passed)
        expectThrows(try ledger.finish(changed, result: result)) {
            expectEqual($0 as? HarnessError, .idempotencyConflict)
        }
        expectEqual(try Data(contentsOf: path), before)
        expectThrows(try ActionLedger(url: path).previous(original)) {
            expectEqual($0 as? HarnessError, .effectUnknown)
        }
    }
    func testCompletionBindsExecutionMethod() throws {
        for method in [ExecutionMethod.nativeText, .nativeClick] {
            let path = try temporaryDirectory().appendingPathComponent("journal.json")
            let ledger = try ActionLedger(url: path), action = request()
            let result = ActionResult(requestId: action.requestId, effect: .applied, verification: .passed)
            try ledger.begin(action, method: method)
            expectThrows(try ledger.finish(action, result: result)) {
                expectEqual($0 as? HarnessError, .idempotencyConflict)
            }
            try ledger.finish(action, result: result, method: method)
            expectEqual(try ActionLedger(url: path).previous(action, method: method), result)
        }
    }
    func testCompletionRejectsWrongResponseCorrelation() throws {
        let path = try temporaryDirectory().appendingPathComponent("journal.json")
        let ledger = try ActionLedger(url: path), action = request()
        try ledger.begin(action)
        let before = try Data(contentsOf: path)
        let result = ActionResult(requestId: "unrelated", effect: .applied, verification: .passed)
        expectThrows(try ledger.finish(action, result: result)) {
            expectEqual($0 as? HarnessError, .protocolMismatch)
        }
        expectEqual(try Data(contentsOf: path), before)
        expectThrows(try ledger.previous(action)) { expectEqual($0 as? HarnessError, .effectUnknown) }
    }
    func testCompletionIsImmutableAcrossRestart() throws {
        let path = try temporaryDirectory().appendingPathComponent("journal.json")
        let ledger = try ActionLedger(url: path), action = request()
        let result = ActionResult(requestId: action.requestId, effect: .unknown, verification: .unavailable,
                                  error: .effectUnknown)
        try ledger.begin(action); try ledger.finish(action, result: result)
        let before = try Data(contentsOf: path)
        let reopened = try ActionLedger(url: path)
        try reopened.finish(action, result: result)
        let replacement = ActionResult(requestId: action.requestId, effect: .applied, verification: .passed)
        expectThrows(try reopened.finish(action, result: replacement)) {
            expectEqual($0 as? HarnessError, .idempotencyConflict)
        }
        expectEqual(try Data(contentsOf: path), before)
        expectEqual(try reopened.previous(action), result)
        expectEqual(try ActionLedger(url: path).previous(action), result)
    }

    func testFailedCompletionFreezesJournalWrites() throws {
        let directory = try temporaryDirectory(), path = directory.appendingPathComponent("journal.json")
        let ledger = try ActionLedger(url: path), action = request()
        try ledger.begin(action)
        let intent = try Data(contentsOf: path)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
        let result = ActionResult(requestId: action.requestId, effect: .applied, verification: .passed)
        expectThrows(try ledger.finish(action, result: result)) { expectEqual($0 as? HarnessError, .effectUnknown) }
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        expectThrows(try ledger.finish(action, result: result)) { expectEqual($0 as? HarnessError, .effectUnknown) }
        var another = action; another.idempotencyKey = "another"
        expectThrows(try ledger.begin(another)) { expectEqual($0 as? HarnessError, .persistenceFailed) }
        expectEqual(try Data(contentsOf: path), intent)
        expectThrows(try ledger.previous(action)) { expectEqual($0 as? HarnessError, .effectUnknown) }
        expectThrows(try ActionLedger(url: path).previous(action)) { expectEqual($0 as? HarnessError, .effectUnknown) }
    }
    func testFailedIntentRequiresReopenBeforeWriting() throws {
        let directory = try temporaryDirectory(), path = directory.appendingPathComponent("journal.json")
        let ledger = try ActionLedger(url: path), action = request()
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
        expectThrows(try ledger.begin(action)) { expectEqual($0 as? HarnessError, .persistenceFailed) }
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        expectThrows(try ledger.begin(action)) { expectEqual($0 as? HarnessError, .persistenceFailed) }
        expectFalse(FileManager.default.fileExists(atPath: path.path))
        let reopened = try ActionLedger(url: path)
        try reopened.begin(action)
        expectThrows(try reopened.previous(action)) { expectEqual($0 as? HarnessError, .effectUnknown) }
    }
    func testRenameFailureCleansTemporaryJournal() throws {
        let directory = try temporaryDirectory(), path = directory.appendingPathComponent("journal.json")
        let ledger = try ActionLedger(url: path)
        // A directory at the destination forces rename to fail after temporary-file fsync.
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: false)
        let marker = path.appendingPathComponent("preserve")
        try Data("fixture".utf8).write(to: marker)
        expectThrows(try ledger.begin(request())) { expectEqual($0 as? HarnessError, .persistenceFailed) }
        expectEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["journal.json"])
        expectEqual(try Data(contentsOf: marker), Data("fixture".utf8))
    }

    func testIntentFailureAtDurabilityBoundaries() throws {
        for stage in JournalWriteStage.allCases {
            let directory = try temporaryDirectory(), path = directory.appendingPathComponent("journal.json")
            var checkpoints: [JournalWriteStage] = []
            let ledger = try ActionLedger(url: path, writeCheckpoint: {
                checkpoints.append($0)
                if $0 == stage { throw HarnessError.persistenceFailed }
            })
            let action = request()
            expectThrows(try ledger.begin(action)) { expectEqual($0 as? HarnessError, .persistenceFailed) }
            expectEqual(checkpoints.last, stage)
            let checkpointCount = checkpoints.count
            expectThrows(try ledger.begin(action)) { expectEqual($0 as? HarnessError, .persistenceFailed) }
            expectEqual(checkpoints.count, checkpointCount)
            let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            expectEqual(files, stage == .beforeDirectorySync ? ["journal.json"] : [])
            let reopened = try ActionLedger(url: path)
            if stage == .beforeDirectorySync {
                expectThrows(try reopened.previous(action)) { expectEqual($0 as? HarnessError, .effectUnknown) }
            } else {
                expectEqual(try reopened.previous(action), nil)
            }
        }
    }
    func testCompletionFailureAtDurabilityBoundaries() throws {
        for stage in JournalWriteStage.allCases {
            let directory = try temporaryDirectory(), path = directory.appendingPathComponent("journal.json")
            var armed = false
            let ledger = try ActionLedger(url: path, writeCheckpoint: {
                if armed && $0 == stage { throw HarnessError.persistenceFailed }
            })
            let action = request()
            try ledger.begin(action)
            let intent = try Data(contentsOf: path)
            armed = true
            let result = ActionResult(requestId: action.requestId, effect: .applied, verification: .passed)
            expectThrows(try ledger.finish(action, result: result)) { expectEqual($0 as? HarnessError, .effectUnknown) }
            expectThrows(try ledger.previous(action)) { expectEqual($0 as? HarnessError, .effectUnknown) }
            armed = false
            expectThrows(try ledger.finish(action, result: result)) { expectEqual($0 as? HarnessError, .effectUnknown) }
            var another = action; another.idempotencyKey = "another"
            expectThrows(try ledger.begin(another)) { expectEqual($0 as? HarnessError, .persistenceFailed) }
            expectEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["journal.json"])
            let reopened = try ActionLedger(url: path)
            if stage == .beforeDirectorySync {
                expectEqual(try reopened.previous(action), result)
            } else {
                expectEqual(try Data(contentsOf: path), intent)
                expectThrows(try reopened.previous(action)) { expectEqual($0 as? HarnessError, .effectUnknown) }
            }
        }
    }

}
