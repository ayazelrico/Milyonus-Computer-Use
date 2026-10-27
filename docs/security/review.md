# Development security review

Updated: 2026-10-25. Scope: implementation review and deterministic regression evidence on this development host. This is not an independent audit, penetration-test certificate, or release approval.

## Findings addressed

| Boundary | Concrete failure | Implemented control | Evidence |
|---|---|---|---|
| Journal completion | A result could resolve a changed intent or overwrite a finalized result | Fingerprint/method and request correlation; immutable completions | [Recovery matrix](../evidence/journal-recovery.md) |
| Failed persistence | Later writes could proceed from potentially divergent in-memory state | Latch the ledger against mutation until reopen; pause execution | Recovery matrix, durability checkpoints |
| Abrupt child death | Cleanup cannot run after SIGKILL | Reopen committed journal only; preserve unresolved intent; kernel lease reacquisition tests | Six isolated crash boundaries per build configuration |
| Journal admission | Malformed identifiers/fingerprints and boundary cases could enter recovery state | Structural validation, private file admission and bounded entry/byte counts | Admission regressions and unchanged rejected bytes |
| RPC correlation | JSON booleans could alias integer request IDs; ambiguous replies were ignored | Strict reply envelope validation before consuming continuations | [Client transport evidence](../evidence/client-transport.md) |
| Tool payloads | First content block could be accepted without validating remaining content | One text block, boolean error flag, known domain errors and typed decoding | Tool-result and pipe matrices |
| Response identity | Valid envelopes could carry another action or session | Bind action/session/observation replies to their expected identity and fixture scope | Correlation pipe matrices |
| Cancellation | Already-cancelled work could enter dispatch; late replies could race Stop | Pre-dispatch/post-reply cancellation checks, pending-call drain and closed-transport refusal | Cancellation and delayed-reply tests |
| Unresponsive direct child | SIGTERM alone did not ensure teardown | One-second grace period, then SIGKILL of the owned direct child if still running | Cooperative and unresponsive child tests |
| Pipe backpressure | Synchronous actor writes could prevent Stop from running | Nonblocking descriptors, bounded serialized frames, partial-write offsets, yielding and deadlines | Backpressure, timeout and frame-order tests |
| Inherited output | Reader could wait indefinitely for EOF held by a descendant | Cancellable nonblocking reads and reader-owned descriptor closure | Descendant-held stdout test |
| Ambiguous JSON | Repeated or escaped-equivalent fields could be silently normalized | Bounded duplicate-member validation on original bytes for SDK payloads and companion requests | Strict JSON and actual-pipe ambiguity tests; companion build only |
| Timeout task retention | Completed requests left timeout tasks sleeping until their deadlines | Cancel and remove timers with request completion or shutdown | Sequential-request and pending-shutdown tests |

## Remaining release blockers

- Signed peer/executable identity and production IPC authentication are not implemented. A supplied child executable is trusted configuration, not verified authority.
- Fixture scope remains narrow. No arbitrary-application acceptance, production egress grant model, or generalized sensitive-content classification is established.
- Native held-input cleanup after forced termination, AX hangs, permission revocation, physical Stop/lock scenarios, and multi-display/OS acceptance remain incomplete.
- Journals are not authenticated against same-user filesystem modification. Rotation, retention and secure export remain unimplemented.
- Process supervision targets only the direct child; descendants are not forcibly killed. A blocked kernel operation can exceed the scheduled escalation delay.
- Polling intervals and bounded queues are implementation controls, not measured performance or energy acceptance. Sustained soak and resource measurements remain open.
- Actual power-loss, reboot and disk-exhaustion durability are not established by injected exceptions or SIGKILL tests.
- Real-provider native acceptance, approved external host action acceptance, Developer ID signing, notarization, clean install and upgrade/uninstall remain separate gates.

No fix here disables native approval, foreground checks, target identity, generation fencing, journal-before-effect ordering or permission validation. Synthetic test peers exercise transport behavior only and do not grant desktop authority.
