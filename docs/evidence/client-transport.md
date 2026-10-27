# Client reply boundary evidence

Scope: the Swift client's inherited-pipe transport and reply decoder. Tests use the standalone self-test executable as a synthetic child; they do not launch the native companion or perform desktop actions.

The decoder checks the JSON-RPC version and distinguishes notifications from replies before touching a pending continuation. Reply IDs must be positive integers matching the client's integer-ID convention. Boolean, fractional, string, null, nonpositive and out-of-range IDs are refused. A reply must contain exactly one of result or error and no method. Error envelopes require an integer code and string message.

Malformed envelopes close the transport and fail pending calls with PROTOCOL_MISMATCH. Oversized lines fail with RESOURCE_LIMIT. Calls after closure return CANCELLED. A valid but unrecognized reply ID is ignored without consuming another request's continuation. Notifications do not resolve requests. Valid RPC error replies fail their matching request without being treated as a successful result.

The input reader retries interrupted reads. A malformed initialize result also closes the transport rather than escaping with a decoding error and leaving the child active.

| Test | Coverage |
|---|---|
| RPCReplyTests.testInvalidIDsCannotConsumePendingRequest | Eight invalid ID forms |
| RPCReplyTests.testMalformedEnvelopesRejected | Ten malformed JSON/envelope forms |
| RPCReplyTests.testValidRepliesAndNotifications | Null result, valid error, notification |
| StdioFailureTests.testInvalidPipeRepliesCloseTransport | Boolean ID, ambiguous result/error, malformed JSON, invalid initialize result and oversized line over actual pipes; refusal of subsequent calls |
| StdioFailureTests.testValidPipeReplyStillConnects | Successful handshake and null session status over actual pipes |

The synthetic children run through the normal client launcher and its sanitized environment. The launcher receives a temporary executable wrapper that invokes only the self-test fixture. This is parser and transport evidence, not production peer authentication, native companion acceptance, or a full cancellation/concurrency matrix. Duplicate-member validation, backpressure and owned-child shutdown are covered below; native and production acceptance remain separate.


## Local tool-result validation

The companion-specific tool decoder requires exactly one content block with type text and a string payload. If isError is present, it must be a JSON boolean; absence means false. Numeric, string and null flags are refused. Error payloads must name a recognized HarnessError. Successful payloads must decode into the requested SDK type. Malformed structure, unknown error codes and typed-payload decoding failures close the transport with PROTOCOL_MISMATCH.

A recognized domain refusal remains a tool result, not a transport decoding failure. It is returned to the caller without closing an otherwise healthy transport, including a domain error whose code itself is PROTOCOL_MISMATCH. Higher layers retain responsibility for session pause/cancellation and action verification.

| Test | Coverage |
|---|---|
| ToolReplyTests.testMalformedToolEnvelopesRejected | Eleven invalid content/error-envelope variants |
| ToolReplyTests.testValueAndDomainFailureRemainDistinct | Missing/false flag success and explicit domain protocol refusal |
| StdioFailureTests.testMalformedToolResultsCloseTransport | Six malformed content/payload modes over actual pipes; subsequent calls refused |
| StdioFailureTests.testDomainRefusalDoesNotCloseTransport | Two consecutive valid UNAUTHORIZED refusals over one live transport |

This is a narrow local companion contract, not support for arbitrary MCP image/resource or multi-content replies. Action correlation is now checked separately as described below; full model/session verification remains outside content decoding.


## Action response correlation

All three SDK mutation routes (act, click and typeText) now share an action-result admission check after typed decoding. The embedded requestId must equal the submitted ActionRequest.requestId. The actionId must be a nonempty ASCII identifier of at most 128 bytes using letters, digits, dash, dot or underscore. A mismatch closes the transport with PROTOCOL_MISMATCH; a subsequent mutation call is refused with CANCELLED. The SDK does not retry the action.

Two additional actual-pipe matrices use synthetic children:
- testInvalidActionResponsesCloseAllMutationRoutes: four invalid outcomes (wrong request ID; empty, path-like or oversized action ID) across three mutation methods, plus rejection of a follow-up call.
- testCorrelatedActionResponsesPreserveOutcome: three methods with applied/passed or unknown/unavailable outcomes; request ID, action ID, effect, verification and error are retained.

These tests exercise SDK correlation without desktop effects or native approval. A valid request ID does not prove that an effect occurred. The agent runner and native engine retain their independent verification, foreground and session-generation checks. Observation/session response checks are described below; hostile transport lifecycle acceptance remains a review area.


## Session and observation response binding

The SDK now checks fixture scope and bounded session identifiers on session replies. A newly opened session must be awaitingApproval at generation 1, matching the current companion contract. Status replies bind to the session owned when the status request was issued; an owned session cannot silently disappear as null. A status call before ownership may still return null.

Heartbeat replies must match the requested session and generation and report ready. Cancellation replies must match the requested session and be cancelled or expired; the latter preserves idempotent cancellation of an already-expired session. Observations must match the requested session, report the fixture bundle, have a positive PID, and carry a valid observation identifier. Violations close the transport with PROTOCOL_MISMATCH; subsequent requests return CANCELLED.

Two actual-pipe tests cover nineteen invalid scenarios and valid lifecycle controls:
- testSessionAndObservationMismatchesCloseTransport checks open, owned status, heartbeat, cancellation and observation responses.
- testCorrelatedSessionAndObservationControls checks pending approval, status, ready heartbeat, observation, ordinary cancellation and expired cancellation.

The synthetic peer supplies these states without desktop actions or native approval. These tests prove SDK reply admission only. They do not authenticate the peer, grant permission, establish current foreground identity, pin a PID across observations, or independently verify the accuracy of a ready state. The native engine and agent runner retain those separate responsibilities.


## Cancellation and late replies

The RPC path checks task cancellation before allocating a request ID or sending data. It checks cancellation and transport closure again after a continuation resumes, covering a cancellation that races a decoded reply. Closed transports ignore subsequent incoming replies. Cancelling an in-flight call closes this dedicated transport and cancels all its pending calls; it does not retry a mutation.

Four actual-pipe lifecycle tests cover:
- testPreCancelledRequestNeverDispatches: the issued-request count remains unchanged.
- testCancellingPendingCallDrainsSiblingRequests: cancellation releases both pending continuations and blocks subsequent calls.
- testShutdownDrainsPendingCallIdempotently: repeated shutdown releases a waiting call exactly through its cancellation result.
- testLateReplyAfterCancellationCannotReviveCall: a synthetic child acknowledges receipt, delays, then attempts a response after cancellation. A temporary phase marker confirms either the write or refusal because the SDK already closed its read end; the call remains cancelled and the transport stays closed.

The late-reply fixture ignores SIGTERM only for its bounded delay, suppresses SIGPIPE in the test process, and exits after its reply attempt. This is not acceptance of indefinitely hostile child termination. Tests inspect package-only read-only request counters; no new RPC, approval control or public SDK configuration is exposed.

Cancellation does not undo an effect already dispatched to the desktop. These tests use status requests and synthetic peers; native interruption and production process teardown remain separate gates; blocked-write coverage is described below.


## Owned child termination fallback

Explicit shutdown closes the child's input and cancels pending work immediately, then sends SIGTERM. If the same owned Process instance is still running after a one-second grace period, the SDK sends SIGKILL to that direct child's PID. No process group, discovered application, or unrelated desktop process is targeted. Client deinitialization uses the same fallback when shutdown has not already started.

Three actual-pipe tests cover explicit shutdown and task cancellation against a synthetic child that ignores SIGTERM and input EOF, plus a cooperative child that exits without SIGKILL. The hostile test fixture has an independent eight-second fail-safe; tests require exit within three seconds and verify SIGKILL status, so that fail-safe cannot masquerade as successful SDK teardown. Pending continuations are drained before process exit.

The one-second delay schedules escalation; it is not an absolute guarantee against OS scheduling delays or an uninterruptible kernel wait. This evidence does not cover native held-input cleanup after forced termination, management of child descendants, native permission/process identity changes, or production peer authentication. Only the SDK's directly launched process is supervised.


## Nonblocking I/O, bounded queues and timer cleanup

Parent pipe descriptors are nonblocking. The write descriptor suppresses SIGPIPE per descriptor; the SDK does not change the host application's global signal disposition. Outbound frames are serialized, at most eight queued, with explicit partial-write offsets and a ten-second deadline. Writes advance in chunks of at most 4,096 bytes and yield between chunks. Backpressure sleeps for five milliseconds instead of blocking the client actor. Partial failure closes the transport with an unknown-effect error; no frame is replayed.

The reader sleeps for ten milliseconds when no data is available, checks cancellation, and closes its own descriptor on exit. It need not wait for an inherited stdout handle to reach EOF. A descendant is not killed to accomplish reader shutdown. Completion, failure, expiry and shutdown remove and cancel the request's timeout task; the active pending-call limit remains eight.

Nine actual-pipe tests cover:
- Shutdown and task cancellation while eight large requests fill a nonreading peer's pipe.
- Partial writes with a slow reader, preserving all request frames and correlations.
- Ten-second blocked-write expiry without reissuing requests.
- Reader shutdown while a temporary three-second descendant retains stdout.
- Timer cleanup after 32 consecutive requests and after pending-call shutdown.
- Closed stdin producing an error rather than SIGPIPE termination of the SDK.
- Refusal of a ninth pending request without eviction of the existing eight.

This is evidence of bounded local transport behavior, not a throughput, CPU, energy or soak benchmark. The periodic sleeps remain to be measured under sustained workloads.

## Duplicate JSON members and nesting

A shared package-only validator checks original UTF-8 bytes before decoded dictionaries are used. Foundation remains responsible for JSON syntax validation. An additional bounded walk rejects duplicate object keys, including escaped spellings of the same key, and limits nesting to 64 levels and input size to 262,144 bytes. Keys repeated in different sibling objects are permitted. Escaped JSON-like text inside strings is not interpreted as object structure. Swift's decoded string equality also rejects canonically equivalent Unicode key spellings.

The validator is used for RPC replies, tool envelopes, tool error payloads and typed success payloads. The native companion now invokes it before request dispatch. Unit tests cover valid controls, malformed syntax, UTF-8 admission, byte/depth limits and ambiguous request fields. Synthetic-child pipe tests cover duplicate RPC IDs, nested tool error flags, duplicate typed fields and duplicate error codes.

The companion change is compiled but has not received a new live companion acceptance run. Pure request-validator tests must not be reported as native GUI acceptance.

## Retained failed attempts

selftest-before-nonblocking-fixture-fix.log records a late-reply fixture that still required a successful write after the reader began closing promptly. The fixture now accepts and records pipe refusal as well as successful late delivery.

selftest-before-inherited-output-fixture-fix.log records a fixture trigger that searched raw JSON text for an unescaped slash. It now parses the notification method before starting the output-holding descendant. Neither failed log is passing evidence.
