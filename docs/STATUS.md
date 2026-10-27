# Implementation status

Updated: 2026-10-27. This is an evidence-based development status, not a release certificate.

## Immediate execution priority

Follow [the acceptance-first queue](ACCEPTANCE-NEXT.md). Basic native gestures and one-action Anthropic/OpenAI native pilots have passed for recorded binaries. The user authorized foreground acceptance on 2026-10-27; native approvals remain manual. Next priority is Ultra live acceptance, then the broader interruption matrix and signed distribution. Provider credentials were transient and are not installed persistently. No valid Developer ID identity was found. Earlier intermittent stdio timeouts remain unresolved.

## Verified so far

- Swift 6 package with contracts, core, macOS adapters, Swift client, agent orchestration, diagnostic CLI, native control app, and fixture.
- Latest Debug and optimized Release suites: 227 cases, 2448 assertions, zero failures. Earlier inherited-output and mismatch/closed-input test timeouts are retained and unresolved below.
- Real MCP stdio smoke suite: 18 passing checks. Swift-client smoke suite: 4 passing checks.
- Actual native fixture run: Native pointer/keyboard stress: 333 checks across 30 Unicode edit/save iterations, including native keyboard input, native pointer clicks, empty replacement, native duplicate suppression, and execution-method conflicts. Independent counter/value verification, duplicate suppression, stale-target refusal, secure-field exclusion, pause and cancellation passed.
- Isolated heartbeat native acceptance: 118 checks across 10 iterations, including readiness until the lease deadline, `heartbeatLost` pause reason and refusal of late renewal.
- Actual ScreenCaptureKit probe: 1240 × 824 pixels, in-memory PNG. Only dimensions/size/hash were emitted; no screenshot upload or disk image.
- Development bundles built and ad-hoc signatures verified. A local Git repository is initialized; no remote, push, or release publication occurred.

## Phase gates

| Gate | Current state | Remaining acceptance work |
|---|---|---|
| G0: platform/identity/IPC | Partially evidenced | Stable Developer ID identity, production IPC/peer authentication, clean-user and minimum-OS checks |
| G1: contracts/policy/session | Substantial implementation and tests | General scope/grant model and broader adversarial coverage; current action/session/observation/result/heartbeat schemas and lease are implemented |
| G2: observation | Native AX and capture slice verified | Real multi-display/hot-plug, complete artifact/retention design, hung-app isolation and TCC revoke matrix |
| G3: execution | Semantic, native-text and native-click fixture slices verified | Full scroll/drag interruption acceptance, arbitrary coordinates/key/general drag operations, complete 20×10 matrix, physical Stop/lock/permission/crash acceptance |
| G4: agent interfaces | SDK/MCP, agent loop, OpenAI Responses and Anthropic Messages adapters implemented | Real inference, negotiated image/egress capabilities, 10×5 agent pilot |
| G5: Agent Ultra | Default-disabled native preview wired; host regression suite passed | Live preview lifecycle matrix, production sandbox/broker acceptance, provider integration |
| G6: release | Packaging/notarization scripts and runbook prepared | Developer ID credentials, clean install/upgrade/uninstall, performance/soak/security acceptance |
| P7: expansion | Backlog | OCR, DOM, clipboard, additional providers/platforms and remote transport remain unimplemented |

No gate is marked fully passed by borrowing evidence from a different platform or from a synthetic test. The first real native slice is accepted; the complete product is not.

## External dependencies

- No valid Developer ID signing identity is installed. Public notarized release cannot be accepted without the appropriate signing access.
- macOS 14 runtime, Intel, and multiple physical displays have not been tested on this host.
- The OpenAI Responses adapter has synthetic transport coverage but real provider inference has not been accepted. `OPENAI_API_KEY` and `MILYONUS_OPENAI_MODEL` are not configured. CLI installation alone is not evidence of compatible tools, vision, authentication, or quota.

These external dependencies do not excuse unfinished implementation. Incomplete gesture interruption acceptance, missing general pointer/drag operations, full broker security, retention, richer schemas, and Ultra integration are explicitly tracked as engineering work.

## Native-test findings resolved during this iteration

1. Foundation buffered pipe reads prevented short MCP requests from being delivered promptly. The transports now use bounded POSIX reads and serialized bounded output.
2. Packaging over a running executable risked invalidating its code signature. Development packaging now replaces the executable inode.
3. Cooperative app activation could be refused from the automated test path. Native approval now requests activation of the already-scoped fixture through Launch Services. It still refuses every observation/action until the fixture is actually foreground.
4. The approval click can be delivered after activation. Only input events timestamped after approval can pause the newly approved session; there is no arbitrary input-ignore grace period.
5. ScreenCaptureKit enumerates auxiliary and off-screen windows. Capture resolves the fixture's explicit main-window title and app identity, and supports desktop-independent capture of that known window. It does not expand the input action scope.
6. CLI capture required AppKit initialization before the screenshot call. The capture adapter now initializes that runtime explicitly.

See `docs/evidence/` for individual logs. The pending full matrix must test these behaviors beyond the successful local fixture slice.

## Current increment

- Added typed native-text SDK capability and advertised its UTF-16 bound.
- Idempotency distinguishes AX writes from native keyboard effects while retaining compatibility with previous semantic journal fingerprints.
- Asynchronous execution keeps a single mutation claim while allowing native cancellation; unit coverage checks cancellation cannot revive a session.
- Native input checks scope before each event and releases held keys/buttons on failure or cancellation.
- Agent-loop hardening rejects wrong-app/process observations and repeated actions without visible progress.
- Live evidence records run status, UTC timestamps, and the exact tested companion binary hash. A failed newer run replaces the success status instead of leaving an old pass as apparent current evidence.

- Native Save clicking uses resolved bounds and an exact system-wide AX hit test before every pointer event; actual counter/value verification passed for 10 iterations. Native text additionally checks that the exact approved field still owns keyboard focus before dispatch.

## Client liveness and provider increment

- MCP sessions now use a 15-second monotonic heartbeat lease with a five-second advertised renewal interval. Heartbeats cannot approve/resume a session or extend its total lifetime. The SDK maintains liveness independently of inference.
- Session status includes a typed pause reason. Heartbeat expiry, requested pause, physical input, environment interruption and uncertain execution are distinguished.
- Terminal session states no longer change generation on repeated reads/cancellation. Missing/late/wrong-generation heartbeats have deterministic fake-clock coverage.
- The optional OpenAI Responses planner uses explicit model selection, session-bound fixture egress, a host credential closure, strict structured output, bounded HTTPS transport, no redirects, no retry and no fallback. API-backed execution requires the explicit `agent-fixture ... --allow-fixture-egress` command. No live inference was performed.
- The provider test suite uses synthetic HTTP responses only; see `docs/provider-matrix.md` for accepted and pending capabilities.
- Black-box MCP tests now reject malformed argument containers, boolean heartbeat generations, heartbeat self-approval and invalid startup sequence. The SDK validates the negotiated protocol version.
- Verification starts from a clean package build following the observed incremental enum-layout mismatch. Native regression findings, including an unsuccessful pointer iteration, are retained in `docs/evidence/regression-findings-2026-10-25.md`.

## Non-disruptive work mode

The user is actively using the computer and requested that disruptive native tests be deferred by 25 minutes. Background development continues. `scripts/verify-background.sh` does not launch windows, activate apps, request permissions or perform native input. Full protocol/SDK GUI checks must wait for availability. Earlier deterministic SDK attempts encountered focus/input interruptions and an approval timeout. A subsequent user-approved run passed; see the latest acceptance entry below.

Current wire contracts now have independently validated JSON Schema coverage: 59 checks against actual Swift-encoded fixtures and malformed variants. This does not complete the future general grant/artifact contracts.

## Agent result and cancellation boundary

After provider latency and a fresh observation, the runner rechecks session identity, application scope, readiness and generation before accepting either a mutation proposal or a completion claim. A result with unavailable verification stops the run without retry, even if its effect is reported as applied. Cancellation detaches its session reference before awaiting transport cleanup, so an older cancellation cannot clear the tracking reference of a newer run. Deterministic regression cases cover revoked-generation completion and unavailable verification.

The latest background checks are independent of older native evidence. A source or package rebuild does not renew live acceptance; native logs retain their tested binary hashes.

## Native SDK retry and approval diagnostics

On the user-authorized retry, the companion was observed in `awaitingApproval` despite the reported manual click; the SDK exited with `TIMEOUT` without applying an action. No approval-success diagnostic was emitted. The cause of that missed approval remains unconfirmed.

Inspection found that successful status polling refreshed the status label and erased native approval failure messages. Native control errors now persist across refreshes and emit typed error codes in opt-in diagnostics. Successful native approval, session creation or resume clears the notice. The fixture bundle URL is also resolved before session approval. These UI changes do not grant permission or relax session/focus checks. The updated native UI still needs live acceptance.

The subsequent retry emitted the native approval/activation diagnostic, then stopped with `FOCUS_CHANGED` while the foreground category was `another-application`. Native approval was reached on that failed attempt; the later successful attempt is recorded below. No retry or foreground-check bypass was added.

## Deterministic live SDK acceptance — passed

The subsequent user-approved run exited with code 0. The real Swift SDK launched the companion, received native approval, maintained the session across an 18-second synthetic planning delay, refreshed targeting, executed one fixture text action and independently verified the host-defined completion condition. The session was cancelled and the child shut down normally.

Evidence: `sdk-agent-fixture.json`, `sdk-agent-diagnostics.log`, and `sdk-agent-attempt-metadata.json` (UTC recording time and exact companion/client hashes). This is one successful native SDK run, not the 10×5 agent matrix. `realInference: false`: no provider request or credential was used. G4 remains partial pending real inference and broader acceptance. Earlier failed attempts remain documented and are not counted as successes.

## Anthropic integration increment

The user supplied an Anthropic credential for testing. A real, minimal text request returned HTTP 200 for `claude-opus-5-5` using API version `2026-10-21`. The credential was kept out of repository files and companion processes.

The Anthropic adapter shares strict action decoding with the OpenAI adapter, minimizes fixture data and accepts exactly one supported proposal. Eleven new synthetic cases cover egress, scope, deadlines, malformed replies, refusal, size limits, HTTP errors and multiple/unknown tools. Debug and Release self-tests pass 85 cases / 521 assertions.

The first Anthropic desktop pilot timed out waiting for native approval; it is not accepted. The earlier deterministic SDK pass remains valid for its recorded binaries and is not evidence of real-provider native completion.

The real Anthropic planner contract check passed: two API-backed proposals (`setValue`, then `finish`) were independently checked against synthetic fixture observations. `anthropic-live-planner.json` records `realInference: true`, `syntheticObservations: true` and `desktopActions: 0`. This proves the adapter's real API exchange, not native completion. A subsequent native attempt returned `UNAUTHORIZED`; no native acceptance is inferred from that result.

The final native retry again timed out waiting for approval. No further desktop run is left pending. The real provider desktop gate remains open; do not confuse the successful synthetic-observation API test with the earlier deterministic native SDK test.

## P5 preparation: native host integration coordinator

`ComputerUseIntegration` now provides a default-disabled native coordinator, dedicated transport lifecycle, explicit computer-use entry mode, safe UI state projection and a required selection-suspension hook. Existing plain-chat/Code/Ultra modes are rejected before a client is constructed. Approval remains in the companion; pause never auto-resumes. Stop invalidates ownership before cleanup, and stale poll revisions cannot overwrite newer state.

Eight deterministic integration tests cover feature/mode isolation, pending approval, exclusive ownership, idempotent Stop, late connection completion, verified completion cleanup, pause handling, out-of-order status replies and Stop while an uncooperative planner is still suspended. These use fake clients and do not interact with the user's desktop.

The Agent Ultra checkout was inspected read-only. Its state changed externally during this work; a later read reported clean HEAD `a081f251d6678b901cec9417d880927da0170ff0`. No changes to that checkout were made here. Actual application/UI wiring, SelectionMonitor suspension, sandbox/broker acceptance and Ultra regressions remain pending. P5/G5 is not complete, and earlier open gates remain open.

## P5 application wiring increment

Agent Ultra now depends on the local harness package and has a separate native preview window, hidden unless `MILYONUS_COMPUTER_USE_PREVIEW=1` is present in its launch environment. It queues a deterministic fixture check before approval so no post-approval host click is needed. Stop, window close and application termination clean up the dedicated session. A token-based SelectionMonitor suspension invalidates pending reads, prevents new copy operations and drains in-flight clipboard restoration before starting the harness. User preferences are not rewritten.

Validation: Ultra build succeeded; its full headless desktop suite passed **3293 assertions, zero failures** (13 new checks). Harness build and self-tests passed **93 cases / 552 assertions**. Existing Ultra compiler warnings in unrelated self-test files remain; they were not suppressed. No GUI test or provider request ran in this increment.

The actual native preview lifecycle, visual UI, signed IPC and live-provider gates remain unaccepted. This development integration uses a sibling local package path and stays disabled by default. Changes do not modify AgentSandbox, WebMessage, plain-chat, Code or hidden Ultra beta routing. See `Integrations/AgentUltra/README.md` for operation and remaining gates.

## P5 isolated native lifecycle evidence

A separate ad-hoc Ultra preview bundle now permits native UI checks without restarting the user's running Ultra application or starting account/chat/bridge services. Live tests verified pending approval display, Stop with companion removal, and window close with companion removal and preview exit code 0. The existing Ultra process remained running. No native approval was granted and no fixture action was performed by this preview run. The action acceptance remains open without repeated approval requests.

Code review then found and fixed suspension release starting an otherwise unstarted SelectionMonitor. A new regression assertion covers this lifecycle boundary; repeated `start()` no longer duplicates monitoring timers. Preview diagnostics now emit state transitions instead of an entry for every status poll. Native lifecycle evidence retains the pre-fix binary hash; it is not silently reassigned to the later build.

The initial lifecycle regression test tried to instantiate the real monitor/panel path inside the headless suite and the process exited 134. That failing run is retained. The test now checks the extracted pure `shouldWatch` policy for unstarted, suspended and active states; this avoids claiming headless coverage of AppKit panel behavior.

Latest verification after the isolated-preview and monitor lifecycle fixes: Ultra full regression suite **3296 passed / 0 failed**; harness **93 cases / 552 assertions**, zero failures. Pending-session native Stop/close acceptance is recorded separately from unperformed approved-action acceptance.

## P6 local-state hardening increment

Private journal reads now use nonblocking open followed by descriptor validation, rejecting a FIFO without waiting for a writer. Journal files with multiple hard links are rejected. ProcessLease validates the private owned parent directory plus regular-file type, owner, private mode and a single hard link. Invalid state is preserved rather than silently repaired. The advisory lock remains coordination for cooperating processes, not production peer authentication.

Four deterministic regression cases cover FIFO refusal and latency, hard-linked journal refusal, public/hard-linked lock refusal and unsafe parent-directory refusal. Tests use disposable temporary directories. Native lifecycle and distribution acceptance remain separate; these changes do not complete G6.

P6 increment validation: Debug and optimized Release both passed **97 cases / 566 assertions**, zero failures; independent wire-schema validation remains **25 checks passed**. No native apps were launched or repackaged during this increment, so existing native evidence retains its original binary scope.


## P6 journal completion integrity

Completion now checks the persisted intent fingerprint, including the execution method, before accepting a result. A response must correlate to its completion request. Completed entries are immutable: an exact repeated completion is harmless, but a different result is rejected, including attempts to replace an unknown effect with success. The v1 journal format and semantic fingerprints remain compatible.

The asynchronous execution engine now forwards its execution method into completion. Invalid response correlation pauses the session and leaves the original intent unresolved for recovery; it cannot trigger an automatic replay.

Six new deterministic cases cover changed intents, both native methods, response correlation, immutable results across restart, engine replay without another dispatch, and engine pause after invalid completion. Debug and optimized Release passed **103 cases / 602 assertions**, zero failures. These are synthetic tests with disposable journals and fake drivers, not native desktop acceptance. No apps were launched or repackaged. G6, real-provider native acceptance, and approved Ultra action acceptance remain open.


## P6 persistence failure containment

A failed intent or completion write now latches the ledger against further mutation. This prevents later writes from a potentially divergent in-memory snapshot after a failed durability barrier. Intent persistence failures pause the execution session before driver dispatch. Completion failures continue to pause with an unknown effect; restoring filesystem permissions does not silently re-enable the same ledger.

Four additional deterministic tests exercise failed-intent reopening, frozen writes after failed completion, rename-failure temporary-file cleanup, and engine completion failure after a simulated effect. The existing intent-failure test additionally verifies session pause. Debug and optimized Release both passed **107 cases / 632 assertions**, zero failures.

The [journal recovery matrix](evidence/journal-recovery.md) separates tested filesystem boundaries from untested power-loss, disk-full and post-rename directory-sync failures. No GUI processes, provider calls, or production journal changes were used. CU-035 and G6 remain incomplete.


## P6 durability-boundary fault injection

Added package-only write checkpoints before file fsync, rename and directory fsync. The public ActionLedger initializer always uses the normal writer with injection disabled; no provider, RPC, environment or CLI control exposes checkpoints. Tests run actual temporary-file creation and replacement, throwing at the selected boundary.

Four new cases cover intent and completion at all three boundaries plus engine behavior after successful rename. They verify cleanup, latched write refusal, zero effect after failed intent, one effect after failed completion, paused sessions, and reopened journal contents. Post-rename completion may be readable after the caller received an error; the original instance still refuses mutation and reports its unresolved result as unknown.

Debug and optimized Release passed **111 cases / 708 assertions**, zero failures. The recovery matrix now records injected post-rename coverage. Actual kernel fsync failures, disk exhaustion, process crashes, reboot and power-loss durability remain unverified. No native apps were launched or repackaged; no provider calls were made. CU-035/G6 and prior native acceptance gaps remain open.


## P6 abrupt subprocess termination recovery

Two new regression matrices launch six isolated self-test children per build configuration and terminate them with SIGKILL at the three journal write checkpoints during intent or completion. Tests verify signal termination, writer-lock reacquisition, survival of a prior completed entry, unresolved intent handling, and the expected old/new journal state after rename. Each child has a ten-second deadline and a minimal environment; no credentials are inherited.

Unlike thrown-error cleanup, abrupt termination before rename leaves a private temporary journal file. Tests verify 0600 permissions, absence of fixture plaintext, and that reopening neither promotes nor deletes the orphan. All such files belong to disposable test directories removed by the parent.

Debug and optimized Release passed **113 cases / 761 assertions**, zero failures, including six killed subprocesses in each configuration. This establishes subprocess-death recovery on this development host. It does not validate power loss, reboot, disk exhaustion, kernel fsync failures or the native companion crash matrix. No GUI apps were launched or repackaged. CU-035/G6 remain open.


## P6 journal admission and capacity boundaries

Journal recovery now validates persisted key/result identifiers and SHA-256 fingerprint shape before admitting entries. All ledger request entry points validate action contracts, and completion rejects invalid action identifiers before persistence. Valid v1 journals remain compatible. Structural checks do not authenticate state against same-user filesystem modification.

Five new deterministic cases cover thirteen malformed record variants, duplicate keys, excess entries, oversized files, the exact 2,000-entry boundary, and invalid new records. At capacity, an existing action can still complete and survive reopening, while a new intent is refused without modifying disk. Validation refusal does not latch an otherwise healthy ledger; actual persistence failure still does.

Debug and optimized Release passed **118 cases / 822 assertions**, zero failures. No GUI apps were launched or repackaged. Retention and safe capacity rollover remain unimplemented; records are never silently evicted to permit new actions. G6 and the native/provider/distribution acceptance gaps remain open.


## P6 client reply boundary hardening

The stdio client now validates reply envelopes before consuming pending continuations. Boolean IDs cannot alias integer request IDs; invalid ID types, ambiguous result/error envelopes and malformed JSON close the transport promptly. Oversized replies retain RESOURCE_LIMIT rather than becoming a generic cancellation. Calls after closure consistently return CANCELLED. Interrupted reads retry, and invalid initialize results close their child transport.

Five new tests cover decoder admission and actual inherited pipes to synthetic self-test children, including a successful handshake/status control. Debug and optimized Release passed **123 cases / 878 assertions**, zero failures; both builds completed without compiler warnings in this increment. No native companion or fixture app was launched or repackaged.

See [client transport evidence](evidence/client-transport.md). This does not establish production peer authentication or complete hostile transport acceptance. Strict MCP content validation, duplicate JSON members, blocked writes and hostile child termination remain review areas. Earlier native/provider/distribution gates remain open.


## P6 local tool-result validation

The SDK now validates the local companion's single-text-content contract and requires a genuine boolean isError flag when present. Unknown error codes, malformed content and typed payload decoding failures close the transport with PROTOCOL_MISMATCH. Recognized tool-domain errors remain distinct and do not independently close a healthy transport.

Four new tests cover eleven invalid envelope variants, valid success/domain distinctions, six malformed tool modes over actual pipes, and consecutive valid domain refusals on the same connection. Debug and optimized Release passed **127 cases / 917 assertions**, zero failures. No native apps or provider requests were used.

This deliberately narrow decoder does not broaden supported MCP content types. Duplicate JSON members, blocked writes, hostile child shutdown and semantic action-response correlation remain review areas. Native companion acceptance and production security gates remain open; see docs/evidence/client-transport.md.


## P6 SDK action-result correlation

All SDK mutation methods now validate that the embedded result requestId matches the submitted action and that actionId satisfies the bounded identifier format. A correlation/identifier failure closes the transport with PROTOCOL_MISMATCH, and subsequent mutations are refused without replay. Correlated results preserve their reported effect and verification, including unknown outcomes; correlation is not independent evidence of completion.

Two actual-pipe test matrices cover four malformed outcomes across semantic action, native click and native text routes, follow-up refusal, and valid applied/unknown controls. Debug and optimized Release passed **129 cases / 971 assertions**, zero failures. No compiler warnings were emitted in these builds.

These are synthetic-child SDK tests with no desktop effects, provider calls or native app launches. Observation/session response correlation, duplicate JSON members, blocked writes, hostile child shutdown and native/distribution acceptance remain open. See docs/evidence/client-transport.md.


## P6 SDK session and observation correlation

Session replies now validate fixture scope, bounded identifiers and positive generations. Open requires the companion's initial awaitingApproval/generation-1 state. Owned status replies cannot switch session or disappear as null. Heartbeat results must match the requested session/generation and ready state. Cancellation validates identity and accepts cancelled or expired state. Observations validate session, fixture scope, positive PID and bounded observation ID. Mismatches close the transport; no automatic retry is introduced.

Two actual-pipe matrices cover nineteen invalid scenarios and valid lifecycle controls, including expired cancellation. Debug and optimized Release passed **131 cases / 1016 assertions**, zero failures, without compiler warnings. No native apps were launched or repackaged and no provider requests were made.

These synthetic peers do not provide approval or prove foreground/process authenticity. Native safety and independent agent verification remain in place. Duplicate JSON members, blocked writes, hostile child shutdown, production peer authentication and native/distribution gates remain open. See docs/evidence/client-transport.md.


## P6 SDK cancellation and late replies

RPC dispatch now refuses already-cancelled tasks before issuing a request, and checks task/transport state again after a reply resumes its continuation. Closed transports ignore late replies. Cancellation continues to close the dedicated transport and drain all pending calls without retrying any action.

Four actual-pipe tests verify pre-cancelled non-dispatch, sibling continuation draining, idempotent shutdown, and a confirmed late reply from a temporarily SIGTERM-ignoring synthetic child. Read-only package-level request counters make dispatch/pending assertions deterministic; no public control or RPC was added. Debug and optimized Release passed **135 cases / 1028 assertions**, zero failures.

These tests use synthetic status requests, not native actions. Cancellation is not rollback of an effect already dispatched. Indefinitely hostile child shutdown, blocked writes, native interruption and production authentication/distribution gates remain open. No native companion/fixture apps were launched or repackaged. See docs/evidence/client-transport.md.


## P6 owned-child termination fallback

SDK shutdown now schedules SIGKILL for its directly launched child if it remains running one second after SIGTERM. Input closure and pending-call cancellation happen first. Deinitialization uses the same fallback unless shutdown already began. No process group or unrelated app is targeted.

Three actual-pipe tests cover explicit shutdown and task cancellation against a child ignoring SIGTERM/EOF, plus cooperative exit without escalation. The hostile fixture has a separate eight-second fail-safe; tests require exit within three seconds with SIGKILL status. Debug and optimized Release passed **138 cases / 1035 assertions**, zero failures, without compiler warnings.

These are synthetic-process teardown tests. OS scheduling can delay escalation, and native held-input cleanup, descendant-held pipes, blocked SDK writes, production peer authentication and native/distribution gates remain open. No native companion/fixture apps were launched or repackaged. See docs/evidence/client-transport.md and docs/release.md.


## P6 nonblocking transport and bounded resources

Replaced synchronous actor pipe writes with a nonblocking, serialized queue capped at eight frames. Partial writes retain offsets, yield between 4,096-byte chunks, and stop at a ten-second deadline. SIGPIPE is suppressed per write descriptor. Cancellation/shutdown clears queued frames and pending calls without replay. The nonblocking reader checks cancellation while waiting for data, owns descriptor closure, and no longer requires EOF from descendant-held stdout. Per-request timeout tasks are removed and cancelled on completion, error, expiry or shutdown.

Nine additional actual-pipe cases cover shutdown/cancellation under confirmed backpressure, ordered partial frames, blocked-write expiry, inherited-output reader shutdown, timer lifecycle, closed-stdin refusal, and pending-capacity protection. The initial late-reply fixture expected a successful write after shutdown; the new reader correctly closed first. Its updated marker accepts confirmed pipe refusal or a written late reply. A second fixture searched raw JSON for a slash that the encoder escaped; it now reads the decoded method. Both failing test logs are retained and are not passing evidence.

## P6 ambiguous JSON admission and consolidated review

Added shared package-only validation of original UTF-8 JSON bytes. Foundation validates syntax; a bounded walk rejects duplicate object keys (including escaped-equivalent spellings), excessive nesting and excessive bytes. SDK envelopes, domain errors and typed payloads use this validation. The companion also validates before dispatch. Five new cases cover duplicate members, valid nested/string controls, byte/depth boundaries, malformed/non-UTF-8 input and ambiguous requests; existing pipe matrices now include four duplicate-field modes.

A clean Debug build and full suite, independent schema validation, and clean optimized Release build/full suite all passed: **156 cases / 1329 assertions**, zero failures in each Swift configuration; **25 schema checks**, zero failures. No compiler warnings were emitted. No native companion or fixture app was launched or repackaged, and no provider requests were made. Temporary self-test children and a three-second stdout-holding descendant were used only for transport tests.

The companion request-admission change is compiled and shares the tested validator; a new live companion acceptance run remains outstanding. The security review at docs/security/review.md consolidates addressed findings and open gates. Performance/energy soak, native forced-exit cleanup, signed peer authentication, broad application scope, retention, real-provider native acceptance and distribution remain incomplete. No phase gate is marked complete by this increment.

## CU-018 bounded gesture preparation (2026-10-25)

- Added an internal drag/scroll sequence builder with finite target-region checks, bounded duration and segment counts, exact signed scroll totals, and per-event size limits.
- Added an opt-in `--gesture-fixture` layout with a synthetic drag canvas, completion coordinates/count and a real 30-row scroll view. Default fixture launches retain their existing layout.
- Four synthetic cases cover geometry/timing, malformed bounds and budgets, signed scroll conservation, and permission revocation with release at the last drag position. Debug and optimized Release suites: 156 cases / 1329 assertions / zero failures; independent schema checks: 25 passed.
- No new RPC capability, application scope, permission or native approval path was added. The gesture fixture has not been launched or accepted natively. Native target resolution, occlusion checks, wire contracts, SDK exposure and independent effect verification remain engineering work; G3 stays open.
- See `docs/gesture-execution.md` for implementation bounds and the next integration gate.

## CU-018 experimental vertical scroll integration (2026-10-25)

- Added bounded `scrollPixels` action contracts, a dedicated scroll schema, the optional Swift `NativeScrollHarnessClient`, and the MCP `desktop_scroll` route. No caller-supplied coordinates, horizontal scroll, drag RPC, extra applications or provider planner actions were added.
- Scroll has a distinct journal execution method. The engine rejects routing mismatches before recording intent. Existing session, foreground, target freshness, geometry, single-writer and generation checks remain in place.
- Native preflight and each input event require exact target ancestry under the pointer and stable scrollbar identity. A requested-direction boundary is refused before intent. Verification observes directional movement of the scrollbar; exact pixel displacement is not claimed. Unverifiable effects pause without replay.
- Synthetic coverage includes request bounds/round trips, method admission, delta-sensitive idempotency, uncertain-effect pause and the new SDK route's malformed/correlated result handling.
- Live native scroll is **not accepted**. The optional fixture's AX enabled state, scrollbar value/ancestry, occlusion, direction, physical interruption and boundary behavior need live validation. No GUI session, app focus, API request or permission change was made for this increment. G3 remains open; drag is still internal only.

Validation for the scroll integration: clean Debug and optimized Release builds passed without compiler warnings; both suites passed 160 cases / 1372 assertions / zero failures. Independent schema validation passed 36 checks. This is synthetic/compiled evidence, not native gesture acceptance.

## CU-018 experimental fixed drag integration (2026-10-25)

- Added `desktop_drag`, optional `NativeDragHarnessClient.drag`, a dedicated wire schema and the distinct `nativeDrag` journal method. The fixed path runs between quarter and three-quarter horizontal positions at the center of the resolved fixture canvas. No caller coordinates or duration override are accepted.
- Preflight hit-tests the sampled path before intent. Each event rechecks session authorization, current foreground/window identity, target geometry and exact canvas hit identity. Existing held-input cleanup remains active.
- Independent verification requires one additional fixture completion and both expected local endpoints within a two-point rounding tolerance. Partial movement, malformed state or unchanged completion cannot report success.
- Added synthetic receipt, contract, method-routing, idempotency, uncertain-effect persistence and cancellation coverage; SDK transport correlation checks now include drag.
- Live drag/scroll acceptance remains open. These binaries were compiled, not packaged or launched; no native approval was bypassed and no user window was manipulated. General drag paths, arbitrary applications and provider-generated gesture plans remain unsupported.

Fixed-drag increment validation: clean Debug and optimized Release builds passed without compiler warnings; both suites passed 165 cases / 1424 assertions / zero failures. Independent schema checks: 42 passed. No native gesture acceptance is inferred from these results.

## Deterministic gesture acceptance runner (2026-10-25)

- Added a separate `ComputerUseAcceptance` target and an explicit `gesture-fixture-selftest ... --allow-native-fixture-input` CLI command. The runner never approves sessions, activates windows, calls a provider or retries mutations.
- Before mutation, it requires both fixture surfaces, valid initial drag state, one normalized scrollbar value and a non-truncated observation. Between actions it checks session/generation, process identity and fresh observation handles. Scroll movement and drag counter/endpoints are read back independently of the action result.
- The AX adapter now exposes finite normalized fixture scrollbar values as strings for read-back verification. Secure-field exclusion and the fixture-only policy remain intact.
- The CLI records UTC timestamps, executable hashes, fixture PID and success/failure results; failures exit nonzero. Passing requires successful verification and session cancellation. The command has not been executed natively; no live acceptance evidence was created.
- Synthetic clients cover success, missing/ambiguous/truncated fixture data, unchanged movement, unknown effects, changed PID/generation, stale observations partial drag receipts and cancellation arriving during status reads. These cases do not prove AppKit gesture delivery.

Acceptance-runner validation: Debug and optimized Release builds passed without compiler warnings; both suites passed 170 cases / 1454 assertions / zero failures. Independent schema validation remains 42 passing checks. The native acceptance command was not launched.

## P4 typed capability discovery (2026-10-25)

- Added shared `HarnessCapabilities`, optional `CapabilityHarnessClient`, SDK decoding/validation and a dedicated schema. The companion emits the same contract. Semantic and experimental feature declarations remain separate.
- The SDK closes on malformed or incompatible policy/limits. Discovery does not approve a session, request permissions, activate windows or automatically expand dispatch. Permission values are snapshots.
- Gesture acceptance now checks both experimental flags, scroll capacity and Accessibility before opening a native session. Existing host protocols remain source-compatible.
- Synthetic tests cover absent permissions, round trips, policy/limit mismatches and malformed pipe responses. No GUI, provider or native gesture test was run. P4 remains incomplete: image/egress negotiation and live pilot acceptance are still open.

Capability-discovery validation: Debug and optimized Release builds passed without compiler warnings; both suites passed 174 cases / 1495 assertions / zero failures. Independent schema validation passed 51 checks. These are synthetic/compiled results, not native acceptance.

## P4 negotiated SDK dispatch (2026-10-25)

- Added opt-in `NegotiatedHarnessClient` and adopted it in the gesture acceptance CLI. Each mutation gets a fresh validated capability response and checks the corresponding feature and bound before forwarding. Invalid shapes, disabled features, reduced bounds or discovery failure dispatch no mutation.
- Unknown results are not retried. Status/observation/cancellation delegate directly, so a broken discovery endpoint does not block session cancellation. Native session and target enforcement remains authoritative.
- Direct SDK clients and Ultra behavior are unchanged. Synthetic clients verify disabled features, changed limits, discovery failure, unknown effects and cancellation independence. No native session or provider request was initiated.

Negotiated-dispatch validation: Debug and optimized Release builds passed without compiler warnings; both suites passed 177 cases / 1509 assertions / zero failures. Wire schemas are unchanged from the 51-check passing run. This does not constitute native or provider acceptance.

## Gesture acceptance geometry and negative cases (2026-10-25)

- Closed an independent-verification gap: the runner now validates gesture target roles, initial scroll bounds and unchanged scroll geometry after the action, in addition to existing final drag geometry checks.
- Added synthetic upward-scroll control and negative cases for wrong direction, missing/ambiguous/non-finite scrollbar values, wrong AX roles and resized scroll/drag surfaces. Invalid initial data dispatches nothing; invalid scroll results stop before drag.
- Native gesture delivery and physical interruption acceptance remain pending. No fixture/companion was launched, no native grant was created and no user window was manipulated.

Geometry-validation results: Debug and optimized Release suites passed 180 cases / 1526 assertions / zero failures, without compiler warnings. Wire schemas are unchanged from 51 passing checks. Updated ad-hoc development bundles were packaged and strict-signature checked using `scripts/build-apps.sh`; see `docs/evidence/gesture-package.log`. No app was launched. The CLI doctor reported Accessibility and Screen Recording granted, which does not establish permissions or live acceptance for the new companion binary. Native foreground testing awaits user availability.

## P6 development packaging safeguards (2026-10-25)

- Packaging now refuses active fixture/companion process names, serializes cooperating runs with a file lock and signs/verifies both complete staged bundles before publication. It does not terminate apps or manipulate windows.
- Failed publication attempts restore the previous bundle. Recovery material is preserved on errors, including restoration failure. Full two-app atomicity, check/use race elimination and power-loss acceptance are not claimed.
- Added headless Python packaging tests and integrated them into background verification. See `docs/development-packaging.md` for limits and recovery behavior. Live gesture testing remains deferred while the user works.

Packaging validation: six headless Python tests passed; actual Debug app packaging and strict ad-hoc signature verification passed. `swift build` and the standalone Swift suite passed (180 cases / 1526 assertions / zero failures). Shell/Python syntax checks passed. No app was launched and production distribution acceptance remains open.

## P6 packaging lock and recovery admission (2026-10-25)

- Added strict lock-file admission: regular, current-user-owned, single-link, private mode, no symlink following and non-blocking open. Existing app destinations must be directories; ordinary files and symbolic links are refused before any publication.
- A real second Python process verifies exclusive lock refusal and release. Synthetic-file tests cover unsafe lock types, invalid destinations and retention of the previous bundle when both publication and restoration fail.
- Ten headless Python tests passed. Actual development packaging and strict ad-hoc signature checks passed without launching an app. This is not production installer or native lifecycle acceptance.

Post-change `swift build` and standalone regression passed: 180 cases / 1526 assertions / zero failures. Python syntax and source whitespace checks passed. Live foreground tests remain deferred at the user's request.

## P6 full packaging orchestration regression (2026-10-25)

- Expanded headless packaging coverage to 15 tests. New scenarios invoke the real packaging workflow in a temporary synthetic repository with substituted build/signature/process results.
- All four signature-operation failure positions, either missing source binary, a late active-process report and an invalid second destination leave existing app material unchanged. The success control verifies published binary/metadata contents and staging cleanup.
- This is injected-failure orchestration evidence, distinct from actual ad-hoc signing and native lifecycle acceptance. User windows remain untouched; foreground testing is still deferred.

Full background workflow passed after the orchestration additions: clean Debug build without compiler warnings, 180 Swift cases / 1526 assertions / zero failures, 51 independent schema checks, 15 Python packaging tests, and actual ad-hoc packaging with strict signature checks. `docs/evidence/background-verification.log` records workflow completion. No native app was launched; Release Swift evidence remains the earlier 180-case run because this increment changes only packaging tests and documentation.

## P6 read-only packaging recovery inventory (2026-10-25)

- Added `build-apps.sh --recovery-status`, which reports candidate staging/previous bundle filesystem types without reading contents, building, signing, launching apps or modifying files.
- Inventory is bounded to 1,000 scanned entries / 100 candidates. Descriptor-relative metadata checks and no-follow directory opens refuse symlinks, including a tested directory-replacement race.
- Results explicitly remain unverified, non-atomic snapshots; active staging cannot be distinguished from abandoned recovery material. No automatic restoration or deletion was added.
- The actual inventory currently reports zero candidates. Native foreground tests remain deferred at the user's request.

Recovery-inventory validation: 20 headless Python tests passed, including non-creation, bounded enumeration, symlink refusal and directory-replacement race coverage. Actual read-only inventory succeeded with zero candidates. Swift build and regression passed (180 cases / 1526 assertions / zero failures); shell/Python syntax checks passed. No app was launched or native acceptance claimed.

## P6 package consistency receipt (2026-10-25)

- Packaging now records configuration, UTC time, signed executable/Info.plist hashes and Swift source/Package.swift hashes in `build/package-receipt.json`. Different pre-build/pre-publication source snapshots abort before app publication.
- The receipt is published after both apps. Earlier failures retain the previous receipt; partial publication or interruption can still produce a receipt/binary mismatch, so consumers must compare actual hashes. This is not a signed attestation or reproducible-build guarantee.
- Added tests for receipt byte matching, changed-source refusal with old receipt retention, unsafe hash inputs and invalid receipt destinations. Twenty-four Python packaging tests passed.
- Actual Debug packaging and strict ad-hoc signature checks passed. Independent receipt comparison matched four packaged files and 32 source inputs; see `docs/evidence/package-receipt-check.json`. No native app was launched.

Post-receipt Swift build/regression passed: 180 cases / 1526 assertions / zero failures. Python syntax and whitespace checks passed. Live GUI/provider acceptance remains deferred and separate from these results.

## P6 executable receipt verification (2026-10-25)

- Added read-only `build-apps.sh --verify-receipt` with structured match/mismatch output and nonzero failure status. Integrated it after packaging in background verification.
- Verification admits bounded duplicate-free JSON and validates version, algorithm, configuration and digest shapes. Receipt data cannot redirect file reads; known package paths use descriptor-relative no-follow opens. Oversized generated receipts are refused before publication.
- Tests cover changed executable/metadata/source inputs, malformed and oversized JSON, package-directory symlinks, pre-publication size refusal and actual CLI exit status against temporary synthetic packages.
- Actual verification matched all four package files and 32 source inputs. This is a consistency check, not fresh signature verification or native acceptance. No app was launched.

Receipt-verifier validation: 29 Python tests passed; Swift build/regression passed with 180 cases / 1526 assertions / zero failures. Actual verifier returned `matched`. Python/shell syntax and whitespace checks passed. No new Release/native acceptance is inferred from this packaging-only increment.

## P2 capture geometry and freshness (2026-10-25)

- Replaced independent axis clamping with uniform bounded capture sizing. Invalid floating-point geometry cannot reach an unchecked Int conversion. Raster output is bounded before PNG encoding.
- Rectangle validation rejects overflowing/unrepresentable upper edges; pixel conversion divides before multiplying to avoid intermediate overflow.
- Native capture rechecks cancellation, permission, window ID/PID/scope and geometry after capture. Detected movement/replacement refuses stale transforms. Framework cancellation/isolation and transient change-and-revert races remain limitations.
- Four synthetic geometry cases were added. No screenshot was captured, no native window was activated, and no image was stored or transmitted during this increment. Live P2 acceptance remains open; see `docs/capture-geometry.md`.

Capture increment validation: Debug and optimized Release builds passed without compiler warnings; both standalone suites passed 184 cases / 1571 assertions / zero failures. Independent wire-schema checks remained 51/51. Native post-capture freshness checks are compiled but not live accepted.

## P2 bounded capture result admission (2026-10-25)

- Added a ten-second monotonic capture/inventory deadline, checked around asynchronous work and before results are returned. Late results and cancellation are rejected; checks never extend the budget. This does not forcibly interrupt a stalled framework call.
- Capture timestamps now record screenshot-request start rather than result completion. Final permission checks cover encoded frames and inventory; inventory is capped at 100 fixture windows.
- Added deterministic deadline-boundary, non-renewal, budget and cancellation cases. No screenshot or native window interaction was performed. Live framework latency/isolation and permission-revocation acceptance remain open.

## P2 fixture capture selection (2026-10-26)

- Extracted shared metadata selection/revalidation used by the actual native capture route. Initial capture requires a unique main fixture window with valid identity/geometry. Post-capture selection also requires uniqueness, so a second eligible fixture window cannot leave an apparently valid frame from an ambiguous target.
- Added standalone cases for auxiliary-window exclusion, ambiguity, invalid IDs/geometry, replacement, movement, resize and a newly appearing second fixture process. These tests use synthetic metadata only; they do not authenticate code identity or close native capture acceptance.
- Capture deadline and selection changes remain within fixture-only observation scope. No windows were activated and no screenshot, provider request or input event was generated.

Capture deadline/selection validation: Debug and optimized Release builds passed without compiler warnings; both standalone suites passed 191 cases / 1628 assertions / zero failures. The development bundles were rebuilt through the checked-in packaging script with strict ad-hoc signature verification. Read-only receipt verification matched four package files and 35 source inputs. No companion or fixture was launched.

## P2 AX traversal and observation publication (2026-10-26)

- Added a shared 500 ms monotonic traversal budget with visited-node, depth and UTF-8 text limits. Final AX reads cannot silently refresh an overdue observation. Secure nodes consume the visit budget but remain excluded from exported values and descendants.
- Observation timestamps/target ages start before traversal. Targets publish only after final cancellation, permission, foreground and window checks; truncated observations retain diagnostic data but cannot authorize actions.
- The execution engine revalidates the original session generation after a platform read and invalidates targets on failure. Synthetic tests cover heartbeat/session expiry during observation, generation replacement, scope mismatch, permission errors and task cancellation.
- Native AX calls remain synchronous; hard timeout/worker isolation, TCC/focus interruption and large-tree live acceptance are still open. No native app, input, screenshot or provider call was used for this increment. See `docs/accessibility-observation.md`.

AX observation validation: Debug and optimized Release builds passed without compiler warnings, and both standalone suites passed 198 cases / 1977 assertions / zero failures. Independent wire schemas passed 51/51. Development packaging and strict ad-hoc signature checks passed; the receipt matched four package files and 36 source inputs. All evidence in this increment is background/synthetic or packaging evidence; no native GUI/provider gate was closed.

## P3 execution admission after blocking work (2026-10-26)

- Execution rechecks task cancellation and original session generation after preflight, before journaling. Rejected preflight invalidates cached targets and creates no intent.
- Both semantic and asynchronous paths recheck admission after durable intent persistence and before effect callbacks. A known refusal records `notApplied` without dispatch; failures after entering execution retain conservative unknown-effect handling.
- Synthetic tests advance the clock at preflight and journal barriers, replace a generation and cancel tasks before/after intent. They verify zero effects, absent or reopened journal records as appropriate, and exact retry without dispatch after a task-cancelled intent.
- Hard interruption of synchronous platform/filesystem calls and the live interruption matrix remain unaccepted. No native app or provider was used. See `docs/execution-admission.md`.

Execution-admission validation: Debug and optimized Release builds passed without compiler warnings; both standalone suites passed 201 cases / 2026 assertions / zero failures. Wire schemas passed 51/51. Development packaging and strict ad-hoc signatures passed, with four package files and 36 source inputs matching the receipt. Native interruption/provider/distribution gates remain separate and open.

## P3 late completion verification (2026-10-26)

- Callback verification now passes an original-session/generation and task-cancellation check before journaling. A late `passed` claim becomes `unavailable` with the relevant refusal error; reported effect and action identity are preserved.
- The normalized result is persisted, preventing an exact retry from restoring the rejected success claim or repeating a completed effect. Existing unknown-effect and journal-failure handling is unchanged.
- Added synthetic semantic/asynchronous coverage for cancellation, generation change, heartbeat/lifetime expiry, task cancellation, reopened receipts and replacement sessions awaiting native approval. Native post-dispatch interruption remains unaccepted; no GUI/provider work was performed.

Late-completion validation: Debug and optimized Release builds passed without compiler warnings; both standalone suites passed 204 cases / 2096 assertions / zero failures. Independent schemas passed 51/51. Development packaging and strict ad-hoc signatures passed; receipt verification matched four package files and 36 source inputs. Live GUI/provider/distribution acceptance remains open.

## P1/P4 action-result consistency (2026-10-26)

- Added shared result validation for identifiers and effect/verification/error consistency. Only an applied effect may carry passed/failed verification; passed verification cannot carry an error.
- SDK mutation routes close on malformed outcomes. The engine validates before late-result normalization; the journal rejects inconsistent completion and malformed persisted receipts without rewriting them.
- Added contract matrix, journal preservation, invalid late-result and five-route synthetic transport coverage. The result schema matches runtime relationships. No native app/provider was used; broader live acceptance remains open.

First result-validation Debug run: 208 cases / 2186 assertions / one failure. `StdioFailureTests.testReaderStopsWithInheritedOutputStillOpen` threw `TIMEOUT`; all new consistency cases passed. The failed log is retained as `docs/evidence/selftest-result-validation-first-attempt.log`. Root cause is not established. Revalidation uses unchanged tests and deadlines; a later pass does not erase this intermittent failure.

The unchanged Debug rerun passed 208 cases / 2189 assertions / zero failures. Independent result-schema validation passed 54/54. This rerun does not establish the cause of the prior inherited-output timeout.

Result-consistency validation: latest Debug and optimized Release builds passed without compiler warnings; both latest suites passed 208 cases / 2189 assertions / zero failures. Development packaging and strict ad-hoc signatures passed; the receipt matched four package files and 36 source inputs. No native GUI/provider/distribution gate was closed. The earlier intermittent stdio timeout remains an explicit reliability finding.

## P4 inherited-output timeout investigation (2026-10-26)

- Added a focused 20-iteration standalone test mode using the existing inherited-stdout test with unchanged deadlines and assertions. It stops on failure and does not launch native apps.
- Synthetic child stage markers and failure-only transport counters distinguish startup/handshake progress without logging payloads. Connection errors explicitly shut down the test client before rethrowing.
- Debug focused run passed 20 cases / 60 assertions / zero failures. The earlier timeout remains unresolved; repetition and instrumentation do not establish a fix. Production transport behavior is unchanged. See `docs/stdio-timeout-investigation.md`.

Focused investigation: Debug and optimized Release each passed 20 inherited-output iterations / 60 assertions / zero failures with unchanged test deadlines. No reproduction occurred in those runs. This is bounded synthetic stress evidence, not closure of the earlier intermittent failure. The existing development package receipt still matches because production sources were unchanged.

Post-instrumentation full verification: Debug and optimized Release builds passed without compiler warnings; both full suites passed 208 cases / 2189 assertions / zero failures. Existing package receipt verification passed. Production sources and wire schemas were unchanged; no new native/provider acceptance is claimed, and the prior timeout remains unresolved.

## P4 SDK opening/cancellation lifecycle (2026-10-26)

- Added a single pending-open guard and lifecycle-token check before adopting an open reply or starting heartbeat. Cancel during opening and shutdown invalidate that token; late replies close the dedicated connection without creating local ownership.
- Cancellation and shutdown remain available during opening. Rejected concurrent opens and reopen attempts issue no additional RPC.
- Synthetic tests hold the open reply until cancellation to exercise ordering deterministically; package-only diagnostics expose ownership/heartbeat booleans. No native companion, provider, foreground input or approval was used. See `docs/sdk-session-lifecycle.md`.

SDK lifecycle validation: Debug and optimized Release builds passed without compiler warnings; both full suites passed 210 cases / 2204 assertions / zero failures. Schema validation passed 54/54. Development packages were rebuilt with strict ad-hoc signature verification; the receipt matched four package files and 36 source inputs. No native app was launched. The earlier inherited-output timeout remains a separate unresolved finding.

## P4 heartbeat ownership lifecycle (2026-10-26)

- Automatic heartbeat tasks capture the session ID and a fresh lifecycle token at successful open. Ticks recheck ownership before/after async work and expected domain refusals; an obsolete status reply cannot renew a cancelled/replacement session.
- Lower-level timeout, malformed-response and task-cancellation shutdown behavior is unchanged. Cancelling a timer with an in-flight RPC can still close the dedicated connection conservatively; seamless reuse is not claimed.
- Added synthetic held-status tests for cancellation, reused IDs after replacement, and a positive renewal/shutdown control. They invoke the same tick used by the timer without shortening its interval. No native GUI/provider calls were made; see `docs/sdk-session-lifecycle.md`.

Heartbeat ownership validation: Debug and optimized Release builds passed without compiler warnings; both suites passed 213 cases / 2219 assertions / zero failures. Wire schemas passed 54/54. Development packaging and strict ad-hoc signatures passed; receipt verification matched four package files and 36 source inputs. No native application was launched, and the earlier inherited-output timeout remains unresolved.

## P2/P4 observation payload admission (2026-10-26)

- Added shared structural observation validation at execution-engine and stdio boundaries: IDs, scope metadata shape, timestamp/source, node count, unique handles/actions, role/geometry and aggregate UTF-8 text budget.
- Driver failures invalidate cached targets; malformed SDK observations close the dedicated transport. Truncated diagnostic observations remain representable but do not gain native action authority.
- Added contract, driver and synthetic pipe coverage. Schema rules now reject duplicate element objects/actions and empty roles; cross-object unique IDs and aggregate byte/geometry arithmetic remain explicit runtime checks. No GUI/provider interaction occurred. See `docs/observation-validation.md`.

Observation-admission validation: Debug and optimized Release builds passed without compiler warnings; both suites passed 216 cases / 2250 assertions / zero failures. Independent schemas passed 57/57. Development packaging and strict ad-hoc signatures passed; the receipt matched four package files and 37 source inputs. No native app/provider was used. The prior inherited-output timeout remains unresolved and live observation acceptance remains separate.

## P1/P4 session metadata consistency (2026-10-26)

- Added shared session metadata validation used for open, status, heartbeat and cancellation replies. Pause reasons belong only to paused sessions; identifier, bundle, positive generation and finite-time bounds are checked.
- Existing scope/state/generation correlation is preserved. Client wall-clock expiry does not replace the companion's monotonic lease or native approval.
- Added state/reason matrix, boundary, injected-clock controller-transition and four-route synthetic pipe tests. Schema rules mirror the state relationship. No native UI/provider interaction occurred; see `docs/session-validation.md`.

Session-consistency validation: Debug and optimized Release builds passed without compiler warnings; both suites passed 219 cases / 2330 assertions / zero failures. Independent schemas passed 59/59. Development packaging and strict ad-hoc signatures passed; the receipt matched four package files and 38 source inputs. No native app/provider was used. Live acceptance and the earlier inherited-output timeout remain open.

## P4 custom-adapter orchestration boundary (2026-10-26)

- Added shared contract validation inside AgentRunner for supplied/current sessions, observations and action results, independently of stdio SDK validation. Initial status application scope is checked before planning.
- Explicitly reject truncated, stale/future observations and reused post-planning observation IDs before mutation or completion. The general runner previously lacked the truncated check; earlier documentation was corrected rather than treating older native evidence as proof.
- Added scripted custom-adapter tests for zero planner calls on invalid input, zero mutations on invalid fresh observations, and no retry after malformed results. Timestamp checks are conservative metadata screening; native monotonic checks and authorization remain authoritative. No provider or native interaction occurred; see `docs/agent-adapter-boundary.md`.

The first runner-boundary regression run exposed an outdated positive integration fixture that reused one observation ID for every read. Its failed log is retained in `docs/evidence/selftest-agent-boundary-first-attempt.log`. The fixture now emits increasing observation IDs, matching the real adapter contract; dedicated negative tests still reject reused IDs. No runtime check was relaxed.

Runner freshness is also rechecked after the authorization-status await, so that wait cannot silently age an observation past the admitted window before action or completion. The existing stale-observation tests exercise the shared admission rule; native delayed-status/clock-change acceptance remains open.

Agent-adapter validation: final Debug and optimized Release builds passed without compiler warnings; both suites passed 222 cases / 2370 assertions / zero failures. Independent schemas remained 59/59. Development packaging and strict ad-hoc signatures passed; receipt verification matched four package files and 38 source inputs. The positive integration fixture was corrected, while reused-ID rejection remains tested. Native/provider acceptance and the earlier inherited-output timeout remain open.

## P4 provider input admission

- Both provider adapters now share fixture context validation before credentials and before transport submission, including structural, freshness, truncation, exported-target uniqueness and step-budget checks. Infinite deadlines are rejected.
- Direct planner calls cannot bypass these checks by omitting AgentRunner. Existing scope consent, field minimization, no-retry/no-fallback behavior and independent completion verification remain unchanged.
- Added synthetic direct-call coverage for both providers, asserting zero credential reads and zero sends for rejected inputs. No real credentials, network or native GUI were used. Slow-credential and native/provider acceptance remain separate; see `docs/provider-input-admission.md`.

Provider-input validation: Debug and optimized Release builds passed without compiler warnings; both suites passed 223 cases / 2418 assertions / zero failures. Independent schemas remained 59/59. Development packaging and strict ad-hoc signatures passed; receipt verification matched four package files and 39 source inputs. Invalid-input tests observed zero credential reads and zero synthetic sends. No real provider/native acceptance is claimed; the earlier inherited-output timeout remains open.

## P4 provider response JSON consistency

- Both response decoders now use the shared strict JSON parser before dictionary interpretation. OpenAI nested proposal text is independently validated; Anthropic tool input is covered by the complete response scan.
- Duplicate members, escaped duplicate names and excessive nesting are rejected before proposing actions, including duplicates in otherwise ignored metadata. Existing byte limits, exactly-one proposal, refusal behavior and no retry remain in place.
- Added synthetic response-envelope/input/nesting cases for both providers. All requests use stub transports; no real provider or native operation occurred. See `docs/provider-response-validation.md`.

The first provider-response regression run passed the new JSON cases but hit two unexpected stdio timeouts in existing mismatch/closed-input tests (226 cases / 2374 assertions / two failures). Its log is retained as `docs/evidence/selftest-provider-response-first-attempt.log`. Fixture stage diagnostics now cover all modes, and a package-only optional SDK callback captures bounded timeout counters before cleanup. The public initializer disables the callback; production deadlines and retry behavior are unchanged. An instrumented rerun passed 226 cases / 2438 assertions; this does not resolve the intermittent timeout. A deliberate unanswered-request case additionally verifies timeout diagnostics and terminal cleanup.

Provider-response final validation: Debug and optimized Release builds passed without compiler warnings; both suites passed 227 cases / 2448 assertions / zero failures. Independent schemas passed 59/59. Development packaging and strict ad-hoc signatures passed; receipt verification matched four package files and 39 source inputs. The intentional unanswered-request case verified diagnostics and terminal cleanup with the existing deadline. Earlier unexpected stdio timeouts remain unresolved. No native window, provider request or production distribution acceptance was performed.

## Native gesture acceptance attempt — 2026-10-27

The first live gesture run received native approval but failed with `UNSUPPORTED_CAPABILITY`; it did not establish gesture acceptance. Evidence is retained in `docs/evidence/native-gestures-2026-10-27-attempt-1.json` and its log. A fixture-only read-only AX probe found `fixture.scroll` with role `AXScrollArea` and no `AXEnabled` attribute, while `fixture.drag.canvas` exposed `AXGroup` and enabled=true. The acceptance runner requires both surfaces to advertise their actions before its first mutation.

The optional fixture scroll view now explicitly exposes enabled=true. The harness still rejects absent/false enabled attributes; no native approval, foreground, identity or execution checks were relaxed. Debug build and the required standalone suite passed (227 cases / 2448 assertions / zero failures), and fresh ad-hoc development packaging/receipt verification passed. The existing Release evidence predates this fixture-only fix. A second live run is pending user availability; the fix is not yet native-accepted. Only the project fixture was terminated for packaging; no unrelated application was touched.

## Native gesture acceptance passed — 2026-10-27

Attempt 2 passed at 14:48:48 Europe/Istanbul after explicit user availability and manual native approval. The current packaged fixture completed two actual native actions: vertical scrollbar value changed from 1 to 0.7214484679665738, and the drag completion count changed from 0 to 1 with matching endpoints. Independent observations verified both postconditions, and session cancellation succeeded. `docs/evidence/native-gestures-2026-10-27-attempt-2.json` records exact companion/fixture hashes and UTC timestamps; its log is retained separately. The first failed attempt remains preserved.

This closes the basic two-action native fixture scroll/drag slice and validates the explicit fixture AXEnabled fix. It does not close G3: interruption, physical input, occlusion, permission revocation, hardware and repetition matrices remain pending. No provider call or arbitrary application interaction occurred. Next priority is real OpenAI execution (missing invoking-process key/model), then Ultra live acceptance; signed distribution still requires Developer ID and notarization credentials.

## Real Anthropic native fixture pilot passed — 2026-10-27

The user explicitly supplied an Anthropic credential and requested execution with `claude-opus-5-5`. The credential was supplied through non-echoing stdin and held in the parent process environment; it was not persisted in project files or forwarded to the companion. The real provider contract check passed with two validated proposals over synthetic observations and zero desktop actions.

The subsequent native provider pilot passed at 14:52:51 Europe/Istanbul: one real model-proposed fixture edit, independent completion verification and successful session cancellation. The native session reached ready through the existing approval control; no RPC or script granted approval. Read-only focus activation retries occurred before execution. Logs and executable hashes are retained in `docs/evidence/anthropic-live-2026-10-27.json` and `docs/evidence/anthropic-live-2026-10-27-native.json`. No screenshot or unrelated application content was sent.

This accepts one Anthropic-driven native fixture slice. OpenAI remains untested without its own credentials/model; the broader 10×5 provider pilot, interruption coverage, Ultra live action and signed distribution remain open. Next priority is the isolated Ultra live action/lifecycle test, followed by its separate normal-host integration acceptance. The shared secret should be rotated after its disclosure in chat; no saved copy is required by this implementation.

## OpenAI live pilot attempted — 2026-10-27

The user supplied a dedicated OpenAI credential for immediate testing. Model discovery succeeded through the real models endpoint; `gpt-5.4-mini-2026-03-17` was present and explicitly selected for the pilot. The key was supplied through non-echoing stdin, held in the invoking process environment and not persisted or passed to the companion. Persistent OpenAI configuration has not been installed.

Attempt 1 ended with `FOCUS_CHANGED`. A fresh explicitly announced attempt 2 ended at 14:58:07 Europe/Istanbul with `NO_PROGRESS`. Both failed evidence records are retained in `docs/evidence/openai-live-2026-10-27-native.json` and `docs/evidence/openai-live-2026-10-27-native-attempt-2.json`, including executable hashes. Neither is accepted completion.

The runner raises NO_PROGRESS after three consecutive unchanged visible-state comparisons following actions; successful provider decoding and action-result checks occurred earlier in that execution path. The current logs do not retain individual proposals or per-step state, so they do not establish why the model/action sequence stopped changing visible state. Do not infer a particular proposal, missing edit, or provider defect from the summary error alone. The run cancelled its session and closed the transport. No limits, foreground checks or completion rules were relaxed, and no further automatic replay was attempted.

Next investigation: add bounded fixture-only step diagnostics (proposal kind, selected known identifier, completion equality and effect/verification metadata; no credentials or raw field text) to the explicit acceptance command before another native run. This is a concrete live-pilot failure investigation, not a new generic protocol-hardening phase. OpenAI end-to-end acceptance remains open; the separately passing Anthropic pilot remains valid for its recorded binary and scope.

## OpenAI no-progress diagnosis and accepted native slice — 2026-10-27

Attempt 3 added bounded CLI planner diagnostics and reproduced NO_PROGRESS: the first setValue matched the completion condition and passed independent action verification, but the model repeatedly proposed that same value after observed completion was already true. Diagnostics record only proposal kind, allowlisted target, equality booleans and previous effect/verification; no text or credentials. This establishes the repeated-write cause for attempt 3, without retroactively inventing traces for attempt 2.

The OpenAI instruction now explicitly requires finish with null target/text when the observed completion value matches, and forbids reapplying the same value or saving after completion. Core no-progress, fresh observation, native authorization and independent completion rules remain unchanged. Attempt 4 timed out awaiting approval before any planner diagnostic. A new `openai-plan-check` CLI uses real API calls with synthetic observations to check the required action and finish; both proposals passed.

After renewed user availability and manual approval, attempt 5 passed at 15:12:41 Europe/Istanbul with gpt-5.4-mini-2026-03-17: one setValue followed by finish, independently verified completion and successful cancellation. The evidence JSON includes exact CLI/companion/fixture hashes. Prior failures are retained. This is one native provider slice, not the full 10×5 pilot, Ultra acceptance or general application support.

Final harness checks for this increment: Debug and Release each 227 cases / 2448 assertions / zero failures; independent schemas 59 checks; packaging 29 tests; actual package receipt matched; real MCP smoke 18/0 and SDK smoke 4/0; focused inherited-output stress 20 cases / 60 assertions / zero failures. Passing stress does not resolve the earlier intermittent timeout. No credentials were persisted. Ultra checks are tracked separately below.

## Isolated Agent Ultra native acceptance — 2026-10-27

Rebuilt the separate ad-hoc preview using the existing Ultra checkout without editing its sources. The current host headless suite passed 3598 assertions / zero failures. In the isolated native preview, the local fixture action progressed through awaitingApproval, ready and completed with no phase error. The visible UI independently showed completed, then Session stopped after Stop. Closing the preview ended its launched process with exit code 0; no preview or companion remained. This uses the deterministic local planner, not a provider.

Evidence is in `ultra-selftest-2026-10-27.log`, `ultra-live-2026-10-27.log` and `ultra-native-2026-10-27.json`, with binary hashes. A Start UI call reported a ScreenCaptureKit error, but subsequent phase logs/AX state established the actual result. The state read after close reopened the same test bundle in its default mode; that extra window was quit without chat/account interaction. This tool side effect is not evidence of normal-host integration acceptance.

Accepted scope: one isolated native fixture action and completion, Stop after completion, close/quit cleanup. Still pending: normal-host selection/clipboard work in flight, Stop during an action, permission loss, lock/sleep/occlusion and broad repeated scenarios, full provider pilot, minimum OS/Intel/multidisplay and signed release. No valid Developer ID is available. The historic intermittent stdio timeout remains unresolved despite a passing 20-run focused stress check. All feasible completed checks are reported separately; this is not an all-phases-pass claim.
