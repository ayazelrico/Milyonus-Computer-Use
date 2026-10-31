# Remaining harness delivery plan

Date: 2026-10-28. Status: planning only; implementation requires actual gate evidence.

## Scope and ownership

This plan covers Milyonus Computer Use only. The user assigned Milyonus Agent Ultra to another agent. Do not read, edit, build, test, package or launch that checkout, or extend its host adapter, while that ownership remains in effect. Existing shared SDK contracts remain available; changing a public contract requires documenting compatibility without modifying the other checkout.

The last uncommitted Ultra preview-factory change was withdrawn after its exact postimage hash matched. The original preimage hash was restored. The corresponding uncommitted harness configuration helper/tests were removed. Historical accepted harness commits remain intact. The withdrawn experiment's 243-case result is not the current baseline; the accepted baseline is 241 cases / 2555 assertions.

No additional implementation is started by this plan. Commits are recovery checkpoints; they are not phase completion or renewed operator authorization.

## Accepted starting point

| Slice | Actual evidence | Boundary |
|---|---|---|
| Authenticated XPC and connection ownership | Real independent-process peer checks, nonce handshake, bounded requests/control lane and approved disconnect/reconnect | Development CDHash pins; production publisher identity is not accepted |
| Native text, click, scroll and drag | Four positive fixture routes independently verified | Explicit fixture/native startup and SDK opt-ins; no broader application support |
| Stop during drag | Receiver saw mouseDown, one motion and cleanup mouseUp; pending SDK action refused | Partial movement occurred; no rollback claim |
| Disconnect during drag | Same receiver-side cleanup pattern | Not a complete held-key/sleep/lock matrix |
| Fresh window closure | 0.802-second capture, TARGET_NOT_FOUND, ready session and unchanged generation | Fixture closes its own window through an explicit test hook |
| Focus loss | 0.167-second capture, FOCUS_CHANGED, ready session and unchanged generation | Fixture hides itself; no physical-input pause used to mask the cause |
| Provider pilots | One actual Anthropic and one actual OpenAI fixture task completed | Full repetition/task matrix remains open |
| Development packaging | Ad-hoc signatures, source-matched receipts and package guards | Not Developer ID signing, notarization or clean-machine release acceptance |

The detailed records are in STATUS.md and xpc-native-input.md. Historical permission grants are tied to recorded executable hashes; they are not permanent constants for future builds.

## Work order

| Order | Work package | Can start without foreground access? | Required input | Exit condition |
|---|---|---|---|---|
| H1 | Investigate intermittent stdio timeout | Yes | Existing failed logs and focused fixtures | Root cause reproduced and fixed with regression evidence, or explicitly unresolved after the bounded investigation |
| H2 | Finish supported native interruption slices | Preparation yes; native acceptance no | One agreed quiet window per applicable native session; actual native approval | Individual accepted records for remaining supported scenarios, without weakening guards |
| H3 | Establish production broker topology and worker boundaries | Design/preparation yes | Signing identity later; native permission/operator acceptance later | Stable authenticated lifecycle, owned cancellation and permission boundaries proven |
| H4 | Complete fixture capture acceptance | Preparation yes; live capture requires fixture access | Current companion capture grant; display coverage where available | Bounded correct fixture capture, identity/geometry checks and negative cases |
| H5 | Complete supported real-provider matrix | Contract preparation yes; live tasks need approved fixture sessions | Locally configured credentials/model and request/cost limits | Declared task/repetition matrix with independent completion and classified failures |
| H6 | Release and hardware acceptance | Preparation yes | Developer ID, notarization profile and missing OS/hardware access | Signed/notarized artifact and clean installation/update/uninstall plus declared platform coverage |

H1 and background preparation for H3/H4 can proceed independently. Do not make a non-reproducing legacy stdio issue block unrelated XPC acceptance. H2/H4 must precede claims that H5 covers native/capture behavior. H6 distribution acceptance depends on the applicable product gates, not merely a successful package build. Agent Ultra is a separate owner's workstream, not an executable step in this queue.

## H1 — Resolve the recorded stdio reliability defect

Problem: inherited-output, session/observation mismatch and closed-input tests have previously timed out unexpectedly. Later passes have not established a fix.

1. Preserve the original failures and record the exact source/binary used for reproduction.
2. Run the existing bounded focused inherited-output reproduction once per relevant build configuration, stopping at the first failure. Use the existing stage/counter diagnostics; retain deadlines.
3. Investigate the actual last stage: child startup, initialize handling, writer queue, received frames, reader completion and owned-child termination. Audit descriptor ownership, task cancellation and child lifecycle against that stage.
4. If reproduced, implement the smallest causal fix and a regression that fails before it. Verify pending continuations/timers drain, no action replay occurs and inherited descendants are not signaled.
5. If not reproduced within the bounded run, leave the defect unresolved, publish the observations and move to the next executable package. Do not add unrelated protocol validation or keep rerunning green stress loops.

Acceptance: documented cause and before/after evidence; appropriate Debug/Release checks. A passing stress run alone does not close H1.

## H2 — Complete the supported native interruption matrix

Prepare one explicit matrix before launching another GUI test. Each record states the event boundary, target identity, session generation, permission state, action/verification result and cleanup actually observed.

| Remaining scenario | Controlled trigger | Required evidence |
|---|---|---|
| Planning delay beyond the heartbeat lease | Quiet 18-second planning delay with automatic SDK heartbeat | Session remains ready, a newly observed target is used, task independently completes and session cancels |
| Physical input during delivered input | Operator input while the fixture receives the tested sequence | userInput pause, generation fencing, no continued unauthorized effects and applicable receiver cleanup |
| Sleep / screen lock during delivered input | Operator-controlled OS transition | Refusal after interruption, no late successful verification and cleanup state after wake/unlock; distinguish attempted from received release |
| Permission revocation during delivery | Only this companion's own permission switch | Effective permission transition and refused continuation; record concurrent physical-input pause instead of claiming a permission-only cause |
| Occlusion / target geometry change | Purpose-built fixture/window arrangement | Unchanged identity/geometry/hit-test rules reject the affected action; no unrelated window receives a test action |
| Key/text cleanup applicable to exposed primitives | Existing supported native text sequence | Evidence for its actual event boundaries; do not add general key-hold or arbitrary-key RPCs solely to fill a test table |

The two native planning-delay attempts remain failed; the diagnosed attempt paused for userInput. Their failure is not permission to disable physical-input protection. Schedule a genuinely quiet window for that acceptance and perform background work while the operator is unavailable.

If OS permission denial prevents observing a release, report that limitation. Never label an attempted release as receiver-confirmed cleanup. Keep native approval manual and scoped. Rebuilding ad-hoc code may require refreshing only this application's registration.

Exit: all scenarios declared applicable to the release have separate evidence, or an explicit unsupported/blocked classification. Mouse cleanup alone does not close the entire matrix.

## H3 — Production broker and blocking-call isolation

The current authenticated development route and native slices are implemented. Remaining work concerns deployability and containment.

1. Specify service registration, startup, shutdown and recovery, including refusing to replace an active user's session. Keep the development pin path visibly separate from the production publisher policy.
2. Validate real Developer ID peer requirements in both directions with the configured Team ID/signing identifiers. Preserve the nonce-only first exchange: a wrong server can receive the first request before its reply is rejected.
3. Prove grant ownership across disconnect, restart, late replies, idle connections and resource exhaustion. No transport or planner method may issue native approval.
4. Design the worker boundary for potentially blocking AX/capture calls before implementation. Demonstrate deadlines and termination of only owned workers while broker Stop stays responsive. Opaque references must remain scoped to connection/session/generation; native AX handles are not authorization tokens.
5. Re-test independent TCC attribution and grant/revoke after installation and update. Do not revoke unrelated applications to manufacture a pass.
6. Validate durable journal/recovery behavior for interrupted or uncertain effects and restart. Preserve applied/unknown effects and idempotency receipts; do not automatically replay mutations.

Background deliverables: topology decision, bounded protocol/lifecycle contract, failure table and development launcher plan. Production signing and native permission lifecycle acceptance remain dependent on their actual prerequisites.

## H4 — Capture and display coverage

Keep screenshot work local and fixture-only until image egress has its own explicit contract and authorization.

- Verify exact target-window identity before and after capture; refuse closed, replaced, moved or ambiguous targets.
- Verify crop, dimensions and bounded scaling against independent fixture geometry. Include negative origins, Retina scaling and mixed displays only on hardware actually exercised.
- Check permission denial/revocation, incomplete results, timeouts and resource limits without weakening identity or geometry checks.
- Confirm AX secure-field exclusion independently from image handling. Synthetic fixture content is the test material; unrelated user windows are not capture fixtures.
- Maintain separate records for compiled coordinate tests, actual fixture capture and hardware coverage. Do not turn a cross-build into a runtime pass.

Exit: accepted fixture capture cases and declared limitations, with no accidental provider upload. Additional application adapters require separate review and acceptance.

## H5 — Real-provider task/repetition matrix

First confirm which task types each existing proposal schema supports. Native gesture capability does not automatically mean a model planner can propose gestures.

Proposed five task families for the supported edit/press/finish boundary:

1. Empty fixture input to a requested value.
2. Existing input to a Unicode value with an independent exact-match check.
3. One fixture Save action with counter/value verification and no duplicate save.
4. Already-complete observation resulting in finish with zero mutation.
5. Interrupted task resulting in safe refusal/termination and no automatic replay.

After checking schema compatibility, freeze the exact task set and run the planned ten repetitions per family per provider, or record a smaller explicitly named pilot without claiming the full matrix. Group only within the existing five-minute session/action limits; renewal requires actual native approval. Do not extend leases or suppress operator-input checks for throughput.

Use credentials configured locally in the invoking process, not chat, repository files or companion environment. Fix model IDs and bounded request/token/cost limits before a paid batch. Record proposals/action kinds, completion booleans, usage and error categories without credentials or raw private values. Stop a batch on an unexpected or uncertain effect; diagnose before replaying anything.

Acceptance: declared denominator, actual successes/failures, independent completion, cancellation and classified refusal behavior. Provider contract tests and synthetic observations remain separate evidence.

## H6 — Distribution and platform gates

Prepare the release candidate and verification procedure before requesting any release action.

| Item | Preparation available now | Acceptance dependency |
|---|---|---|
| Stable signing identity | Requirements, bundle/service identifiers and minimal entitlement review | Installed valid Developer ID Application identity |
| Notarization | Reproducible archive, verification/stapling procedure and failure handling | Existing local notarization profile/account configuration |
| Install/update/uninstall | Source receipts, active-process refusal, staging and rollback checks | Actual signed artifact on clean target machine; verify grants after update |
| Development/test surface | Separate fixture/test hooks and development pins from claimed release support | Reviewed release configuration and actual negative tests |
| macOS 14 / Intel | Compile/compatibility preparation and explicit coverage checklist | Runtime access to those environments |
| Multi-display / scaling | Fixture geometry cases and bounded capture checks | Physical layouts actually tested |

Do not request private signing keys in chat. Do not mark distribution passed with an ad-hoc signature or mark hardware supported because compilation succeeds. Keep the currently advertised app/platform scope narrow until its gate passes.

## Operating rules and stop conditions

- General test authorization persists in operator-authorization.md. Do not ask for it again at each commit. Actual OS authentication and native session approval remain real operator steps.
- Background work never takes focus merely to keep a loop running. Prepare concrete acceptance first and use an agreed operator window for disruptive tests.
- Freeze scope after a causal fix and its required checks pass. Move to the next declared item rather than adding endless synthetic hardening.
- Update STATUS.md with actual evidence and limitations. Keep synthetic, native, provider, integration and distribution results distinct.
- Mark a package blocked only by its specific missing operator/input/hardware condition; continue other executable harness work. Do not change Agent Ultra to bypass a dependency.

## Immediate next executable sequence

1. Start H1's bounded source/evidence investigation; keep the historical defect open until causal evidence exists.
2. Prepare the remaining H2 cases and the H4 local capture checklist without launching GUI tests.
3. Draft H3's production registration/worker-boundary decision against the current implementation.
4. Run remaining native cases only when the required operator interaction is available.
5. Execute H5 and H6 when their documented prerequisites are present.

The Agent Ultra owner can consume the existing typed SDK and published compatibility notes independently. This harness plan neither changes that checkout nor assigns work to that agent.

## Execution checkpoint — 2026-10-29

H1 completed its bounded investigation without reproduction: Debug/Release each passed 20 inherited-output cases; the historical defect remains unresolved. H3's first internal lifecycle increment is implemented and verified in Debug/Release, 247 cases / 2603 assertions. This supersedes the current test count without rewriting the historical baseline above. See [read-worker lifecycle](read-worker-lifecycle.md).

Next executable H3 work: authenticated private transport and bounded owned-process startup/teardown, then actual fixture AX observation with independently measured worker permissions. No current native or production isolation gate is accepted by the injected lifecycle tests. H4's nine-case local capture matrix is prepared separately.

H3's next process-owner increment is also implemented: queued startup, sticky cancellation and owned SIGTERM/SIGKILL teardown, with actual cooperative/uncooperative child exit evidence. Current Debug/Release baseline is 249 cases / 2611 assertions. Helper authentication, wire framing, native AX/TCC and retiring-worker-slot admission remain required before companion integration. See `read-worker-lifecycle.md`.

H3's owned-channel/capacity increment is verified: signature plus selected-process admission, server-process checks, irreversible context revocation and a slot retained through actual child exit. Debug/Release each pass 252 cases / 2644 assertions; the five-case owned-peer matrix and existing 12-case named SDK regression pass independently. Next: the fixed bounded read-ticket/reply wire format and actual fixture AX collector with trusted startup and independently measured TCC. These transport results do not close native collection or production signing gates.

The next increment adds the fixed read wire and native collector component, with kernel process-start verification and conservative scope refusals. Current Debug/Release each pass 256 cases / 2674 assertions. No separate native helper or AX positive collection is accepted. The next engineering item is dedicated authenticated helper/broker integration, not expansion of the task/app surface; see `read-worker-collector.md`.

The runtime/companion increment now connects these components through a persistent selected-peer service and a same-executable child role. Default writable routes are unchanged; the opt-in worker route is read-only. Final Debug/Release counts are 258 / 2693. Three actual child refusal round trips pass; the corrected live run reaches awaiting native approval with broker AX=true but has not completed positive collection. Next is the prepared approved native run, then actual blocked-AX cancellation; do not claim H3 complete from the background results. Developer ID identity count is currently zero, and this invoking process has no provider configuration.

Native attempt -3 now accepts the separate-process read-only fixture slice: three fresh observations, secure-field exclusion, live broker permission, manual native approval, action refusal and cancellation. The corrected source-matched package and final 258/2693 Debug/Release checks are associated in `fixture-worker-runtime-acceptance-2026-10-29.json`. Next: prepare actual blocked-AX Stop and cleanup, then obtain the required operator window; do not broaden the writable path or claim full H3 completion.

### Blocked-AX checkpoint and next bounded acceptance — 2026-10-29

`e653120` adds actual fixture AX-stall evidence. One native attempt failed without subcondition measurements; the diagnostic attempt passed (0.577292 ms Stop acknowledgement, pending read cancelled, owned worker retired before broker unload). Runtime and acceptance thresholds were unchanged between attempts. Do not close the unexplained failure from the passing repeat.

The next operator batch is bounded, not an open-ended repeat loop: at most two diagnostic blocked-AX runs, stopping immediately on a failure. Preserve acknowledgement latency, AX entry/return relation, pending-read refusal, and worker PID/start retirement separately. If the failure recurs, fix its measured cause before another attempt. If it does not recur, retain the original as unresolved; do not manufacture a causal explanation.

Permission interruption follows that checkpoint. Establish an approved ready session and successful isolated observation first; record broker permission before and after changing only this companion's OS permission. Attempt a fresh read and require refusal. Record physical-input/environment interruption alongside permission state: if either also changed, classify the result as combined interruption, not permission-only acceptance. Restore the original permission through System Settings and measure it; never replace a runtime permission query with a test flag. Native approval and any OS authentication remain human steps. This protocol is prepared, not executed.

No new application targets, mutation capabilities, Agent Ultra work or provider calls are part of this batch. Stable Developer ID signing remains blocked on an actual identity; existing ad-hoc package validation does not satisfy that gate.

### Permission and capture checkpoint — 2026-10-29

The bounded two-run Stop repeat passed (attempts -3/-4); the unexplained first failure remains open, with no further repeat loop planned. Isolated new-read permission denial/restoration passed in attempt -2 after the first attempt timed out at OS authentication. Effective broker permission true→false→true, PERMISSION_REQUIRED refusal and unchanged ready generation were recorded. This does not demonstrate in-flight permission interruption or automatic session revocation.

H4 now has real no-window and ambiguous-window refusals and a local marker/decoded-dimension capture slice. Raw pixels stay in memory; the probe uses no provider. Strict RGB color equality failed and remains unaccepted; the documented marker identity rule tests dominant-channel ordering and spacing only. The next H4 implementation should add deterministic enumeration/capture/revalidation event hooks for C4/C5 before claiming native close/move timing. C6/C7, publisher/start identity and independent absolute marker mapping remain open; C9 needs actual hardware. Do not repeatedly rerun the accepted C2/C3 paths as a substitute for these remaining gates.

### Capture transition checkpoint — 2026-10-29

Actual movement and closure after framework image return now refuse publication with STALE_OBSERVATION. Actual-image cancellation and a ten-second delayed callback also refuse publication. The event boundary is explicitly after image completion; OS-call interruption is not claimed. Capture now pins kernel process-start identity, and marker/move/close native cases pass with that change. Publisher authentication remains open.

Next executable H4 work is independent marker-to-desktop mapping and resize coverage; capture-specific permission revocation and containment of a stalled framework call remain distinct gates. Additional hardware and stable signing still require real prerequisites. The gate table in capture-acceptance-plan.md supersedes the earlier statement that all C4/C5/C7 work is unexecuted, without declaring those categories fully complete.

### Process identity and resize follow-through — 2026-10-29

Capture now rechecks kernel process-start identity before acquisition and publication; native marker/move/close cases passed with this binding. The additional resize case passed with measured 620×412→700×472 dimensions and STALE_OBSERVATION. Cancellation/deadline records remain associated with their earlier source snapshot. This is still pre-publication admission, not OS-call preemption or publisher authentication.

ADR 002 has been reconciled with actual AX worker progress. The next capture-worker increment cannot reuse the AX wire for PNG bytes: its 262144-byte bound is below the capture limit of 8 MiB. First define an authenticated bounded frame transport and measure the independent role's capture permission; retain broker scope and publication ownership. This dependency is separate from independent marker-to-desktop mapping and the current single-display limits.

### Capture worker component implementation — 2026-10-29

The separate metadata role, bounded fixed metadata codec and exact-window/process-start collector are implemented. A real signed-role probe passed two non-fixture/changed-start refusals without reading pixels or creating a grant. Positive worker capture attribution is not established by those refusals. The next concrete integration is a typed capture reply lifecycle and broker-approved dispatch using the owned process slot; do not convert capture metadata into an AX Observation to reuse the existing controller. No public capture capability should be advertised before that integration and native approval/Stop/permission acceptance.
