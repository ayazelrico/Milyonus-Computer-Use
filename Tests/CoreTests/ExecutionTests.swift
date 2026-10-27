import Foundation
import ComputerUseContracts
import ComputerUseCore

@MainActor
final class FakeDesktop: DesktopDriver {
    var applied = 0
    var invalidated = 0
    var preflightError: HarnessError?
    var throwDuringExecution = false
    var observationID = "observation-1"
    var onObserve: (() throws -> Void)?
    var onPreflight: (() throws -> Void)?
    var onExecute: (() throws -> Void)?
    var observedBundle: String?
    var observationOverride: Observation?
    func observe(session: Session) throws -> Observation {
        try onObserve?()
        if let observationOverride { return observationOverride }
        return Observation(id: observationID, sessionId: session.id, bundleId: observedBundle ?? session.bundleId, pid: 42,
                    capturedAt: Date(), elements: [], truncated: false)
    }
    func preflight(_ request: ActionRequest, session: Session) throws {
        try onPreflight?()
        if let preflightError { throw preflightError }
        guard request.observationId == observationID else { throw HarnessError.staleObservation }
    }
    func execute(_ request: ActionRequest, session: Session) throws -> ActionResult {
        applied += 1
        try onExecute?()
        if throwDuringExecution { throw HarnessError.timeout }
        return ActionResult(requestId: request.requestId, effect: .applied, verification: .passed)
    }
    func invalidate() { invalidated += 1; observationID = UUID().uuidString }
}

@MainActor
final class ExecutionTests: TestCase {
    func setup(maximumActions: Int = 100, controller: SessionController? = nil, writeCheckpoint: ((JournalWriteStage) throws -> Void)? = nil) throws -> (ExecutionEngine, SessionController, FakeDesktop, ActionRequest, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let sessions = controller ?? SessionController(), driver = FakeDesktop()
        let session = try sessions.open(bundleID: SessionController.fixtureBundleID)
        try sessions.approveFromNativeUI()
        let engine = ExecutionEngine(sessions: sessions, driver: driver,
                                     ledger: try ActionLedger(url: directory.appendingPathComponent("journal.json"), writeCheckpoint: writeCheckpoint), maximumActions: maximumActions)
        let request = ActionRequest(requestId: "request", sessionId: session.id, idempotencyKey: "key",
                                    observationId: driver.observationID, generation: session.generation,
                                    elementId: "element", kind: .press)
        return (engine, sessions, driver, request, directory)
    }
    func testMalformedDriverObservationInvalidatesTargets() throws {
        let (engine, _, driver, request, _) = try setup()
        var malformed = ObservationValidationTests().fixture()
        malformed.sessionId = request.sessionId
        malformed.elements += malformed.elements
        driver.observationOverride = malformed
        expectThrows(try engine.observe(sessionID: request.sessionId)) {
            expectEqual($0 as? HarnessError, .protocolMismatch)
        }
        expectEqual(driver.invalidated, 1)
        expectEqual(driver.applied, 0)
    }
    func testContradictoryCompletionRetainsUnknownIntent() async throws {
        let (engine, sessions, driver, request, directory) = try setup()
        do {
            _ = try await engine.executeAsync(request) { _ in
                // Even a late callback cannot normalize an invalid success claim.
                sessions.cancel()
                return ActionResult(requestId: request.requestId, effect: .unknown, verification: .passed)
            }
            fail("Contradictory result admitted")
        } catch { expectEqual(error as? HarnessError, .protocolMismatch) }
        expectEqual(driver.invalidated, 1)
        expectEqual(sessions.current()?.state, .cancelled)
        let reopened = try ActionLedger(url: directory.appendingPathComponent("journal.json"))
        expectThrows(try reopened.previous(request)) { expectEqual($0 as? HarnessError, .effectUnknown) }
    }
    func testLateCompletionPreservesEffectWithoutVerification() async throws {
        for asynchronous in [false, true] {
            for mode in ["cancel", "generation", "heartbeat", "lifetime"] {
                var now = 0.0
                let sessions = SessionController(heartbeatTimeout: 15, monotonic: { now })
                let (engine, _, driver, request, directory) = try setup(controller: sessions)
                let revoke: () throws -> Void = {
                    switch mode {
                    case "cancel": sessions.cancel()
                    case "generation":
                        sessions.pause()
                        try sessions.requestResume(request.sessionId)
                        try sessions.approveFromNativeUI()
                    case "heartbeat": now = 15
                    default: now = 300
                    }
                }
                let method: ExecutionMethod = asynchronous ? .nativeClick : .semantic
                var callbacks = 0
                let result: ActionResult
                if asynchronous {
                    result = try await engine.executeAsync(request, method: method) { _ in
                        callbacks += 1
                        try revoke()
                        return ActionResult(requestId: request.requestId, effect: .applied, verification: .passed)
                    }
                } else {
                    driver.onExecute = revoke
                    result = try engine.execute(request)
                }
                expectEqual(result.effect, .applied)
                expectEqual(result.verification, .unavailable)
                expectEqual(result.error, mode == "generation" ? .staleObservation : mode == "lifetime" ? .timeout : .unauthorized)
                expectEqual(driver.applied + callbacks, 1)
                expectEqual(driver.invalidated, 1)
                let reopened = try ActionLedger(url: directory.appendingPathComponent("journal.json"))
                expectEqual(try reopened.previous(request, method: method), result)
                expectEqual(sessions.current()?.state, mode == "cancel" ? .cancelled : mode == "generation" ? .ready : mode == "heartbeat" ? .paused : .expired)
            }
        }
    }
    func testCancelledCompletionReceiptCannotRepeatEffect() async throws {
        let (engine, sessions, driver, request, directory) = try setup()
        driver.onExecute = { withUnsafeCurrentTask { $0?.cancel() } }
        let task = Task { @MainActor in try engine.execute(request) }
        let result = try await task.value
        expectEqual(result.effect, .applied)
        expectEqual(result.verification, .unavailable)
        expectEqual(result.error, .cancelled)
        expectEqual(driver.applied, 1)
        expectEqual(sessions.current()?.state, .ready)
        driver.onExecute = nil
        expectEqual(try engine.execute(request), result)
        expectEqual(driver.applied, 1)
        let reopened = try ActionLedger(url: directory.appendingPathComponent("journal.json"))
        expectEqual(try reopened.previous(request), result)
    }
    func testLateCompletionDoesNotReviveCancelledSessionOrAlterReplacement() async throws {
        let (engine, sessions, _, request, directory) = try setup()
        var replacement: Session?
        let result = try await engine.executeAsync(request) { _ in
            sessions.cancel()
            replacement = try sessions.open(bundleID: SessionController.fixtureBundleID)
            return ActionResult(requestId: request.requestId, effect: .applied, verification: .passed)
        }
        expectEqual(result.effect, .applied)
        expectEqual(result.verification, .unavailable)
        expectEqual(result.error, .unauthorized)
        expectEqual(sessions.current()?.id, replacement?.id)
        expectEqual(sessions.current()?.state, .awaitingApproval)
        let reopened = try ActionLedger(url: directory.appendingPathComponent("journal.json"))
        expectEqual(try reopened.previous(request), result)
    }
    func testPreflightExpiryAndGenerationChangeCannotWriteIntent() throws {
        for mode in ["heartbeat", "lifetime", "generation"] {
            var now = 0.0
            let sessions = SessionController(heartbeatTimeout: 15, monotonic: { now })
            let (engine, _, driver, request, directory) = try setup(controller: sessions)
            driver.onPreflight = {
                if mode == "generation" {
                    sessions.pause()
                    try sessions.requestResume(request.sessionId)
                    try sessions.approveFromNativeUI()
                } else { now = mode == "heartbeat" ? 15 : 300 }
            }
            expectThrows(try engine.execute(request)) {
                expectEqual($0 as? HarnessError, mode == "generation" ? .staleObservation : mode == "heartbeat" ? .unauthorized : .timeout)
            }
            expectEqual(driver.applied, 0)
            expectEqual(driver.invalidated, 1)
            expectFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("journal.json").path))
        }
    }
    func testJournalExpiryPreventsSemanticAndAsyncDispatch() async throws {
        for asynchronous in [false, true] {
            for duration in [15.0, 300.0] {
                var now = 0.0
                let sessions = SessionController(heartbeatTimeout: 15, monotonic: { now })
                let (engine, _, driver, request, directory) = try setup(controller: sessions, writeCheckpoint: { stage in
                    if stage == .beforeDirectorySync { now = duration }
                })
                let result: ActionResult
                let method: ExecutionMethod = asynchronous ? .nativeClick : .semantic
                if asynchronous {
                    result = try await engine.executeAsync(request, method: method) { _ in
                        fail("Expired journal must not dispatch callback")
                        return ActionResult(requestId: request.requestId, effect: .applied, verification: .passed)
                    }
                } else { result = try engine.execute(request) }
                expectEqual(result.effect, .notApplied)
                expectEqual(result.verification, .unavailable)
                expectEqual(result.error, duration == 15 ? .unauthorized : .timeout)
                expectEqual(driver.applied, 0)
                expectEqual(driver.invalidated, 1)
                let reopened = try ActionLedger(url: directory.appendingPathComponent("journal.json"))
                expectEqual(try reopened.previous(request, method: method), result)
            }
        }
    }
    func testTaskCancellationBeforeAndAfterIntent() async throws {
        for afterIntent in [false, true] {
            let (engine, _, driver, request, directory) = try setup(writeCheckpoint: { stage in
                if afterIntent && stage == .beforeDirectorySync { withUnsafeCurrentTask { $0?.cancel() } }
            })
            if !afterIntent { driver.onPreflight = { withUnsafeCurrentTask { $0?.cancel() } } }
            let task = Task { @MainActor in try engine.execute(request) }
            if afterIntent {
                let result = try await task.value
                expectEqual(result.effect, .notApplied)
                expectEqual(result.error, .cancelled)
                let reopened = try ActionLedger(url: directory.appendingPathComponent("journal.json"))
                expectEqual(try reopened.previous(request), result)
                // Cancellation did not dispatch; a later exact retry returns the receipt.
                expectEqual(try engine.execute(request), result)
            } else {
                do { _ = try await task.value; fail("Cancelled preflight wrote an intent") }
                catch { expectEqual(error is CancellationError, true) }
                expectFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("journal.json").path))
            }
            expectEqual(driver.applied, 0)
            expectEqual(driver.invalidated, 1)
        }
    }
    func testObservationLeaseExpiryInvalidatesTargets() throws {
        for duration in [15.0, 300.0] {
            var now = 0.0
            let sessions = SessionController(heartbeatTimeout: 15, monotonic: { now })
            let (engine, _, driver, request, _) = try setup(controller: sessions)
            driver.onObserve = { now = duration }
            expectThrows(try engine.observe(sessionID: request.sessionId)) {
                expectEqual($0 as? HarnessError, duration == 300 ? .timeout : .unauthorized)
            }
            expectEqual(driver.invalidated, 1)
            expectEqual(driver.applied, 0)
        }
    }
    func testObservationGenerationAndScopeCannotChangeDuringRead() throws {
        let (engine, sessions, driver, request, _) = try setup()
        driver.onObserve = {
            sessions.pause()
            try sessions.requestResume(request.sessionId)
            try sessions.approveFromNativeUI()
        }
        expectThrows(try engine.observe(sessionID: request.sessionId)) {
            expectEqual($0 as? HarnessError, .staleObservation)
        }
        expectEqual(driver.invalidated, 1)
        driver.onObserve = nil
        driver.observedBundle = "another.app"
        expectThrows(try engine.observe(sessionID: request.sessionId)) {
            expectEqual($0 as? HarnessError, .protocolMismatch)
        }
        expectEqual(driver.invalidated, 2)
        driver.observedBundle = nil
        expectEqual(try engine.observe(sessionID: request.sessionId).bundleId, SessionController.fixtureBundleID)
    }
    func testObservationTaskCancellationCannotPublish() async throws {
        let (engine, _, driver, request, _) = try setup()
        driver.onObserve = { withUnsafeCurrentTask { $0?.cancel() } }
        let task = Task { @MainActor in try engine.observe(sessionID: request.sessionId) }
        do { _ = try await task.value; fail("Cancelled observation was published") }
        catch { expectEqual(error is CancellationError, true) }
        expectEqual(driver.invalidated, 1)
        expectEqual(driver.applied, 0)
    }
    func testObservationFailureInvalidatesTargets() throws {
        let (engine, _, driver, request, _) = try setup()
        driver.onObserve = { throw HarnessError.permissionRevoked }
        expectThrows(try engine.observe(sessionID: request.sessionId)) {
            expectEqual($0 as? HarnessError, .permissionRevoked)
        }
        expectEqual(driver.invalidated, 1)
        expectEqual(driver.applied, 0)
    }
    func testIdempotencyDistinguishesExecutionMethods() async throws {
        let (engine, _, driver, request, _) = try setup()
        _ = try engine.execute(request)
        do {
            _ = try await engine.executeAsync(request, method: .nativeText) { _ in
                fail("Different execution method must not dispatch")
                return ActionResult(requestId: request.requestId, effect: .applied, verification: .passed)
            }
            fail("Expected idempotency conflict")
        } catch { expectEqual(error as? HarnessError, .idempotencyConflict) }
        expectEqual(driver.applied, 1)
    }
    func testDuplicateRunsNativeEffectOnce() throws {
        let (engine, _, driver, request, _) = try setup()
        let first = try engine.execute(request), second = try engine.execute(request)
        expectEqual(first.actionId, second.actionId); expectEqual(driver.applied, 1)
        expectEqual(driver.invalidated, 1)
    }
    func testPreflightFailureHasNoIntentAndNoEffect() throws {
        let (engine, _, driver, request, directory) = try setup()
        driver.preflightError = .focusChanged
        expectThrows(try engine.execute(request)) { expectEqual($0 as? HarnessError, .focusChanged) }
        expectEqual(driver.applied, 0)
        expectFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("journal.json").path))
    }
    func testIntentFailurePreventsNativeCall() throws {
        let (engine, sessions, driver, request, directory) = try setup()
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
        expectThrows(try engine.execute(request))
        expectEqual(driver.applied, 0)
        expectEqual(sessions.session?.state, .paused)
    }
    func testAdapterExceptionIsUnknownAndPauses() throws {
        let (engine, sessions, driver, request, _) = try setup()
        driver.throwDuringExecution = true
        let result = try engine.execute(request)
        expectEqual(result.effect, .unknown); expectEqual(result.verification, .unavailable)
        expectEqual(sessions.session?.state, .paused)
        expectThrows(try engine.execute(request)); expectEqual(driver.applied, 1)
    }
    func testCancellationPreventsExecution() throws {
        let (engine, sessions, driver, request, _) = try setup()
        sessions.cancel()
        expectThrows(try engine.execute(request)); expectEqual(driver.applied, 0)
    }
    func testOldGenerationCannotExecuteAfterResume() throws {
        let (engine, sessions, driver, request, _) = try setup()
        sessions.pause(); try sessions.requestResume(request.sessionId); try sessions.approveFromNativeUI()
        expectThrows(try engine.execute(request)) { expectEqual($0 as? HarnessError, .staleObservation) }
        expectEqual(driver.applied, 0)
    }
    func testBudgetStopsSecondEffectButAllowsReadback() throws {
        let (engine, _, driver, request, _) = try setup(maximumActions: 1)
        let result = try engine.execute(request)
        expectEqual(try engine.execute(request).actionId, result.actionId)
        var second = request; second.idempotencyKey = "key-2"; second.observationId = driver.observationID
        expectThrows(try engine.execute(second)) { expectEqual($0 as? HarnessError, .resourceLimit) }
        expectEqual(driver.applied, 1)
    }
    func testMalformedRequestNeverReachesNativeDriver() throws {
        let (engine, _, driver, request, _) = try setup()
        var malformed = request; malformed.text = "unexpected"
        expectThrows(try engine.execute(malformed)); expectEqual(driver.applied, 0)
    }
    func testAsyncExecutionRetainsClaimAndHonorsCancellation() async throws {
        let (engine, sessions, _, request, _) = try setup()
        var entered = false
        let task = Task { @MainActor in
            try await engine.executeAsync(request) { session in
                entered = true
                try await Task.sleep(for: .milliseconds(50))
                _ = try sessions.requireReady(session.id, generation: session.generation)
                return ActionResult(requestId: request.requestId, effect: .applied, verification: .passed)
            }
        }
        for _ in 0..<100 where !entered { await Task.yield() }
        expectEqual(entered, true)
        var other = request; other.idempotencyKey = "other"
        expectThrows(try engine.execute(other)) { expectEqual($0 as? HarnessError, .leaseBusy) }
        expectThrows(try engine.observe(sessionID: request.sessionId)) { expectEqual($0 as? HarnessError, .leaseBusy) }
        sessions.cancel()
        let result = try await task.value
        expectEqual(result.effect, .unknown)
        expectEqual(sessions.session?.state, .cancelled)
    }

    func testNativeMethodCompletionCanBeReplayedWithoutDispatch() async throws {
        for method in [ExecutionMethod.nativeText, .nativeClick] {
            let (engine, sessions, driver, request, _) = try setup()
            var dispatches = 0
            let first = try await engine.executeAsync(request, method: method) { _ in
                dispatches += 1
                return ActionResult(requestId: request.requestId, effect: .applied, verification: .passed)
            }
            let second = try await engine.executeAsync(request, method: method) { _ in
                dispatches += 1
                return ActionResult(requestId: request.requestId, effect: .applied, verification: .passed)
            }
            expectEqual(first, second)
            expectEqual(dispatches, 1)
            expectEqual(driver.invalidated, 1)
            expectEqual(sessions.session?.state, .ready)
        }
    }
    func testWrongCompletionCorrelationPausesAndPreservesIntent() async throws {
        let (engine, sessions, driver, request, directory) = try setup()
        do {
            _ = try await engine.executeAsync(request) { _ in
                ActionResult(requestId: "unrelated", effect: .applied, verification: .passed)
            }
            fail("Expected response correlation failure")
        } catch { expectEqual(error as? HarnessError, .protocolMismatch) }
        expectEqual(sessions.session?.state, .paused)
        expectEqual(driver.invalidated, 1)
        let reopened = try ActionLedger(url: directory.appendingPathComponent("journal.json"))
        expectThrows(try reopened.previous(request)) { expectEqual($0 as? HarnessError, .effectUnknown) }
        expectThrows(try engine.execute(request))
        expectEqual(driver.applied, 0)
    }

    func testCompletionWriteFailurePausesWithoutRepeatingEffect() async throws {
        let (engine, sessions, _, request, directory) = try setup()
        var effects = 0
        do {
            _ = try await engine.executeAsync(request) { _ in
                effects += 1
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
                return ActionResult(requestId: request.requestId, effect: .applied, verification: .passed)
            }
            fail("Expected failed completion persistence")
        } catch { expectEqual(error as? HarnessError, .effectUnknown) }
        expectEqual(sessions.session?.state, .paused)
        expectEqual(effects, 1)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        expectThrows(try engine.execute(request))
        let reopened = try ActionLedger(url: directory.appendingPathComponent("journal.json"))
        expectThrows(try reopened.previous(request)) { expectEqual($0 as? HarnessError, .effectUnknown) }
        expectEqual(effects, 1)
    }

    func testPostRenameIntentFailureNeverDispatches() throws {
        let (engine, sessions, driver, request, directory) = try setup(writeCheckpoint: {
            if $0 == .beforeDirectorySync { throw HarnessError.persistenceFailed }
        })
        expectThrows(try engine.execute(request)) { expectEqual($0 as? HarnessError, .persistenceFailed) }
        expectEqual(driver.applied, 0)
        expectEqual(sessions.session?.state, .paused)
        let reopened = try ActionLedger(url: directory.appendingPathComponent("journal.json"))
        expectThrows(try reopened.previous(request)) { expectEqual($0 as? HarnessError, .effectUnknown) }
        expectThrows(try engine.execute(request))
        expectEqual(driver.applied, 0)
    }
    func testPostRenameCompletionFailureDoesNotRepeatEffect() throws {
        var writes = 0
        let (engine, sessions, driver, request, directory) = try setup(writeCheckpoint: {
            if $0 == .beforeDirectorySync {
                writes += 1
                if writes == 2 { throw HarnessError.persistenceFailed }
            }
        })
        expectThrows(try engine.execute(request)) { expectEqual($0 as? HarnessError, .effectUnknown) }
        expectEqual(driver.applied, 1)
        expectEqual(sessions.session?.state, .paused)
        expectThrows(try engine.execute(request))
        expectEqual(driver.applied, 1)
        expectEqual(writes, 2)
        let reopened = try ActionLedger(url: directory.appendingPathComponent("journal.json"))
        let result = try requireValue(reopened.previous(request))
        expectEqual(result.effect, .applied)
        expectEqual(result.verification, .passed)
    }

}
