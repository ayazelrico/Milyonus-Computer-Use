# Opt-in XPC native input and interruption acceptance

The independently launched companion now has a separate trusted startup option:

`--broker-development <service> <client-cdhash> --fixture-actions --native-fixture-input`

The typed SDK must also select `allowFixtureActions: true` and `allowNativeFixtureInput: true`. Both default off. Lifecycle-only and AX-only modes retain their earlier capability sets. Native capability flags are advertised only for the explicit native-input mode. No RPC can choose either startup option or approve its own session.

The new routes reuse existing bounded fixture native text replacement, Save-button click, vertical scroll and fixed-canvas drag implementations. SDK request-kind/size validation and action-result identity validation run for each route. Server checks still require native approval, live connection ownership, fresh observation, unchanged target/focus/geometry, current generation, permissions and durable journal admission. Input sequences authorize each new event and attempt release cleanup on interruption.

## Receiver-side evidence

The gesture fixture can optionally record only received down/drag/up events and monotonic timestamps. It never records text, keys, screenshots, labels or unrelated windows. Trace output is capped at 64 events and opens only an exclusive `events.ndjson` file in the acceptance runner's owner-only temporary directory. Existing files and symlinks are refused. Normal fixture launches create no trace.

The acceptance client first observes actual mouseDown and motion in that receiver file, then sends Stop on the independent control lane or closes its connection. It requires the pending SDK action to be refused, fewer than the full 20 drag segments received and exactly one cleanup mouseUp. Partial movement is an applied effect; interruption does not imply rollback or zero effect. Trace timestamps describe delivery to the receiver, not exact event-post or OS queue timing.

The separate `baseline` mode verifies native text, native click and independent scroll/drag postconditions. Stop and disconnect each use a single interrupted drag, so receiver evidence does not depend on preceding mutations.

Run `python3 scripts/xpc-companion-lifecycle.py --native-interruption stop --evidence <new-path>` or use `disconnect` / `baseline`. The runner owns only its temporary companion service and gesture fixture, refuses pre-existing project processes, and removes its job/fixture afterward. Native approval remains manual. It does not interact with unrelated windows or send provider data.

## Current validation boundary

Debug and Release standalone tests passed 241 cases / 2555 assertions / zero failures, including native-route default denial and wrong action-request identity rejection across all four SDK methods. The first native Stop attempt failed with STALE_OBSERVATION before receiver evidence; it is preserved in `evidence/xpc-native-stop-2026-10-28-1.json` and is not acceptance. A follow-up adds stage names only to distinguish the failing step. No timing, freshness, permission or focus check was relaxed.

## Accepted native slices (2026-10-28)

- `xpc-native-input-baseline-2026-10-28-2.json`: all four positive routes passed independent verification and cancellation. Receiver recorded all 20 drag segments and its release.
- `xpc-native-stop-2026-10-28-4.json`: Stop after received mouseDown and one motion segment refused the pending SDK action; receiver recorded one cleanup mouseUp.
- `xpc-native-disconnect-2026-10-28-1.json`: closing the connection after one received motion segment also refused the pending action and produced one cleanup mouseUp.

All three use companion SHA-256 `808a754db8f36cf74107eff715d2fbd68f6d13a1fc70c73e1447c39d64e8abe7`. Exact fixture association is recorded in `xpc-native-input-binaries-2026-10-28.json` against the validated package receipt. Temporary services and owned fixtures were cleaned up.

Earlier attempts remain failed: initial stale observation without stage trace; trace-path refusal; interrupted positive baseline without a distinguishing pause reason; and initial target ambiguity before effects. Read-only initial observation now retries focus/absent/ambiguous target refusals for at most three seconds, with every native identity check unchanged. Mutations are never retried. The receiver trace fixed `/var` versus `/private/var` alias admission using temporary-root device/inode identity and an owner-only non-symlink leaf directory; exclusive output/no-follow checks remain. Direct trace tests passed valid alias admission, no overwrite and no symlink following.

These slices do not establish rollback, zero partial effect, long-held keys, sleep/lock during delivery, hardware or arbitrary-app support. The interrupted drag visibly moved; cleanup restores released input, not prior UI state.
