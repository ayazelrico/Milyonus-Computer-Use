# Read-only worker lifecycle foundation

Date: 2026-10-29. Implementation scope: internal controller, injectable transport and direct-child process owner; no native worker integration.

## What changed

`ComputerUseCore/ReadWorkerController.swift` provides one in-flight, fixture-only read. A broker caller supplies an independently established target PID/start time, optional window ID, connection ID and ready-session snapshot. These values do not grant native authority: a throwing admission closure must re-check live connection ownership, actual session/generation, target identity, permissions and scope against authoritative state.

The controller generates request and incarnation UUIDs, applies a monotonic budget capped at ten seconds, validates returned observation structure and exact envelope/target association, and stops the transport on every terminal path. It rejects concurrent reads rather than queueing them. It never dispatches a mutation, renews a lease, approves a session, writes an action journal or installs worker-supplied element handles in the native target table.

Cancellation is scoped to the active request and remains latched until the asynchronous call returns. This includes the interval after a reply has fulfilled its continuation but before the awaiting caller resumes. Final admission is repeated after that suspension; an earlier successful reply cannot preserve authorization that has since been revoked. A delayed cancellation callback from an old request cannot cancel a replacement. Teardown clears pending ownership before invoking transport stop, so synchronous exit callbacks cannot double-resume a continuation.

## Evidence and distinction

The standalone tests cover wrong connection/request/incarnation/generation/process-start identity, malformed snapshots, revoked admission, reentrant cancellation, timeout, task cancellation, concurrent reads, late callbacks and replacement fencing. A test-only transport launches its own `/bin/sleep 30` child and deliberately supplies no reply. While the child is alive, controller cancellation must acknowledge within 250 ms; that exact owned child must exit on SIGTERM within two seconds. Those thresholds were fixed in the test before execution. No process group is signaled and no GUI is used.

This is a real owned-child cancellation check around an injected stalled read. It is **not** an AX server stall, production broker Stop, authenticated helper transport, worker permission attribution or complete hostile-application containment. The initial checkpoint used a test-local child owner. The subsequent process-owner increment replaces that ownership code with the reusable internal supervisor described below; the injected read transport still is not a production launcher.

Current native actions and synchronous AX observation are unchanged. The new controller is package-scoped and is not wired into the companion. Existing native acceptance remains associated with its recorded binaries; the new build is not automatically native-accepted or packaged.

## Verification

Debug build and standalone suite passed 247 cases / 2603 assertions / zero failures. The optimized Release suite passed the same counts. [Evidence manifest](evidence/read-worker-lifecycle-2026-10-29.json) associates the source hashes, logs and fixed owned-child thresholds. No full native or production worker gate is claimed.

## Owned-process implementation increment

`OwnedReadWorkerProcess` now runs spawn/termination on a dedicated utility queue, keeping process operations off the broker actor. Its locked snapshot carries only idle/launching/running/exit/failure state. Stop is sticky across queued startup and cannot restart the same owner; cancellation during launch requests teardown. A minimal PATH-only environment and null standard streams prevent inherited provider credentials or incidental output. It never accepts an external PID or process group.

Termination sends SIGTERM to the directly owned live Process, then checks that same object after a configurable positive grace capped at one second and sends SIGKILL if it remains running. Exit status and signal-versus-normal-exit are recorded by its termination callback. The object begins teardown when released. The authenticated read transport and trusted packaged-helper locator remain separate work; this class does not authenticate an executable merely because it is executable.

The additional selftest child installs SIGTERM ignore, writes a readiness marker in a private temporary test directory and then stalls. Only after the marker exists does the test stop its exact process owner. The test requires a signal-terminated SIGKILL exit within two seconds with a 75 ms grace, exercising actual escalation rather than guessing whether the child had configured its signal handler. The marker mode exists only in the standalone selftest executable, not the companion.

Limits: a kernel/framework stall inside Process.run is not forcibly preempted by this queue. Stop latches immediately, but termination follows launch completion. The enclosing controller's independent read deadline does not prove the OS spawn has returned. A future broker transport must retain the retiring launch/worker slot until actual exit (or classify it as unresolved) and refuse another worker, rather than permitting overlap while teardown is pending. Neither the process owner nor injected tests establish native AX isolation or independent worker TCC trust.

The process-owner increment passed Debug build/selftests and optimized Release selftests: 249 cases / 2611 assertions / zero failures each. [Process evidence](evidence/owned-worker-process-2026-10-29.json) records the exact source hashes, logs and signal expectations. The earlier 247-case checkpoint remains historical evidence.

## Remaining implementation boundary

Before using this controller for platform reads:

1. Supply a bounded, authenticated private transport and a trusted packaged-helper locator around the implemented process owner. Use the implemented ReadWorkerProcessSlot to retain capacity until exit. A transport factory/start/stop must not block the broker actor. A trusted launcher must derive identity; the current target value initializer does not query or authenticate a process.
2. Define a versioned bounded wire representation. Current Sendable value types are internal lifecycle objects, not a supported encoded protocol. Validate frame size, duplicates/depth, result timing, traversal bounds and peer identity before constructing a reply.
3. Implement read-only fixture AX collection in the separate process, independently check its actual TCC trust, and mint broker-owned observation/element handles on admission. Retain exact process/window re-resolution at mutation time.
4. Connect Stop/disconnect/revocation and ready-session checks to this controller without moving core authority to the worker. Measure native broker responsiveness against a deliberately stalled AX fixture.
5. Migrate remaining blocking preflight/mutation paths separately; read isolation alone cannot establish full action-path containment.

See [ADR 002](adr/002-broker-worker-boundary.md). No production isolation or permission gate is closed by this foundation.

## Owned-channel and capacity increment

The internal [owned worker channel](owned-worker-channel.md) now combines signature requirements with live selected-process binding on the listener and server-process checks on the client. Ownership failure irreversibly revokes the context. Stop removes authentication eligibility immediately. ReadWorkerProcessSlot blocks replacement while the old process is still retiring; actual SIGTERM-ignoring child cleanup and replacement admission passed. Current Debug/Release suites each pass 252 cases / 2644 assertions. Native AX collection, wire framing, TCC and companion integration remain open.
