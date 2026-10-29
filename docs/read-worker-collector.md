# Fixed read wire and native fixture collector

Date: 2026-10-29. Scope: internal codec and native collector component, not a launched/authenticated native helper.

## Fixed read protocol

ReadWorkerWire defines version 1 with only `fixture.ax.observe` requests and `fixture.ax.result` replies. The request carries the broker-created ticket, exact target process/start identity and optional window ID. It has no executable, script, caller-selected bundle, action, clipboard, image or native-approval field. Extra request/ticket fields, duplicate JSON members, oversized/deep messages, unsupported operations and out-of-range time budgets fail closed.

Request deadlines are represented in integral nanoseconds, positive and capped at ten seconds. A ticket whose precision cannot be represented exactly is refused. Reply elapsed time is bounded and the broker's independent monotonic deadline remains authoritative; worker-reported timing cannot extend admission. A reply must echo the expected ticket even when it reports a permission refusal. Observation/error are exclusive, and observation PID/session/bundle and the existing structural/aggregate limits are revalidated. Dates use milliseconds since the Unix epoch within this private versioned wire.

The fixture bundle constant is now explicitly nonisolated immutable data so the codec can validate values off the broker actor. SessionController's approval and mutation state remains MainActor-isolated. The local ready-state value used for metadata validation is not a native approval and does not create SessionController state.

## Native collector component

ReadWorkerProcessIdentity reads PROC_PIDTBSDINFO and validates the returned size, PID and start seconds/microseconds. The SDK header and [Apple's kernel implementation](https://github.com/apple/darwin-xnu/blob/main/bsd/kern/proc_info.c) identify these start fields as the process start time. A missing/unreadable process fails closed. This identity is not a publisher signature; existing fixture signing/target-identity limitations remain.

FixtureReadWorker.collect is an internal read-only entry intended for the separate authenticated helper. It validates the ticket, checks kernel start identity and the exact fixture bundle, checks its calling process's real AX trust, then uses the existing bounded AccessibilityDesktop traversal. The traversal retains foreground, window-consistency, secure-field exclusion, truncation and resource checks. Kernel identity, permission and deadline are checked again before returning. The temporary worker-side target table is invalidated and is never installed in the broker.

The collector does not activate an application, post input, request permission, approve/renew a session or upload anything. A broker must authorize the operation before sending the ticket and re-admit the result afterwards. The scoping Session value passed to the read-only driver is only metadata; it is not an approval token.

The first collector explicitly refuses a non-nil CGWindow ID with UNSUPPORTED_CAPABILITY. It must not downgrade a requested explicit-window binding to the focused-window AX path. Broader window association requires its own implementation and native evidence. Calling this component inside the companion would not demonstrate independent worker TCC attribution.

## Verification boundary

Codec tests cover the fixed request, Unicode result and permission-refusal round trips, mismatched success/failure tickets, injected mutation/app scope, duplicate/oversized data, contradictory replies, extended elapsed time and wrong result PID. Kernel identity tests query only the selftest's own process. Collector negative tests use that same non-fixture process: bundle mismatch, altered kernel start time and unsupported explicit-window scope are rejected before any AX traversal or trust query.

These checks do not demonstrate successful AX collection, effective helper permission, broker Stop while AX blocks, packaged worker startup or a native grant. No GUI is launched by the tests. Native collection acceptance must run through the authenticated helper and an actual approved broker session before the companion can switch paths.

Debug build/selftests and optimized Release selftests each passed 256 cases / 2674 assertions / zero failures. The [evidence manifest](evidence/worker-collector-acceptance-2026-10-29.json) associates the exact source and logs.

## Next integration gate

Connect the codec and collector in a dedicated helper using [owned XPC admission](owned-worker-channel.md), a trusted packaged-helper locator and production-safe startup rendezvous. Keep ReadWorkerProcessSlot until actual child exit. The broker must preserve its session/connection/generation admission and mint its own observation/element references; worker handles cannot authorize native actions. Collect independent TCC and stalled-AX cancellation evidence before claiming H3 complete.
