# Regression findings — 2026-10-25

These findings are separate from successful acceptance evidence.

1. After extending the public error enum, an incremental companion build returned `PROVIDER_REFUSED` for an unsupported tool. A clean rebuild restored the expected `UNSUPPORTED_CAPABILITY` response and all 18 black-box checks passed. Verification now starts with a clean package build; source compilation alone was insufficient evidence.
2. The first client-liveness GUI run observed a pause caused by a UI-testing input event rather than lease expiry. Its initial state-only assertion was insufficient. The revised test requires the ready state to persist until the lease deadline and requires `pauseReason: heartbeatLost`. It does not count a user-input pause as proof of lease expiry.
3. A subsequent native pointer run stopped at iteration 7 because the Save counter did not change. The action did not report success and was not retried. Native pointer events now specify a single click and include 10 ms movement settlement and a 30 ms press interval. This addresses a timing hypothesis; only subsequent native results support reliability, and the full G3 stress matrix remains open.

The live artifact records only the latest run's pass/failure. Earlier successful slices do not override a newer failing run. Native approval in these automated fixture regressions was driven by the test controller under the user's explicit fixture-test authorization; this is not evidence of a physically operated approval.

Subsequent isolated native acceptance passed 118 checks for semantic/keyboard/heartbeat behavior. Pointer/keyboard acceptance then passed 113 checks over 10 iterations and 333 checks over 30 iterations. The earlier pointer misses remain recorded: these passing runs narrow the observed regression but do not establish its root cause or replace the complete G3 matrix.

The deterministic SDK pilot encountered `FOCUS_CHANGED` after an 18-second planning delay in two automated runs. A diagnostic run also recorded a physical-input-category event 0.143 seconds after automated approval and correctly paused. The foreground diagnostic reports only fixture/companion/another-application categories, not unrelated app identities or UI contents. Human-operated approval is being used to distinguish test-controller interference from SDK behavior; failed automated runs do not count as SDK acceptance.

## Agent completion across a generation change

Code inspection found that the runner checked session readiness before inference but could accept a completion claim after an observation returned while the session generation changed. It now checks session status again after the fresh observation and before either proposal branch. A deterministic fake client changes generation during that read; the expected outcome is `UNAUTHORIZED`, no mutation and cancellation.

An `applied` result with `unavailable` verification is also rejected with `VERIFICATION_FAILED` and no retry. This is synthetic orchestration evidence; it does not replace native interruption acceptance.

## Native approval error hidden by polling

A user-authorized deterministic SDK retry timed out in native approval. Read-only companion inspection showed `awaitingApproval`; no action or successful activation was recorded. Source inspection established that the SDK's status polling called `refresh()` and could overwrite the approval handler's error text. This is a confirmed diagnostic defect, not proof of the underlying approval failure.

The companion now retains native errors across status refreshes, reports typed codes through opt-in diagnostics, and validates the fixture bundle URL before transitioning to ready. The failed SDK run remains unaccepted.

The retry after the diagnostic fix reached native approval (`fixture activation requested through Launch Services`) but exited with `FOCUS_CHANGED`; diagnostics identified only the category `another-application`, without collecting its name or content. This distinguishes the retry from the earlier approval timeout. It does not establish why foreground focus changed.
