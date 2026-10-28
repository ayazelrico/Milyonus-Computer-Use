# Connection-owned session lifecycle

The server creates `BrokerConnectionContext` identities locally; no request may select its connection ID. The context has a lock-protected live bit. Listener removal clears this bit synchronously before dispatching asynchronous core cleanup, and cancels an in-flight handler task. This closes the gap where a disconnect notification is waiting for the main actor.

`ConnectionSessionOwner` binds one transport identity to the real `SessionController` session. Opening still returns awaitingApproval. Ownership checks do not grant readiness; the existing readiness, generation, expiry and native approval rules remain authoritative. A disconnect cancels only the exact bound session and invalidates targets. Delayed notifications cannot cancel another connection's replacement or a newly created native session. Liveness is checked before and after opening and before each owned operation.

The XPC endpoint now supports a bounded request after the nonce handshake: maximum 262,144 bytes, one in-flight request per connection, bounded client deadline, no replay, and cancellation/invalidation on terminal transport failures. Replies after disconnection are rejected. The endpoint's handshake flag establishes protocol order; Foundation's signing check establishes client identity. Neither establishes native approval.

## Development companion route

The explicitly selected `--broker-development <registered-mach-service> <client-cdhash>` mode configures only a local exact development pin. The service must already have been registered by an operator-controlled launcher. It cannot run concurrently with MCP mode. Invalid configuration leaves a visible startup failure and no execution path.

Requests use `{"name":"session_open","arguments":{}}`; replies contain either `result` or `error`. The route accepts only capabilities and session open/status/pause/cancel/heartbeat. It denies all desktop observation and action methods until XPC dispatch/journal interruption acceptance exists. The normal stdio SDK and Ultra adapter are unchanged. Local native approval remains manual; no RPC approves or resumes a session. The UI's independent create-session button does nothing in broker mode.

The packaged companion passed an independent temporary launchd lifecycle run on 2026-10-28. The SDK received awaitingApproval, disconnected, then opened a distinct awaitingApproval session on a new connection. Desktop capabilities were disabled. Evidence is `docs/evidence/xpc-companion-lifecycle-2026-10-28-1.json`. There is no installer or persistent launchd job in this change. Native permission grant/revoke, UI approval, approved-session disconnect and native event cancellation remain unaccepted.

## Evidence

Core tests exercise delayed disconnect, stale-owner requests, lease contention, reconnect without inherited approval, and preservation of native replacement sessions. A separate launchd peer links the actual IPC library and core SessionController: the real SDK sends open, receives awaitingApproval, closes, and the server records exactly one cancelled session and one disconnect callback. This is a real transport/core lifecycle test with no native grant or desktop action, not native approval acceptance.

`docs/evidence/xpc-session-2026-10-28-1.json` records eleven independent-process scenarios, including the new session lifecycle. Its historical limitations string still says read-only handshake; the detailed case and this document clarify that an unapproved in-memory core session was opened and cancelled. No desktop APIs were invoked. Temporary jobs were removed.

The development route's capabilities explicitly advertise no supported actions and disable native text, click, scroll and drag flags. The fixture policy remains the maximum scope; capability discovery is not an execution grant.

Before enabling desktop actions, the request concurrency design must also preserve independent heartbeat/Stop delivery during an action, and ownership must be checked after durable intent and at native dispatch/verification boundaries. One in-flight request is sufficient only for the current lifecycle route.

## Execution admission integration

The execution engine now accepts a server-supplied admission closure alongside its existing session rules. It checks admission before observation, again before publishing observation data, before action preparation, after preflight, after durable intent immediately before dispatch, and before admitting successful verification. The companion passes its transport ownership closure through these calls and through each native sequence's authorization callback. Existing stdio calls use the default empty transport closure while retaining their original session/generation/permission checks.

A refusal after intent but before dispatch is persisted as notApplied. Revocation after a reported applied effect preserves that effect and withdraws successful verification; it never rewrites history as if no effect occurred. The XPC route still denies desktop methods: admission integration alone is not live native acceptance, and independent heartbeat/Stop delivery during long actions remains required.

## Independent control follow-up

The single-request limitation above has now been addressed by a separate bounded heartbeat/pause/cancel lane on the same authenticated connection. See [XPC control lane](xpc-control-lane.md) for evidence and remaining native acceptance limits.
