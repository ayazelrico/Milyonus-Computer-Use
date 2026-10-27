# Execution admission across blocking reads and writes

Execution validates task cancellation before admission and rechecks cancellation plus the original ready session generation after driver preflight. A preflight can make synchronous platform calls, so the initial lease check is insufficient. A refusal at this boundary invalidates driver targets and creates no journal intent.

After durable intent persistence, both semantic and asynchronous execution recheck cancellation and the ready session generation immediately before entering the effect-producing driver/callback. Persistence can consume the remaining heartbeat or session lifetime. If admission fails here, no effect callback is entered: the engine records `notApplied` with `unavailable` verification and the refusal error. Exact retries can read that immutable receipt when the session is still eligible; they do not dispatch the action again. The attempt still consumes the existing action budget.

This known refusal differs from an exception after execution starts. Once the driver/callback has been entered, exceptions remain `unknown` and pause the session. Failure to persist the refusal receipt also retains the existing conservative journal-failure behavior. Nothing removes an unresolved intent or enables automatic replay.

Synthetic regression cases advance a fake clock during preflight and journal synchronization, replace a session generation during preflight, and cancel tasks before/after intent. They verify zero effects, absence of a preflight-refused intent, reopened journal receipts after post-intent refusal, and separate semantic/native-click callback admission. The injection hooks are package-only test facilities, not RPC or native approval paths.

These checks do not make synchronous platform or filesystem calls interruptible, detect every transient foreground change, or replace per-event native target/focus checks. Live interruption, filesystem-stall, Stop and crash acceptance remain open. No additional application or input operation is authorized.

## Late completion verification

Before journaling a callback's `passed` verification, the engine rechecks task cancellation and the original session/generation. If the callback returned after revocation, expiry or replacement, verification becomes `unavailable` and carries the admission error. The reported effect and action identity remain unchanged: cancellation after dispatch does not establish that an applied effect never happened.

The normalized result is the persisted immutable receipt, so a later exact retry cannot recover the callback's rejected success claim or repeat the effect. A task cancellation alone does not revive or grant a session; an already cancelled/expired session stays terminal, and a replacement awaiting native approval remains awaiting approval. Existing unknown-effect and journal-failure pause behavior is unchanged.

Synthetic tests cover semantic and asynchronous callbacks returning after cancellation, reapproval/generation change, heartbeat loss and total lifetime expiry. They reopen journal files to verify the normalized receipt, confirm a task-cancelled completed effect is not repeated, and verify that an old callback cannot approve a replacement session.

This check admits verification at the completion boundary before its journal write; it is not a promise that the session remains ready after the result is recorded or delivered. Filesystem writes remain synchronous, and actual post-dispatch interruption/partial-effect acceptance still requires native tests.
