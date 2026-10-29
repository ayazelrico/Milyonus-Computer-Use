# Read-only worker lifecycle foundation

Date: 2026-10-29. Implementation scope: internal controller and injectable transport only.

## What changed

`ComputerUseCore/ReadWorkerController.swift` provides one in-flight, fixture-only read. A broker caller supplies an independently established target PID/start time, optional window ID, connection ID and ready-session snapshot. These values do not grant native authority: a throwing admission closure must re-check live connection ownership, actual session/generation, target identity, permissions and scope against authoritative state.

The controller generates request and incarnation UUIDs, applies a monotonic budget capped at ten seconds, validates returned observation structure and exact envelope/target association, and stops the transport on every terminal path. It rejects concurrent reads rather than queueing them. It never dispatches a mutation, renews a lease, approves a session, writes an action journal or installs worker-supplied element handles in the native target table.

Cancellation is scoped to the active request and remains latched until the asynchronous call returns. This includes the interval after a reply has fulfilled its continuation but before the awaiting caller resumes. Final admission is repeated after that suspension; an earlier successful reply cannot preserve authorization that has since been revoked. A delayed cancellation callback from an old request cannot cancel a replacement. Teardown clears pending ownership before invoking transport stop, so synchronous exit callbacks cannot double-resume a continuation.

## Evidence and distinction

The standalone tests cover wrong connection/request/incarnation/generation/process-start identity, malformed snapshots, revoked admission, reentrant cancellation, timeout, task cancellation, concurrent reads, late callbacks and replacement fencing. A test-only transport launches its own `/bin/sleep 30` child and deliberately supplies no reply. While the child is alive, controller cancellation must acknowledge within 250 ms; that exact owned child must exit on SIGTERM within two seconds. Those thresholds were fixed in the test before execution. No process group is signaled and no GUI is used.

This is a real owned-child cancellation check around an injected stalled read. It is **not** an AX server stall, production broker Stop, authenticated helper transport, worker permission attribution or complete hostile-application containment. The test driver is deliberately not a production launcher.

Current native actions and synchronous AX observation are unchanged. The new controller is package-scoped and is not wired into the companion. Existing native acceptance remains associated with its recorded binaries; the new build is not automatically native-accepted or packaged.

## Verification

Debug build and standalone suite passed 247 cases / 2603 assertions / zero failures. The optimized Release suite passed the same counts. [Evidence manifest](evidence/read-worker-lifecycle-2026-10-29.json) associates the source hashes, logs and fixed owned-child thresholds. No full native or production worker gate is claimed.

## Remaining implementation boundary

Before using this controller for platform reads:

1. Supply a bounded, authenticated private transport and an owned-process launcher with bounded termination escalation/reaping. A transport factory/start/stop must not block the broker actor. A trusted launcher must derive identity; the current target value initializer does not query or authenticate a process.
2. Define a versioned bounded wire representation. Current Sendable value types are internal lifecycle objects, not a supported encoded protocol. Validate frame size, duplicates/depth, result timing, traversal bounds and peer identity before constructing a reply.
3. Implement read-only fixture AX collection in the separate process, independently check its actual TCC trust, and mint broker-owned observation/element handles on admission. Retain exact process/window re-resolution at mutation time.
4. Connect Stop/disconnect/revocation and ready-session checks to this controller without moving core authority to the worker. Measure native broker responsiveness against a deliberately stalled AX fixture.
5. Migrate remaining blocking preflight/mutation paths separately; read isolation alone cannot establish full action-path containment.

See [ADR 002](adr/002-broker-worker-boundary.md). No production isolation or permission gate is closed by this foundation.
