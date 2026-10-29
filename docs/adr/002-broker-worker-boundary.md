# ADR 002: Broker authority and blocking platform workers

Date: 2026-10-29. Status: proposed; no production topology or worker isolation accepted.

## Problem demonstrated by the current code

`AccessibilityDesktop` and `ExecutionEngine` are MainActor-isolated. AX traversal checks a budget and uses a 0.05-second native messaging timeout, but synchronous platform calls do not yield the actor while blocked. The independently scheduled XPC control lane cannot guarantee prompt native Stop if its handler needs that same blocked actor. Existing real Stop-during-drag evidence covers asynchronous event delivery, not an unresponsive AX server.

`ScreenCapture.captureFixture` awaits framework enumeration and screenshot capture and checks `CaptureDeadline` around those calls. The ten-second admission deadline rejects late results; it does not forcibly interrupt a stalled framework operation. Moving a synchronous call into an unstructured Task alone would not provide process containment or prove cancellation.

## Proposed authority split

The visible companion remains the broker and sole authority for native approval, session scope, connection ownership, generation, action budget, durable intent/result journal and emergency Stop. It never waits synchronously for platform work on its control actor. A separate owned process performs bounded platform reads. No worker opens a session, grants approval, renews a lease, chooses policy or writes authoritative action receipts.

Implement read-only AX observation first. Capture follows only after its independent TCC attribution is measured. Do not move semantic mutation or CGEvent delivery into the worker in the first increment. Observation isolation alone cannot be advertised as complete action-path isolation: the existing preflight and mutation AX calls would remain a release limitation until separately migrated and accepted.

Workers are not model tools. Their transport is private, authenticated and bound to a single broker instance. Never publish a generic AX operation, arbitrary bundle selector, filesystem path, executable or script endpoint. Start with a single bounded fixture-observation request. The worker returns validated value snapshots, not serialized AXUIElement references.

## Request and reply contract to implement

Each request carries a broker-created request ID, connection/session ID, session generation, worker incarnation, fixed operation enum, explicit fixture process identity, window identity where known, monotonic remaining budget and traversal/resource limits. Only the broker derives those values from an admitted session. A worker cannot expand the allowlist or substitute its own target identity.

Each reply echoes the request identity and incarnation and contains bounded snapshots, measured collection duration, truncation reason and a classified failure. The broker checks every field, active ownership, generation, current target and elapsed budget before publishing a new observation. Public element IDs remain broker-issued and scoped; a worker reference is not a grant. A reply from a previous incarnation is discarded even if its request ID matches.

One in-flight read and one owned worker per broker is the initial limit. There is no unbounded queue or automatic retry. Timeout, cancellation or malformed response invalidates that incarnation and all its handles. Restart permits a new read only after a fresh broker admission; it never replays a mutation.

## Cancellation and effect accounting

| Boundary | Required broker behavior |
|---|---|
| Before worker dispatch | Check live connection, ready session, generation and budget |
| During blocked read | Accept Stop independently, revoke generation/handles, cancel pending continuation exactly once |
| Worker deadline expires | Return classified timeout, invalidate incarnation, terminate only the broker-owned worker |
| Worker replies after cancellation | Discard reply without publishing data or restoring readiness |
| Worker exits or connection drops | Drain pending work; keep session policy and journal authoritative in broker |
| Broker restarts | Invalidate all prior grants and worker references; require native approval again |
| Future mutation helper loses acknowledgement | Preserve unknown/applied effect information; reconcile before further mutation, never infer notApplied from transport loss |

Use an owned process handle and lifecycle identity for termination, not an unverified PID from a request or a process group. Bound termination escalation and reap the owned child. Keep cleanup evidence distinct from a release attempt. Initial read-only workers hold no mouse/key state; current native input cleanup remains the companion's responsibility.

## Registration and permission constraints

The production companion/service registration must use stable identifiers and mutual publisher validation. Existing development CDHash-pinned launchd probes provide development evidence only. Do not install a persistent service, replace a live session or choose a production Team ID automatically.

Before selecting an embedded service versus another signed owned-helper arrangement, measure Accessibility and Screen Recording in independently launched processes after install, update and permission revocation. Do not assume the companion's grant is inherited by a worker. A helper that lacks permission must fail closed; it cannot borrow a parent's trust or weaken checks. Developer ID credentials and clean-machine testing remain prerequisites for production acceptance.

## Implementation sequence and gates

1. Define internal bounded request/reply values and an injectable read-worker lifecycle. Add causal lifecycle tests for cancellation, late replies, incarnation fencing and single completion.
2. Add a test worker that deliberately stalls before returning known fixture metadata. Prove broker Stop remains responsive and the exact owned process is reaped. This is process-containment evidence, not native AX evidence.
3. Add read-only AX observation in the separate process with independent permission checks and retained traversal budgets. Native fixture observations must match independently observed target identity and expected values.
4. Revoke permission, terminate a target and stall a purpose-built AX fixture. Verify refusals, late-result fencing and control responsiveness with measured latency. Freeze a latency threshold before running the acceptance, not after observing it.
5. Add local capture only after permission attribution and resource bounds pass. Migrate blocking preflight/mutation paths separately, retaining per-action journal semantics and per-event admission.
6. Validate real publisher requirements and installed lifecycle on signed artifacts before marking H3 complete.

This document authorizes no production rollout. The first internal lifecycle increment is now tracked in [read-worker lifecycle](../read-worker-lifecycle.md); separate-process AX observation and production topology remain unimplemented/unaccepted. Example Host remains outside this workstream.
