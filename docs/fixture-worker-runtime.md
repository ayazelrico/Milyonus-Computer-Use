# Fixture worker runtime and companion integration

Date: 2026-10-29. Experimental development route; production topology and full hostile-application isolation remain open.

## Running role and trust

ComputerUseWorker connects the lifecycle controller, process owner, fixed read wire and native collector. The packaged companion has a `--fixture-read-worker-v1 <service> <parent-pid>` child role. It exits before constructing the companion session controller, writer lock, journal, native controls or event monitors. It creates no native approval and posts no input.

The child requires its actual parent PID and a signature requirement derived from its own executable's CodeDirectory hash. A command-line argument cannot select a trusted broker hash. The parent also uses its own executable as the only helper locator; no RPC provides a path. This development design uses two instances of the same signed executable, not a separate published helper identity. Exact version pins are not a stable Developer ID update policy.

The initial exchange is the existing public nonce. A bounded bootstrap retry can repeat only that public handshake while the parent publishes the selected child PID. No read ticket, observation, mutation or result is replayed. Parent identity is checked again before requesting work, collecting and submitting the result. An independent 20-second child watchdog bounds orphan lifetime even if the collector blocks its actor; the broker's shorter read deadline and owned termination remain authoritative.

## Persistent service, one child per read

The experimental broker requires two explicitly registered Mach services on the same launchd job:

```
MilyonusComputerUse --broker-development <agent-service> <client-cdhash> --isolated-fixture-reads <worker-service>
```

The worker service name must differ from the agent service. The new mode cannot be combined with the fixture-action/native-input startup flags. Neither service is chosen by an agent request.

FixtureWorkerHost keeps one worker listener across reads. WorkerSelection snapshots a specific OwnedReadWorkerProcess at connection acceptance. BrokerOwnedPeer's liveness closure captures that exact owner, so selecting another child cannot revive an old connection even if a PID is reused. Removing a completed connection does not invalidate the persistent service. The process slot remains occupied until the old child actually exits.

Each transport admits one `fixture-read-next-v1`, sends one fixed ticket, then accepts one correlated result from that same connection. The child has no control handler. Stop withdraws child eligibility immediately, revokes its connection, cancels pending work and starts owned termination. A child that exits before its first request is detected by a bounded asynchronous watcher. No timer or AX wait blocks the broker actor.

The broker can stop the role as soon as it accepts a result, so the child is not guaranteed to receive its final acknowledgement or exit normally. Losing that acknowledgement is never permission to retry. Evidence distinguishes process exit from success of a UI read.

## Native broker authority

The agent-facing observation route requires actual connection ownership and a real ready session. It preserves the broker's Accessibility check and verifies the selected fixture PID/start identity, active application, session generation and live owner before dispatch and after collection. The child separately queries its own effective Accessibility trust. A false check is refused, never replaced with a remembered grant.

Pause, Stop, physical input, environment interruption, ownership disconnect and watchdog generation changes cancel the read and invalidate targets. Human approval remains the existing native control. No worker or agent RPC can manufacture it.

This mode advertises no supported mutation actions and disables native input capabilities. All action routes are refused before execution. Returned observation/element IDs are newly minted by the broker and never installed in the mutation target table. Integrating worker handles with mutating actions is a separate task with its own identity/re-resolution gate; read-only IDs are not authorization tokens.

XPCSessionClient now has an explicit `allowFixtureObservation` opt-in. Its default remains false; existing action/native opt-ins keep their behavior. Observation-only configuration expects the read-only capability set and cannot call mutations. Capability validation was not relaxed to hide a mismatch.

## Evidence and discovered failures

The standalone runtime probe starts the actual self-pinned child role three times through a persistent service. Its target is hardcoded to its own non-fixture process. Non-fixture scope, changed kernel start identity and unsupported explicit-window scope each return their exact collector error through the real wire. Every child exit and temporary job removal are recorded. These cases perform no AX traversal and create no native session.

Debug/Release standalone suites passed 257 cases / 2679 assertions after initial runtime integration. Adding the observation-only SDK regression produced 258 cases / 2693 assertions in the final Debug and optimized Release runs. The existing 12-case named SDK and five-case selected-peer matrices passed after the persistent-binding listener change. Packaging failure/recovery guards also passed.

The first acceptance-client preparation failed compilation because cancel returns Void; the corrected client relies on the SDK's validated cancellation acknowledgement and checks subsequent local ownership refusal. The first native attempt then failed before session opening with PROTOCOL_MISMATCH: the client requested action capability while the new route correctly advertised none. The explicit observation-only SDK configuration fixes that mismatch without broadening actions. The failed records remain preserved.

After that native attempt had already shut down, selecting the app through UI automation opened an ordinary idle companion. It had no pending session and could not accept native approval. That idle window was closed. Only this companion's old Accessibility registration was removed and re-added for the exact current bundle through System Settings after the operator completed Touch ID. Other applications' switches were untouched. A real running companion then reported Accessibility granted; subsequent native acceptance still must measure the independent broker/child path.

## Native acceptance procedure

`isolated-fixture-read.py --approval --prepare-only --evidence <new-path.json>` verifies the package receipt and compiles/signs the client without launching native apps. The real `--approval` run opens only the project's fixture and companion and waits for the actual native click. A progress sidecar identifies the real awaiting-approval stage and the broker's measured Accessibility result, avoiding an approval request after a client has already failed.

The approved test requires three fresh complete snapshots of the runner-owned fixture PID, distinct broker observation IDs, a stable ready session/generation, and exclusion of the fixture's synthetic secure field/value. It also checks the server's mutation-route refusal, SDK mutation refusal and cancellation. It enters no text, captures no other windows, uploads nothing and automates no native approval. Native results are separate evidence, not inferred from preparation or kernel-only tests.

The first corrected native attempt reached a real awaiting-approval session with broker Accessibility=true. Unapproved read and server mutation-route refusal both passed; no ready transition was observed before the 120-second operator wait expired. It ended as TIMEOUT, cancelled ownership and removed its job/fixture. This is not a native collection pass.

Native attempt -3 passed through the packaged companion and separate child role: three fresh complete fixture snapshots, distinct broker IDs, unchanged ready generation, secure-field exclusion, server/SDK action refusal and acknowledged session cancellation. Broker Accessibility was measured true. The exact companion/fixture hashes and manual-approval boundary are in `evidence/isolated-read-native-2026-10-29-3.json`. This accepts the read-only native slice, not the complete H3 gate.

Remaining gates include blocked-AX Stop and permission interruption, stable signed install/update attribution, broader window binding and isolation of the existing mutation/preflight paths. Current production support remains unchanged.

## Blocked AX Stop acceptance preparation

The fixture has an explicit `--ax-stall-on-signal` test mode. Its runner-owned PID is armed once with SIGUSR1 after three successful worker observations. The next text-field accessibility-value read records entry and blocks only the fixture AX server for five seconds. Default fixture behavior is unchanged. Four fixed event records contain only PID and monotonic time; the trace requires a private immediate temporary directory and an exclusively created, non-symlink 0600 file. No UI values are recorded.

`isolated-fixture-read.py --ax-stall-stop --prepare-only --evidence <new-path.json>` compiles and signs the acceptance client without opening windows. Without `--prepare-only`, actual native approval is still required. The client waits for recorded AX entry before sending Stop, requires acknowledgement below 250 ms before the AX call returns, requires cancellation of the pending SDK read, and verifies the exact worker PID/start identity has exited within two seconds before unloading the broker. Process enumeration is read-only; the only test signal goes to the runner's own identity-checked fixture. Existing foreground and physical-input checks remain enabled. File-admission and compilation results do not establish native blocked-call acceptance.

The first actual blocked-AX run failed at Stop verification without sufficient subcondition diagnostics. The second, with diagnostic-only changes, passed at 0.577292 ms and verified cancelled read plus owned worker exit before broker unload. Both records are retained. This is positive native evidence with an unresolved earlier failure, not a proven fix for that failure or a repeated-run reliability result.

## Permission interruption procedure

`isolated-fixture-read.py --permission-revoke --prepare-only --evidence <new-path.json>` validates preparation without native windows. The actual run first requires operator session approval and three complete isolated observations. It then waits up to 120 seconds for the independently launched broker's effective Accessibility permission to become false. A new observation must return PERMISSION_REQUIRED or PERMISSION_REVOKED. Session state, generation and pause reason are recorded; a concurrent physical-input/environment pause is explicitly classified as combined interruption. The client waits for measured restoration before cancelling. Neither the script nor SDK toggles OS permissions, enters credentials, creates approval or resumes a paused session. UI switch appearance alone is not effective-permission evidence.
