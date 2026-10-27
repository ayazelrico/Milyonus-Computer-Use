import Foundation
import ComputerUseContracts
import ComputerUseCore

do {
    try JournalCrashFixture.runChildIfRequested()
    try StdioFailureFixture.runIfRequested()
}
catch { exit(72) }

// Focused, bounded reproduction path. It executes the unchanged timing assertions
// and uses only synthetic pipe children, never the native companion.
if CommandLine.arguments.dropFirst().first == "--stdio-inherited-output-stress" {
    guard CommandLine.arguments.count == 2 else { exit(64) }
    for iteration in 1...20 {
        await runAsyncCase("inherited-output-stress.\(iteration)") {
            let test = StdioFailureTests(); defer { test.tearDown() }
            try await test.testReaderStopsWithInheritedOutputStillOpen()
        }
        if failureCount > 0 { break }
    }
    print("STRESS RESULT: \(testCount) cases, \(assertionCount) assertions, \(failureCount) failures")
    exit(failureCount == 0 ? 0 : 1)
}

// Standalone test runner for the Command Line Tools toolchain, which has no XCTest/Testing module.
// Each case is isolated and failures produce a nonzero exit status.
runCase("ContractTests.testPressRejectsText") { let test = ContractTests(); defer { test.tearDown() }; test.testPressRejectsText() }
runCase("ContractTests.testSetValueRequiresText") { let test = ContractTests(); defer { test.tearDown() }; test.testSetValueRequiresText() }
runCase("ContractTests.testUnicodeInputRoundTrip") { let test = ContractTests(); defer { test.tearDown() }; try test.testUnicodeInputRoundTrip() }
runCase("ContractTests.testUTF8LimitUsesBytes") { let test = ContractTests(); defer { test.tearDown() }; test.testUTF8LimitUsesBytes() }
runCase("ContractTests.testNullRejected") { let test = ContractTests(); defer { test.tearDown() }; test.testNullRejected() }
runCase("ContractTests.testPathLikeIdentifierRejected") { let test = ContractTests(); defer { test.tearDown() }; test.testPathLikeIdentifierRejected() }
runCase("ContractTests.testZeroGenerationRejected") { let test = ContractTests(); defer { test.tearDown() }; test.testZeroGenerationRejected() }
runCase("ContractTests.testUnknownActionRejected") { let test = ContractTests(); defer { test.tearDown() }; try test.testUnknownActionRejected() }
runCase("ContractTests.testRetinaNegativeOriginAndCrop") { let test = ContractTests(); defer { test.tearDown() }; try test.testRetinaNegativeOriginAndCrop() }
runCase("ContractTests.testPixelBoundsAndNonfiniteRejected") { let test = ContractTests(); defer { test.tearDown() }; test.testPixelBoundsAndNonfiniteRejected() }
runCase("ContractTests.testCoordinatePropertyAcrossScales") { let test = ContractTests(); defer { test.tearDown() }; try test.testCoordinatePropertyAcrossScales() }
runCase("CoreTests.testUnapprovedSessionCannotExecute") { let test = CoreTests(); defer { test.tearDown() }; try test.testUnapprovedSessionCannotExecute() }
runCase("CoreTests.testArbitraryAppDenied") { let test = CoreTests(); defer { test.tearDown() }; test.testArbitraryAppDenied() }
runCase("CoreTests.testOnlyOneSession") { let test = CoreTests(); defer { test.tearDown() }; try test.testOnlyOneSession() }
runCase("CoreTests.testApprovalAndGenerationFencing") { let test = CoreTests(); defer { test.tearDown() }; try test.testApprovalAndGenerationFencing() }
runCase("CoreTests.testCancellationCannotBeRevived") { let test = CoreTests(); defer { test.tearDown() }; try test.testCancellationCannotBeRevived() }
runCase("CoreTests.testMonotonicExpiry") { let test = CoreTests(); defer { test.tearDown() }; try test.testMonotonicExpiry() }
runCase("CoreTests.testExpiredApprovalRejected") { let test = CoreTests(); defer { test.tearDown() }; try test.testExpiredApprovalRejected() }
runCase("CoreTests.testWrongSessionCannotReadReadyState") { let test = CoreTests(); defer { test.tearDown() }; try test.testWrongSessionCannotReadReadyState() }
runCase("CoreTests.testUnresolvedIntentSurvivesRestart") { let test = CoreTests(); defer { test.tearDown() }; try test.testUnresolvedIntentSurvivesRestart() }
runCase("CoreTests.testDuplicateResultWithoutReexecution") { let test = CoreTests(); defer { test.tearDown() }; try test.testDuplicateResultWithoutReexecution() }
runCase("CoreTests.testSameKeyDifferentPayloadConflict") { let test = CoreTests(); defer { test.tearDown() }; try test.testSameKeyDifferentPayloadConflict() }
runCase("CoreTests.testJournalDoesNotContainText") { let test = CoreTests(); defer { test.tearDown() }; try test.testJournalDoesNotContainText() }
runCase("CoreTests.testCorruptJournalFailsClosed") { let test = CoreTests(); defer { test.tearDown() }; try test.testCorruptJournalFailsClosed() }
runCase("CoreTests.testDuplicateBeginRejected") { let test = CoreTests(); defer { test.tearDown() }; try test.testDuplicateBeginRejected() }
runCase("CoreTests.testCrossProcessLeaseContention") { let test = CoreTests(); defer { test.tearDown() }; try test.testCrossProcessLeaseContention() }
runCase("CoreTests.testLeaseRejectsSymlink") { let test = CoreTests(); defer { test.tearDown() }; try test.testLeaseRejectsSymlink() }
runCase("CoreTests.testExpiredSessionDoesNotBlockNewSession") { let test = CoreTests(); defer { test.tearDown() }; try test.testExpiredSessionDoesNotBlockNewSession() }
runCase("CoreTests.testRepeatedPauseDoesNotChangeGeneration") { let test = CoreTests(); defer { test.tearDown() }; try test.testRepeatedPauseDoesNotChangeGeneration() }
runCase("CoreTests.testFutureJournalVersionPreserved") { let test = CoreTests(); defer { test.tearDown() }; try test.testFutureJournalVersionPreserved() }
runCase("CoreTests.testJournalRejectsSymlink") { let test = CoreTests(); defer { test.tearDown() }; try test.testJournalRejectsSymlink() }
runCase("CoreTests.testJournalRejectsPublicDirectory") { let test = CoreTests(); defer { test.tearDown() }; try test.testJournalRejectsPublicDirectory() }
runCase("CoreTests.testIntentPersistenceFailureDoesNotRemainInMemory") { let test = CoreTests(); defer { test.tearDown() }; try test.testIntentPersistenceFailureDoesNotRemainInMemory() }
runCase("CoreTests.testCompletedJournalSurvivesRestart") { let test = CoreTests(); defer { test.tearDown() }; try test.testCompletedJournalSurvivesRestart() }
runCase("ExecutionTests.testDuplicateRunsNativeEffectOnce") { let test = ExecutionTests(); defer { test.tearDown() }; try test.testDuplicateRunsNativeEffectOnce() }
runCase("ExecutionTests.testPreflightFailureHasNoIntentAndNoEffect") { let test = ExecutionTests(); defer { test.tearDown() }; try test.testPreflightFailureHasNoIntentAndNoEffect() }
runCase("ExecutionTests.testIntentFailurePreventsNativeCall") { let test = ExecutionTests(); defer { test.tearDown() }; try test.testIntentFailurePreventsNativeCall() }
runCase("ExecutionTests.testAdapterExceptionIsUnknownAndPauses") { let test = ExecutionTests(); defer { test.tearDown() }; try test.testAdapterExceptionIsUnknownAndPauses() }
runCase("ExecutionTests.testCancellationPreventsExecution") { let test = ExecutionTests(); defer { test.tearDown() }; try test.testCancellationPreventsExecution() }
runCase("ExecutionTests.testOldGenerationCannotExecuteAfterResume") { let test = ExecutionTests(); defer { test.tearDown() }; try test.testOldGenerationCannotExecuteAfterResume() }
runCase("ExecutionTests.testBudgetStopsSecondEffectButAllowsReadback") { let test = ExecutionTests(); defer { test.tearDown() }; try test.testBudgetStopsSecondEffectButAllowsReadback() }
runCase("ExecutionTests.testMalformedRequestNeverReachesNativeDriver") { let test = ExecutionTests(); defer { test.tearDown() }; try test.testMalformedRequestNeverReachesNativeDriver() }
await runAsyncCase("AgentTests.testPlannerActionUsesFreshHandlesAndHostCompletion") { let test = AgentTests(); defer { test.tearDown() }; try await test.testPlannerActionUsesFreshHandlesAndHostCompletion() }
await runAsyncCase("AgentTests.testFalsePlannerCompletionFailsIndependentVerification") { let test = AgentTests(); defer { test.tearDown() }; try await test.testFalsePlannerCompletionFailsIndependentVerification() }
await runAsyncCase("AgentTests.testUnknownEffectNeverRetries") { let test = AgentTests(); defer { test.tearDown() }; try await test.testUnknownEffectNeverRetries() }
await runAsyncCase("AgentTests.testStepBudgetCancelsSession") { let test = AgentTests(); defer { test.tearDown() }; try await test.testStepBudgetCancelsSession() }
await runAsyncCase("InputTests.testInputPermissionCheckedBeforeEveryEvent") { let test = InputTests(); defer { test.tearDown() }; try await test.testInputPermissionCheckedBeforeEveryEvent() }
await runAsyncCase("InputTests.testEmitterFailureStillReleasesHeldMouse") { let test = InputTests(); defer { test.tearDown() }; try await test.testEmitterFailureStillReleasesHeldMouse() }
await runAsyncCase("InputTests.testInvalidCoordinatesDispatchNothing") { let test = InputTests(); defer { test.tearDown() }; try await test.testInvalidCoordinatesDispatchNothing() }
await runAsyncCase("InputTests.testCancelDuringDelayReleasesAndFencesNextEvent") { let test = InputTests(); defer { test.tearDown() }; try await test.testCancelDuringDelayReleasesAndFencesNextEvent() }
await runAsyncCase("InputTests.testSequenceBudgetRejectsBeforeDispatch") { let test = InputTests(); defer { test.tearDown() }; try await test.testSequenceBudgetRejectsBeforeDispatch() }
await runAsyncCase("ExecutionTests.testAsyncExecutionRetainsClaimAndHonorsCancellation") { let test = ExecutionTests(); defer { test.tearDown() }; try await test.testAsyncExecutionRetainsClaimAndHonorsCancellation() }
await runAsyncCase("ExecutionTests.testIdempotencyDistinguishesExecutionMethods") { let test = ExecutionTests(); defer { test.tearDown() }; try await test.testIdempotencyDistinguishesExecutionMethods() }
await runAsyncCase("AgentTests.testNoProgressStopsRepeatedNoOpActions") { let test = AgentTests(); defer { test.tearDown() }; try await test.testNoProgressStopsRepeatedNoOpActions() }
await runAsyncCase("AgentTests.testObservationScopeMismatchNeverReachesPlanner") { let test = AgentTests(); defer { test.tearDown() }; try await test.testObservationScopeMismatchNeverReachesPlanner() }
runCase("HeartbeatTests.testMissingHeartbeatPausesAndInvalidatesOnce") { let test = HeartbeatTests(); defer { test.tearDown() }; try test.testMissingHeartbeatPausesAndInvalidatesOnce() }
runCase("HeartbeatTests.testHeartbeatRenewsButDoesNotExtendSessionLifetime") { let test = HeartbeatTests(); defer { test.tearDown() }; try test.testHeartbeatRenewsButDoesNotExtendSessionLifetime() }
runCase("HeartbeatTests.testHeartbeatCannotApprovePendingSession") { let test = HeartbeatTests(); defer { test.tearDown() }; try test.testHeartbeatCannotApprovePendingSession() }
runCase("HeartbeatTests.testWrongGenerationCannotRenewLease") { let test = HeartbeatTests(); defer { test.tearDown() }; try test.testWrongGenerationCannotRenewLease() }
runCase("HeartbeatTests.testResumeNeedsNativeApprovalAndFreshGeneration") { let test = HeartbeatTests(); defer { test.tearDown() }; try test.testResumeNeedsNativeApprovalAndFreshGeneration() }
runCase("HeartbeatTests.testTerminalStateDoesNotChangeOnRepeatedReadsOrCancellation") { let test = HeartbeatTests(); defer { test.tearDown() }; try test.testTerminalStateDoesNotChangeOnRepeatedReadsOrCancellation() }
runCase("HeartbeatTests.testNativeOnlySessionDoesNotRequireClientHeartbeat") { let test = HeartbeatTests(); defer { test.tearDown() }; try test.testNativeOnlySessionDoesNotRequireClientHeartbeat() }
await runAsyncCase("ProviderTests.testValidActionAndMinimizedEgress") { let test = ProviderTests(); defer { test.tearDown() }; try await test.testValidActionAndMinimizedEgress() }
await runAsyncCase("ProviderTests.testFinishUsesExplicitNulls") { let test = ProviderTests(); defer { test.tearDown() }; try await test.testFinishUsesExplicitNulls() }
await runAsyncCase("ProviderTests.testScopeMismatchNeverSends") { let test = ProviderTests(); defer { test.tearDown() }; try await test.testScopeMismatchNeverSends() }
await runAsyncCase("ProviderTests.testExpiredDeadlineNeverSends") { let test = ProviderTests(); defer { test.tearDown() }; try await test.testExpiredDeadlineNeverSends() }
await runAsyncCase("ProviderTests.testRateLimitDoesNotRetry") { let test = ProviderTests(); defer { test.tearDown() }; try await test.testRateLimitDoesNotRetry() }
await runAsyncCase("ProviderTests.testIncompleteResponseCannotExecute") { let test = ProviderTests(); defer { test.tearDown() }; try await test.testIncompleteResponseCannotExecute() }
await runAsyncCase("ProviderTests.testUnknownFieldsAndTargetsRejected") { let test = ProviderTests(); defer { test.tearDown() }; try await test.testUnknownFieldsAndTargetsRejected() }
await runAsyncCase("ProviderTests.testRefusalIsNotAnAction") { let test = ProviderTests(); defer { test.tearDown() }; try await test.testRefusalIsNotAnAction() }
await runAsyncCase("ProviderTests.testOversizedResponseRejected") { let test = ProviderTests(); defer { test.tearDown() }; try await test.testOversizedResponseRejected() }
runCase("ProviderTests.testEgressMustBeExplicit") { let test = ProviderTests(); defer { test.tearDown() }; try test.testEgressMustBeExplicit() }
await runAsyncCase("AgentTests.testUnavailableVerificationStopsWithoutRetry") { let test = AgentTests(); defer { test.tearDown() }; try await test.testUnavailableVerificationStopsWithoutRetry() }
await runAsyncCase("AgentTests.testGenerationChangeBeforeFinishIsRejected") { let test = AgentTests(); defer { test.tearDown() }; try await test.testGenerationChangeBeforeFinishIsRejected() }
await runAsyncCase("AnthropicProviderTests.testValidActionAndMinimizedEgress") { let test = AnthropicProviderTests(); defer { test.tearDown() }; try await test.testValidActionAndMinimizedEgress() }
await runAsyncCase("AnthropicProviderTests.testFinishUsesExplicitNulls") { let test = AnthropicProviderTests(); defer { test.tearDown() }; try await test.testFinishUsesExplicitNulls() }
await runAsyncCase("AnthropicProviderTests.testScopeMismatchNeverSends") { let test = AnthropicProviderTests(); defer { test.tearDown() }; try await test.testScopeMismatchNeverSends() }
await runAsyncCase("AnthropicProviderTests.testExpiredDeadlineNeverSends") { let test = AnthropicProviderTests(); defer { test.tearDown() }; try await test.testExpiredDeadlineNeverSends() }
await runAsyncCase("AnthropicProviderTests.testRateLimitDoesNotRetry") { let test = AnthropicProviderTests(); defer { test.tearDown() }; try await test.testRateLimitDoesNotRetry() }
await runAsyncCase("AnthropicProviderTests.testIncompleteResponseCannotExecute") { let test = AnthropicProviderTests(); defer { test.tearDown() }; try await test.testIncompleteResponseCannotExecute() }
await runAsyncCase("AnthropicProviderTests.testUnknownFieldsAndTargetsRejected") { let test = AnthropicProviderTests(); defer { test.tearDown() }; try await test.testUnknownFieldsAndTargetsRejected() }
await runAsyncCase("AnthropicProviderTests.testRefusalIsNotAnAction") { let test = AnthropicProviderTests(); defer { test.tearDown() }; try await test.testRefusalIsNotAnAction() }
await runAsyncCase("AnthropicProviderTests.testOversizedResponseRejected") { let test = AnthropicProviderTests(); defer { test.tearDown() }; try await test.testOversizedResponseRejected() }
runCase("AnthropicProviderTests.testEgressMustBeExplicit") { let test = AnthropicProviderTests(); defer { test.tearDown() }; try test.testEgressMustBeExplicit() }
await runAsyncCase("AnthropicProviderTests.testMultipleOrUnknownToolsRejected") { let test = AnthropicProviderTests(); defer { test.tearDown() }; try await test.testMultipleOrUnknownToolsRejected() }
await runAsyncCase("IntegrationTests.testDisabledFeatureCannotLaunch") { let test = IntegrationTests(); defer { test.tearDown() }; try await test.testDisabledFeatureCannotLaunch() }
await runAsyncCase("IntegrationTests.testExistingModesCannotLaunch") { let test = IntegrationTests(); defer { test.tearDown() }; try await test.testExistingModesCannotLaunch() }
await runAsyncCase("IntegrationTests.testApprovalAndExclusiveOwnership") { let test = IntegrationTests(); defer { test.tearDown() }; try await test.testApprovalAndExclusiveOwnership() }
await runAsyncCase("IntegrationTests.testStopInvalidatesLateConnection") { let test = IntegrationTests(); defer { test.tearDown() }; try await test.testStopInvalidatesLateConnection() }
await runAsyncCase("IntegrationTests.testVerifiedCompletionClosesTransport") { let test = IntegrationTests(); defer { test.tearDown() }; try await test.testVerifiedCompletionClosesTransport() }
await runAsyncCase("IntegrationTests.testPauseDoesNotResumeAutomatically") { let test = IntegrationTests(); defer { test.tearDown() }; try await test.testPauseDoesNotResumeAutomatically() }
await runAsyncCase("IntegrationTests.testOlderPollCannotOverwriteNewerState") { let test = IntegrationTests(); defer { test.tearDown() }; try await test.testOlderPollCannotOverwriteNewerState() }
await runAsyncCase("IntegrationTests.testStopDuringPlanningCannotBecomeCompleted") { let test = IntegrationTests(); defer { test.tearDown() }; try await test.testStopDuringPlanningCannotBecomeCompleted() }
runCase("CoreTests.testCompletionRejectsChangedIntent") { let test = CoreTests(); defer { test.tearDown() }; try test.testCompletionRejectsChangedIntent() }
runCase("CoreTests.testCompletionBindsExecutionMethod") { let test = CoreTests(); defer { test.tearDown() }; try test.testCompletionBindsExecutionMethod() }
runCase("CoreTests.testCompletionRejectsWrongResponseCorrelation") { let test = CoreTests(); defer { test.tearDown() }; try test.testCompletionRejectsWrongResponseCorrelation() }
runCase("CoreTests.testCompletionIsImmutableAcrossRestart") { let test = CoreTests(); defer { test.tearDown() }; try test.testCompletionIsImmutableAcrossRestart() }
runCase("CoreTests.testJournalRejectsFIFOWithoutWaitingForWriter") { let test = CoreTests(); defer { test.tearDown() }; try test.testJournalRejectsFIFOWithoutWaitingForWriter() }
runCase("CoreTests.testJournalRejectsHardLink") { let test = CoreTests(); defer { test.tearDown() }; try test.testJournalRejectsHardLink() }
runCase("CoreTests.testLeaseRejectsPublicFileAndHardLink") { let test = CoreTests(); defer { test.tearDown() }; try test.testLeaseRejectsPublicFileAndHardLink() }
runCase("CoreTests.testLeaseRejectsPublicParent") { let test = CoreTests(); defer { test.tearDown() }; try test.testLeaseRejectsPublicParent() }
await runAsyncCase("ExecutionTests.testNativeMethodCompletionCanBeReplayedWithoutDispatch") { let test = ExecutionTests(); defer { test.tearDown() }; try await test.testNativeMethodCompletionCanBeReplayedWithoutDispatch() }
await runAsyncCase("ExecutionTests.testWrongCompletionCorrelationPausesAndPreservesIntent") { let test = ExecutionTests(); defer { test.tearDown() }; try await test.testWrongCompletionCorrelationPausesAndPreservesIntent() }
runCase("CoreTests.testFailedCompletionFreezesJournalWrites") { let test = CoreTests(); defer { test.tearDown() }; try test.testFailedCompletionFreezesJournalWrites() }
runCase("CoreTests.testFailedIntentRequiresReopenBeforeWriting") { let test = CoreTests(); defer { test.tearDown() }; try test.testFailedIntentRequiresReopenBeforeWriting() }
runCase("CoreTests.testRenameFailureCleansTemporaryJournal") { let test = CoreTests(); defer { test.tearDown() }; try test.testRenameFailureCleansTemporaryJournal() }
await runAsyncCase("ExecutionTests.testCompletionWriteFailurePausesWithoutRepeatingEffect") { let test = ExecutionTests(); defer { test.tearDown() }; try await test.testCompletionWriteFailurePausesWithoutRepeatingEffect() }
runCase("CoreTests.testIntentFailureAtDurabilityBoundaries") { let test = CoreTests(); defer { test.tearDown() }; try test.testIntentFailureAtDurabilityBoundaries() }
runCase("CoreTests.testCompletionFailureAtDurabilityBoundaries") { let test = CoreTests(); defer { test.tearDown() }; try test.testCompletionFailureAtDurabilityBoundaries() }
runCase("ExecutionTests.testPostRenameIntentFailureNeverDispatches") { let test = ExecutionTests(); defer { test.tearDown() }; try test.testPostRenameIntentFailureNeverDispatches() }
runCase("ExecutionTests.testPostRenameCompletionFailureDoesNotRepeatEffect") { let test = ExecutionTests(); defer { test.tearDown() }; try test.testPostRenameCompletionFailureDoesNotRepeatEffect() }
await runAsyncCase("JournalCrashTests.testAbruptExitDuringIntent") { let test = JournalCrashTests(); defer { test.tearDown() }; try await test.testAbruptExitDuringIntent() }
await runAsyncCase("JournalCrashTests.testAbruptExitDuringCompletion") { let test = JournalCrashTests(); defer { test.tearDown() }; try await test.testAbruptExitDuringCompletion() }
runCase("JournalAdmissionTests.testMalformedEntriesRejectedWithoutRepair") { let test = JournalAdmissionTests(); defer { test.tearDown() }; try test.testMalformedEntriesRejectedWithoutRepair() }
runCase("JournalAdmissionTests.testEntryCountAndDuplicateKeysRejected") { let test = JournalAdmissionTests(); defer { test.tearDown() }; try test.testEntryCountAndDuplicateKeysRejected() }
runCase("JournalAdmissionTests.testFullJournalAllowsCompletionButRejectsNewIntent") { let test = JournalAdmissionTests(); defer { test.tearDown() }; try test.testFullJournalAllowsCompletionButRejectsNewIntent() }
runCase("JournalAdmissionTests.testOversizedJournalRejectedWithoutTruncation") { let test = JournalAdmissionTests(); defer { test.tearDown() }; try test.testOversizedJournalRejectedWithoutTruncation() }
runCase("JournalAdmissionTests.testInvalidNewRecordsNeverPersist") { let test = JournalAdmissionTests(); defer { test.tearDown() }; try test.testInvalidNewRecordsNeverPersist() }
runCase("RPCReplyTests.testInvalidIDsCannotConsumePendingRequest") { let test = RPCReplyTests(); defer { test.tearDown() }; test.testInvalidIDsCannotConsumePendingRequest() }
runCase("RPCReplyTests.testMalformedEnvelopesRejected") { let test = RPCReplyTests(); defer { test.tearDown() }; test.testMalformedEnvelopesRejected() }
runCase("RPCReplyTests.testValidRepliesAndNotifications") { let test = RPCReplyTests(); defer { test.tearDown() }; try test.testValidRepliesAndNotifications() }
await runAsyncCase("StdioFailureTests.testInvalidPipeRepliesCloseTransport") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testInvalidPipeRepliesCloseTransport() }
await runAsyncCase("StdioFailureTests.testValidPipeReplyStillConnects") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testValidPipeReplyStillConnects() }
await runAsyncCase("StdioFailureTests.testMalformedToolResultsCloseTransport") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testMalformedToolResultsCloseTransport() }
await runAsyncCase("StdioFailureTests.testDomainRefusalDoesNotCloseTransport") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testDomainRefusalDoesNotCloseTransport() }
runCase("ToolReplyTests.testMalformedToolEnvelopesRejected") { let test = ToolReplyTests(); defer { test.tearDown() }; try test.testMalformedToolEnvelopesRejected() }
runCase("ToolReplyTests.testValueAndDomainFailureRemainDistinct") { let test = ToolReplyTests(); defer { test.tearDown() }; try test.testValueAndDomainFailureRemainDistinct() }
await runAsyncCase("StdioFailureTests.testInvalidActionResponsesCloseAllMutationRoutes") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testInvalidActionResponsesCloseAllMutationRoutes() }
await runAsyncCase("StdioFailureTests.testCorrelatedActionResponsesPreserveOutcome") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testCorrelatedActionResponsesPreserveOutcome() }
await runAsyncCase("StdioFailureTests.testSessionAndObservationMismatchesCloseTransport") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testSessionAndObservationMismatchesCloseTransport() }
await runAsyncCase("StdioFailureTests.testCorrelatedSessionAndObservationControls") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testCorrelatedSessionAndObservationControls() }
await runAsyncCase("StdioFailureTests.testPreCancelledRequestNeverDispatches") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testPreCancelledRequestNeverDispatches() }
await runAsyncCase("StdioFailureTests.testCancellingPendingCallDrainsSiblingRequests") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testCancellingPendingCallDrainsSiblingRequests() }
await runAsyncCase("StdioFailureTests.testShutdownDrainsPendingCallIdempotently") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testShutdownDrainsPendingCallIdempotently() }
await runAsyncCase("StdioFailureTests.testLateReplyAfterCancellationCannotReviveCall") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testLateReplyAfterCancellationCannotReviveCall() }
await runAsyncCase("StdioFailureTests.testShutdownEscalatesOnlyOwnedUnresponsiveChild") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testShutdownEscalatesOnlyOwnedUnresponsiveChild() }
await runAsyncCase("StdioFailureTests.testCancellationEscalatesUnresponsiveChild") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testCancellationEscalatesUnresponsiveChild() }
await runAsyncCase("StdioFailureTests.testCooperativeChildExitsWithoutEscalation") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testCooperativeChildExitsWithoutEscalation() }
await runAsyncCase("StdioFailureTests.testShutdownRemainsResponsiveUnderWriteBackpressure") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testShutdownRemainsResponsiveUnderWriteBackpressure() }
await runAsyncCase("StdioFailureTests.testTaskCancellationRemainsResponsiveUnderWriteBackpressure") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testTaskCancellationRemainsResponsiveUnderWriteBackpressure() }
await runAsyncCase("StdioFailureTests.testPartialWritesPreserveRequestFrames") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testPartialWritesPreserveRequestFrames() }
await runAsyncCase("StdioFailureTests.testBlockedWritesExpireWithoutReplay") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testBlockedWritesExpireWithoutReplay() }
await runAsyncCase("StdioFailureTests.testReaderStopsWithInheritedOutputStillOpen") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testReaderStopsWithInheritedOutputStillOpen() }
await runAsyncCase("StdioFailureTests.testCompletedRequestsReleaseTimeoutTasks") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testCompletedRequestsReleaseTimeoutTasks() }
await runAsyncCase("StdioFailureTests.testShutdownReleasesPendingTimeoutTasks") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testShutdownReleasesPendingTimeoutTasks() }
await runAsyncCase("StdioFailureTests.testClosedInputDoesNotSignalSDKOrReplay") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testClosedInputDoesNotSignalSDKOrReplay() }
await runAsyncCase("StdioFailureTests.testPendingLimitRefusesNewWorkWithoutEviction") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testPendingLimitRefusesNewWorkWithoutEviction() }
runCase("StrictJSONTests.testDuplicateMembersRejectedAtEveryDepth") { let test = StrictJSONTests(); defer { test.tearDown() }; test.testDuplicateMembersRejectedAtEveryDepth() }
runCase("StrictJSONTests.testValidJSONStringsAndSiblingKeysPreserved") { let test = StrictJSONTests(); defer { test.tearDown() }; try test.testValidJSONStringsAndSiblingKeysPreserved() }
runCase("StrictJSONTests.testNestingAndByteBounds") { let test = StrictJSONTests(); defer { test.tearDown() }; try test.testNestingAndByteBounds() }
runCase("StrictJSONTests.testMalformedSyntaxAndNonUTF8Rejected") { let test = StrictJSONTests(); defer { test.tearDown() }; test.testMalformedSyntaxAndNonUTF8Rejected() }
runCase("StrictJSONTests.testAmbiguousRequestsRejectedBeforeDispatch") { let test = StrictJSONTests(); defer { test.tearDown() }; try test.testAmbiguousRequestsRejectedBeforeDispatch() }
runCase("PointerGestureTests.testDragGeometryAndTiming") { let test = PointerGestureTests(); defer { test.tearDown() }; try test.testDragGeometryAndTiming() }
runCase("PointerGestureTests.testInvalidGeometryAndBudgets") { let test = PointerGestureTests(); defer { test.tearDown() }; test.testInvalidGeometryAndBudgets() }
runCase("PointerGestureTests.testScrollConservesSignedDeltas") { let test = PointerGestureTests(); defer { test.tearDown() }; try test.testScrollConservesSignedDeltas() }
await runAsyncCase("PointerGestureTests.testDragRevocationReleasesAtLastPosition") { let test = PointerGestureTests(); defer { test.tearDown() }; try await test.testDragRevocationReleasesAtLastPosition() }
runCase("ScrollExecutionTests.testScrollContractRoundTripAndBounds") { let test = ScrollExecutionTests(); defer { test.tearDown() }; try test.testScrollContractRoundTripAndBounds() }
await runAsyncCase("ScrollExecutionTests.testScrollMethodGatePrecedesJournal") { let test = ScrollExecutionTests(); defer { test.tearDown() }; try await test.testScrollMethodGatePrecedesJournal() }
await runAsyncCase("ScrollExecutionTests.testScrollDuplicateAndChangedDelta") { let test = ScrollExecutionTests(); defer { test.tearDown() }; try await test.testScrollDuplicateAndChangedDelta() }
await runAsyncCase("ScrollExecutionTests.testUnknownScrollPausesWithoutReplay") { let test = ScrollExecutionTests(); defer { test.tearDown() }; try await test.testUnknownScrollPausesWithoutReplay() }
runCase("DragExecutionTests.testReceiptRequiresCounterAndBothEndpoints") { let test = DragExecutionTests(); defer { test.tearDown() }; try test.testReceiptRequiresCounterAndBothEndpoints() }
runCase("DragExecutionTests.testDragContractForbidsOtherPayloads") { let test = DragExecutionTests(); defer { test.tearDown() }; try test.testDragContractForbidsOtherPayloads() }
await runAsyncCase("DragExecutionTests.testDragMethodAdmissionAndDuplicateSuppression") { let test = DragExecutionTests(); defer { test.tearDown() }; try await test.testDragMethodAdmissionAndDuplicateSuppression() }
await runAsyncCase("DragExecutionTests.testDragFailurePausesAndRetainsUnknownIntentResult") { let test = DragExecutionTests(); defer { test.tearDown() }; try await test.testDragFailurePausesAndRetainsUnknownIntentResult() }
await runAsyncCase("DragExecutionTests.testCancelledDragReleasesBeforeEndpoint") { let test = DragExecutionTests(); defer { test.tearDown() }; try await test.testCancelledDragReleasesBeforeEndpoint() }
await runAsyncCase("GestureAcceptanceTests.testIndependentCompletionAndFreshTargets") { let test = GestureAcceptanceTests(); defer { test.tearDown() }; try await test.testIndependentCompletionAndFreshTargets() }
await runAsyncCase("GestureAcceptanceTests.testAdmissionRejectsBeforeMutation") { let test = GestureAcceptanceTests(); defer { test.tearDown() }; try await test.testAdmissionRejectsBeforeMutation() }
await runAsyncCase("GestureAcceptanceTests.testUnknownOrChangedStateNeverDispatchesDrag") { let test = GestureAcceptanceTests(); defer { test.tearDown() }; try await test.testUnknownOrChangedStateNeverDispatchesDrag() }
await runAsyncCase("GestureAcceptanceTests.testPartialDragCannotPassOrRetry") { let test = GestureAcceptanceTests(); defer { test.tearDown() }; try await test.testPartialDragCannotPassOrRetry() }
await runAsyncCase("GestureAcceptanceTests.testCancellationDuringStatusStopsNextMutation") { let test = GestureAcceptanceTests(); defer { test.tearDown() }; try await test.testCancellationDuringStatusStopsNextMutation() }
runCase("CapabilitiesTests.testCurrentContractDoesNotRequirePermissions") { let test = CapabilitiesTests(); defer { test.tearDown() }; try test.testCurrentContractDoesNotRequirePermissions() }
runCase("CapabilitiesTests.testIncompatiblePolicyAndLimitsRejected") { let test = CapabilitiesTests(); defer { test.tearDown() }; try test.testIncompatiblePolicyAndLimitsRejected() }
await runAsyncCase("CapabilitiesTests.testMalformedCapabilitiesCloseTransport") { let test = CapabilitiesTests(); defer { test.tearDown() }; try await test.testMalformedCapabilitiesCloseTransport() }
await runAsyncCase("CapabilitiesTests.testCapabilityReadsDoNotOpenSession") { let test = CapabilitiesTests(); defer { test.tearDown() }; try await test.testCapabilityReadsDoNotOpenSession() }
await runAsyncCase("NegotiatedClientTests.testDisabledFeaturesNeverDispatch") { let test = NegotiatedClientTests(); defer { test.tearDown() }; try await test.testDisabledFeaturesNeverDispatch() }
await runAsyncCase("NegotiatedClientTests.testFreshLimitsAndRevocation") { let test = NegotiatedClientTests(); defer { test.tearDown() }; try await test.testFreshLimitsAndRevocation() }
await runAsyncCase("NegotiatedClientTests.testUnknownResultIsNotRetriedAndCancelBypassesDiscovery") { let test = NegotiatedClientTests(); defer { test.tearDown() }; try await test.testUnknownResultIsNotRetriedAndCancelBypassesDiscovery() }
await runAsyncCase("GestureAcceptanceTests.testUpwardScrollUsesInteriorDirection") { let test = GestureAcceptanceTests(); defer { test.tearDown() }; try await test.testUpwardScrollUsesInteriorDirection() }
await runAsyncCase("GestureAcceptanceTests.testAmbiguousAndMalformedScrollbarsCannotStart") { let test = GestureAcceptanceTests(); defer { test.tearDown() }; try await test.testAmbiguousAndMalformedScrollbarsCannotStart() }
await runAsyncCase("GestureAcceptanceTests.testWrongDirectionAndResizedTargetsCannotPass") { let test = GestureAcceptanceTests(); defer { test.tearDown() }; try await test.testWrongDirectionAndResizedTargetsCannotPass() }
runCase("CaptureGeometryTests.testUniformScalingPreservesWideAndTallFrames") { let test = CaptureGeometryTests(); defer { test.tearDown() }; try test.testUniformScalingPreservesWideAndTallFrames() }
runCase("CaptureGeometryTests.testMalformedAndOverflowingBoundsRefused") { let test = CaptureGeometryTests(); defer { test.tearDown() }; test.testMalformedAndOverflowingBoundsRefused() }
runCase("CaptureGeometryTests.testHugeFiniteDimensionsDoNotTrapAndTransformsDoNotOverflow") { let test = CaptureGeometryTests(); defer { test.tearDown() }; try test.testHugeFiniteDimensionsDoNotTrapAndTransformsDoNotOverflow() }
runCase("CaptureGeometryTests.testFractionalAndExtremeAspectRatiosRemainBounded") { let test = CaptureGeometryTests(); defer { test.tearDown() }; try test.testFractionalAndExtremeAspectRatiosRemainBounded() }
runCase("CaptureDeadlineTests.testExactBoundaryAndDelayedResultRejected") { let test = CaptureDeadlineTests(); defer { test.tearDown() }; try test.testExactBoundaryAndDelayedResultRejected() }
runCase("CaptureDeadlineTests.testRepeatedChecksCannotExtendDeadline") { let test = CaptureDeadlineTests(); defer { test.tearDown() }; try test.testRepeatedChecksCannotExtendDeadline() }
runCase("CaptureDeadlineTests.testInvalidBudgetsRejected") { let test = CaptureDeadlineTests(); defer { test.tearDown() }; test.testInvalidBudgetsRejected() }
await runAsyncCase("CaptureDeadlineTests.testCancellationRejectsEvenBeforeExpiry") { let test = CaptureDeadlineTests(); defer { test.tearDown() }; try await test.testCancellationRejectsEvenBeforeExpiry() }
runCase("FixtureCaptureSelectionTests.testOnlyUniqueMainFixtureIsSelected") { let test = FixtureCaptureSelectionTests(); defer { test.tearDown() }; try test.testOnlyUniqueMainFixtureIsSelected() }
runCase("FixtureCaptureSelectionTests.testInvalidIdentityAndGeometryCannotBeSelected") { let test = FixtureCaptureSelectionTests(); defer { test.tearDown() }; test.testInvalidIdentityAndGeometryCannotBeSelected() }
runCase("FixtureCaptureSelectionTests.testCaptureRejectsReplacementMovementAndNewAmbiguity") { let test = FixtureCaptureSelectionTests(); defer { test.tearDown() }; try test.testCaptureRejectsReplacementMovementAndNewAmbiguity() }
runCase("ObservationTraversalBudgetTests.testDeadlineIncludesFinalReadAndDoesNotRenew") { let test = ObservationTraversalBudgetTests(); defer { test.tearDown() }; test.testDeadlineIncludesFinalReadAndDoesNotRenew() }
runCase("ObservationTraversalBudgetTests.testVisitedNodesIncludeNodesWithoutExportedText") { let test = ObservationTraversalBudgetTests(); defer { test.tearDown() }; test.testVisitedNodesIncludeNodesWithoutExportedText() }
runCase("ObservationTraversalBudgetTests.testDepthAndTextBoundsLatchTruncationWithoutOverflow") { let test = ObservationTraversalBudgetTests(); defer { test.tearDown() }; test.testDepthAndTextBoundsLatchTruncationWithoutOverflow() }
runCase("ExecutionTests.testObservationLeaseExpiryInvalidatesTargets") { let test = ExecutionTests(); defer { test.tearDown() }; try test.testObservationLeaseExpiryInvalidatesTargets() }
runCase("ExecutionTests.testObservationGenerationAndScopeCannotChangeDuringRead") { let test = ExecutionTests(); defer { test.tearDown() }; try test.testObservationGenerationAndScopeCannotChangeDuringRead() }
runCase("ExecutionTests.testObservationFailureInvalidatesTargets") { let test = ExecutionTests(); defer { test.tearDown() }; try test.testObservationFailureInvalidatesTargets() }
await runAsyncCase("ExecutionTests.testObservationTaskCancellationCannotPublish") { let test = ExecutionTests(); defer { test.tearDown() }; try await test.testObservationTaskCancellationCannotPublish() }
runCase("ExecutionTests.testPreflightExpiryAndGenerationChangeCannotWriteIntent") { let test = ExecutionTests(); defer { test.tearDown() }; try test.testPreflightExpiryAndGenerationChangeCannotWriteIntent() }
await runAsyncCase("ExecutionTests.testJournalExpiryPreventsSemanticAndAsyncDispatch") { let test = ExecutionTests(); defer { test.tearDown() }; try await test.testJournalExpiryPreventsSemanticAndAsyncDispatch() }
await runAsyncCase("ExecutionTests.testTaskCancellationBeforeAndAfterIntent") { let test = ExecutionTests(); defer { test.tearDown() }; try await test.testTaskCancellationBeforeAndAfterIntent() }
await runAsyncCase("ExecutionTests.testLateCompletionPreservesEffectWithoutVerification") { let test = ExecutionTests(); defer { test.tearDown() }; try await test.testLateCompletionPreservesEffectWithoutVerification() }
await runAsyncCase("ExecutionTests.testCancelledCompletionReceiptCannotRepeatEffect") { let test = ExecutionTests(); defer { test.tearDown() }; try await test.testCancelledCompletionReceiptCannotRepeatEffect() }
await runAsyncCase("ExecutionTests.testLateCompletionDoesNotReviveCancelledSessionOrAlterReplacement") { let test = ExecutionTests(); defer { test.tearDown() }; try await test.testLateCompletionDoesNotReviveCancelledSessionOrAlterReplacement() }
runCase("ActionResultTests.testEffectVerificationMatrix") { let test = ActionResultTests(); defer { test.tearDown() }; try test.testEffectVerificationMatrix() }
runCase("ActionResultTests.testMalformedResultIdentifiers") { let test = ActionResultTests(); defer { test.tearDown() }; test.testMalformedResultIdentifiers() }
runCase("JournalAdmissionTests.testContradictoryResultsCannotCompleteOrReopen") { let test = JournalAdmissionTests(); defer { test.tearDown() }; try test.testContradictoryResultsCannotCompleteOrReopen() }
await runAsyncCase("ExecutionTests.testContradictoryCompletionRetainsUnknownIntent") { let test = ExecutionTests(); defer { test.tearDown() }; try await test.testContradictoryCompletionRetainsUnknownIntent() }
await runAsyncCase("StdioFailureTests.testConcurrentOpenRefusedBeforeSecondRPC") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testConcurrentOpenRefusedBeforeSecondRPC() }
await runAsyncCase("StdioFailureTests.testCancelWhileOpeningCannotAdoptLateSession") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testCancelWhileOpeningCannotAdoptLateSession() }
await runAsyncCase("StdioFailureTests.testHeartbeatCannotRenewAfterOwnershipCancellation") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testHeartbeatCannotRenewAfterOwnershipCancellation() }
await runAsyncCase("StdioFailureTests.testOldHeartbeatCannotFollowReusedSessionIdentity") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testOldHeartbeatCannotFollowReusedSessionIdentity() }
await runAsyncCase("StdioFailureTests.testCurrentHeartbeatTickStillRenewsAndStopsAfterShutdown") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testCurrentHeartbeatTickStillRenewsAndStopsAfterShutdown() }
runCase("ObservationValidationTests.testStructuralLimitsAndUniqueHandles") { let test = ObservationValidationTests(); defer { test.tearDown() }; try test.testStructuralLimitsAndUniqueHandles() }
runCase("ObservationValidationTests.testAggregateTextUsesUTF8AndExclusiveLimit") { let test = ObservationValidationTests(); defer { test.tearDown() }; try test.testAggregateTextUsesUTF8AndExclusiveLimit() }
runCase("ExecutionTests.testMalformedDriverObservationInvalidatesTargets") { let test = ExecutionTests(); defer { test.tearDown() }; try test.testMalformedDriverObservationInvalidatesTargets() }
runCase("SessionValidationTests.testPauseReasonBelongsOnlyToPausedState") { let test = SessionValidationTests(); defer { test.tearDown() }; try test.testPauseReasonBelongsOnlyToPausedState() }
runCase("SessionValidationTests.testMetadataBoundsAndFiniteTime") { let test = SessionValidationTests(); defer { test.tearDown() }; try test.testMetadataBoundsAndFiniteTime() }
runCase("SessionValidationTests.testNativeControllerTransitionsRemainConsistent") { let test = SessionValidationTests(); defer { test.tearDown() }; try test.testNativeControllerTransitionsRemainConsistent() }
await runAsyncCase("AgentTests.testInvalidAdapterDataNeverReachesPlanner") { let test = AgentTests(); defer { test.tearDown() }; try await test.testInvalidAdapterDataNeverReachesPlanner() }
await runAsyncCase("AgentTests.testFreshObservationCannotBeTruncatedOrReused") { let test = AgentTests(); defer { test.tearDown() }; try await test.testFreshObservationCannotBeTruncatedOrReused() }
await runAsyncCase("AgentTests.testMalformedCustomAdapterResultStopsWithoutRetry") { let test = AgentTests(); defer { test.tearDown() }; try await test.testMalformedCustomAdapterResultStopsWithoutRetry() }
await runAsyncCase("PlannerAdmissionTests.testInvalidContextNeverReadsCredentialsOrSends") { let test = PlannerAdmissionTests(); defer { test.tearDown() }; try await test.testInvalidContextNeverReadsCredentialsOrSends() }
await runAsyncCase("PlannerResponseValidationTests.testOpenAIDuplicateMembersRejectedAtBothJSONLayers") { let test = PlannerResponseValidationTests(); defer { test.tearDown() }; try await test.testOpenAIDuplicateMembersRejectedAtBothJSONLayers() }
await runAsyncCase("PlannerResponseValidationTests.testAnthropicDuplicateMembersRejectedInEnvelopeAndInput") { let test = PlannerResponseValidationTests(); defer { test.tearDown() }; try await test.testAnthropicDuplicateMembersRejectedInEnvelopeAndInput() }
await runAsyncCase("PlannerResponseValidationTests.testDeepIgnoredMetadataCannotBypassBounds") { let test = PlannerResponseValidationTests(); defer { test.tearDown() }; try await test.testDeepIgnoredMetadataCannotBypassBounds() }
await runAsyncCase("StdioFailureTests.testTimeoutDiagnosticsPreserveDeadlineAndTerminalCleanup") { let test = StdioFailureTests(); defer { test.tearDown() }; try await test.testTimeoutDiagnosticsPreserveDeadlineAndTerminalCleanup() }
print("RESULT: \(testCount) cases, \(assertionCount) assertions, \(failureCount) failures")
exit(failureCount == 0 ? 0 : 1)
