# Inherited-output timeout investigation

The first action-result validation run failed when `testReaderStopsWithInheritedOutputStillOpen` threw `TIMEOUT`. Its three assertions were not reached. The unchanged rerun and optimized Release suite passed. The original failed log remains in `evidence/selftest-result-validation-first-attempt.log`; its cause is not established.

A focused standalone-runner mode now invokes this exact test up to 20 times, stopping on the first failure and returning a nonzero exit code. It uses the original handshake timeout, marker wait, reader-shutdown wait and one-second shutdown assertion. It does not retry a failed iteration, launch the companion, activate a window or send native input.

```sh
swift run computer-use-selftest --stdio-inherited-output-stress
swift run -c release computer-use-selftest --stdio-inherited-output-stress
```

Only the synthetic inherited-output child writes bounded known-stage markers into its temporary test directory: child started, initialize received, initialize replied, initialized notification received, and stdout holder started. If connection fails, the test reports the last recognized stage, child liveness, queued/written byte counts, reader completion and pending/timer counts, then explicitly shuts down the client before rethrowing. Unknown marker contents are never printed. No message payload, credential, application window or user data is included.

The helper's three-second stdout-holding descendant remains outside the client's signal scope and expires naturally. Production transport timing, process ownership and protocol handling are unchanged. Instrumentation can affect scheduling; passing repeated tests narrows reproduction evidence but does not prove the earlier race or timeout is fixed. A future failure can distinguish child startup/handshake progress from reader/writer state without weakening the test.

## Broader fixture timeout diagnostics

A subsequent provider-response validation run timed out in two different existing stdio cases: session/observation mismatch handling and closed-input handling. That failed run is retained in `evidence/selftest-provider-response-first-attempt.log`. This broadens the unresolved finding; the inherited-output case is not established as the sole affected path.

Synthetic pipe children now record the same bounded known-stage markers for all fixture modes. A package-only optional timeout callback captures request ID, queued frame count, written bytes, received frame count, reader completion and child liveness before transport cleanup. The public SDK initializer installs no callback. The test factory emits only those counters, its known test mode and a recognized stage, never request/response contents or credentials.

The callback is emitted once per connection and does not change the ten-second request/frame deadlines, retries, process ownership or terminal shutdown. A deliberate unanswered-status test checks the captured handshake/request counters and confirms subsequent calls are rejected on the closed transport. This test waits for the existing real deadline; it does not shorten or bypass it.

`STDIO_TIMEOUT` alone does not indicate test failure: nonreading/backpressure and unanswered-request fixtures intentionally time out. Read the surrounding case result and final suite summary. Instrumented passing runs do not establish the root cause of the earlier unexpected timeouts, and stage-file I/O may affect scheduling. Native/provider acceptance remains separate.

## Bounded investigation — 2026-10-29

The existing exact inherited-output reproduction ran once in Debug and once in optimized Release: each completed 20 cases / 60 assertions / zero failures. See `evidence/stdio-bounded-investigation-2026-10-29.json` for source hashes and log references. No companion, GUI action or provider call was launched.

Source review confirmed that the pipe reader polls a nonblocking descriptor, checks cancellation between reads, and closes its handle in its own deferred cleanup. Shutdown cancels the reader independently of descendant EOF. The writer is actor-isolated, bounds queued frames, handles partial writes and closes rather than replaying a partially delivered frame. Request timers are removed with their continuations. These are code observations, not proof that every scheduling or process-startup path is correct. The historical failures do not contain a causal stage snapshot sufficient to select a fix.

Disposition: **unresolved, not reproduced in this bounded run**. No timeout relaxation, production change, mutation replay or new retry was introduced. The session/observation-mismatch and closed-input historical failures remain separate unresolved observations. Stop repeating green inherited-output loops; retain the existing diagnostics for the next actual unexpected failure and proceed with independent harness work.
