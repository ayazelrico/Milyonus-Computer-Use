# Journal recovery evidence

Scope: deterministic core and engine tests using disposable temporary directories and fake desktop effects. No native desktop, production journal, account data or provider requests are used.

| Failure boundary | Test | Verified behavior |
|---|---|---|
| Before intent persistence | testIntentFailurePreventsNativeCall | No driver effect; session pauses |
| Invalid parent before intent write | testFailedIntentRequiresReopenBeforeWriting | Failed ledger refuses later writes even after the parent is restored; reopening revalidates disk |
| Invalid parent after simulated effect | testCompletionWriteFailurePausesWithoutRepeatingEffect | Completion reports unknown, session pauses, restart retains unresolved intent |
| Failed completion followed by additional writes | testFailedCompletionFreezesJournalWrites | Both completion retry and new intent are refused; original journal bytes remain intact |
| Rename fails after temporary-file synchronization | testRenameFailureCleansTemporaryJournal | Temporary file is removed; destination directory and marker are preserved |
| Completed result substitution | testCompletionIsImmutableAcrossRestart | Unknown result cannot be rewritten as success; identical completion is harmless |
| Different action or execution method | testCompletionRejectsChangedIntent / testCompletionBindsExecutionMethod | Completion cannot resolve an unrelated intent |
| Uncorrelated driver result | testWrongCompletionCorrelationPausesAndPreservesIntent | Session pauses; recovery retains unresolved intent |
| Injected intent failure before file sync, before rename, and before directory sync | testIntentFailureAtDurabilityBoundaries | No temporary files remain; post-rename intent is visible on reopen but cannot be replayed |
| Injected completion failure at all three boundaries | testCompletionFailureAtDurabilityBoundaries | In-memory result stays unknown; writes remain blocked; reopen reads the old intent or the replaced completion |
| Injected post-rename intent failure through engine | testPostRenameIntentFailureNeverDispatches | Session pauses with zero effects despite a visible persisted intent |
| Injected post-rename completion failure through engine | testPostRenameCompletionFailureDoesNotRepeatEffect | One effect only; session pauses; reopening reads the recorded result without dispatch |
| SIGKILL during intent at all three write boundaries | JournalCrashTests.testAbruptExitDuringIntent | Prior completed entry survives; pre-rename target is absent; post-rename target remains unresolved; lock can be reacquired |
| SIGKILL during completion at all three write boundaries | JournalCrashTests.testAbruptExitDuringCompletion | Prior completed entry survives; pre-rename target remains unresolved; post-rename completion is readable; lock can be reacquired |
| Malformed persisted identifiers and fingerprints | JournalAdmissionTests.testMalformedEntriesRejectedWithoutRepair | Thirteen malformed record variants are rejected without modifying bytes |
| Duplicate keys or more than 2,000 records | JournalAdmissionTests.testEntryCountAndDuplicateKeysRejected | Startup refuses the document and preserves it |
| Exactly 2,000 records | JournalAdmissionTests.testFullJournalAllowsCompletionButRejectsNewIntent | Existing action can complete and be read after reopen; new intent is refused |
| File larger than 2,000,000 bytes | JournalAdmissionTests.testOversizedJournalRejectedWithoutTruncation | Startup refuses without truncation |
| Invalid incoming record | JournalAdmissionTests.testInvalidNewRecordsNeverPersist | Invalid request or completion is rejected before persistence; healthy ledger still accepts valid completion |
| Restart with unresolved intent | testUnresolvedIntentSurvivesRestart | Unknown effect is returned rather than replayed |

A persistence failure latches the current ledger against further mutation. Reads of previously completed records remain available; unresolved records remain unknown. Recovery requires stopping the companion and reopening its journal after diagnosing storage. Reopening does not authorize a new desktop session or permit replay of unresolved effects.

Filesystem refusal tests change temporary parent permissions or install a directory at the rename destination. Additional package-only checkpoints throw immediately before file fsync, rename, or directory fsync. These exercise the real temporary-file writing, replacement and cleanup paths, including the state where rename succeeded but directory synchronization was not performed. The public ledger initializer always disables the checkpoints; no environment variable, CLI option, provider input or RPC enables them.

The standalone self-test additionally launches six isolated subprocesses, selecting intent or completion at each of the three boundaries. Each child holds a temporary writer lease, seeds a prior completed record, then kills itself with SIGKILL at its selected checkpoint. The parent checks signal termination, reacquires the lease, and reads the journal. A ten-second deadline limits each child; timeout is a test failure. Child environment contains only PATH and TMPDIR. No companion or fixture application is launched.

SIGKILL bypasses Swift cleanup. Before rename, a private 0600 temporary record remains. Tests verify it contains no fixture plaintext and that reopening neither promotes nor deletes it. After rename, the temporary path no longer exists. Parent teardown removes only its disposable test directory.

These tests establish local subprocess-death recovery, not actual kernel fsync failure, power loss or disk exhaustion. Immediate reopening on this host is not proof of persistence across reboot. The native companion crash matrix and broader durability platform acceptance remain open. No claim of production crash consistency or CU-035/G6 completion follows from this matrix.

Current complete-suite results are recorded in selftest.log and release-selftest.log. Source identities are recorded in source-manifest.json; native evidence retains its separate binary scope.


Journal admission validates keys and result identifiers as nonempty ASCII identifier strings of at most 128 bytes, and fingerprints as exactly 64 lowercase hexadecimal characters. It retains the v1 format and existing valid semantic/native fingerprints. These are structural checks, not authenticity checks: the journal is not cryptographically authenticated against another process with the same user's filesystem access.
