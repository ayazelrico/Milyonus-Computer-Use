# Native interruption acceptance matrix

Updated: 2026-10-27. A passed row establishes only its stated timing and intervention, not the full G3 gate.

| Scenario | Timing / intervention | Current evidence |
|---|---|---|
| Stop with captured target | Manual approval, capture, physical-input pause, native Stop, then submit the captured request | Passed: `evidence/interruption-stop-2026-10-27-3.json`; cancellation, generation change, action and observation refusal |
| Physical input | Manual approval, capture, user clicks blank fixture area, then submit captured request | Passed: `evidence/interruption-user-input-2026-10-27-2.json`; userInput pause, generation invalidation and request refusal |
| Focus changed | Capture then activate another project-owned window; attempt admission | Not yet isolated from physical-input pause |
| Fixture closed | Capture then close only fixture; attempt admission | Pending |
| Stop during dispatched input | Stop after actual dispatch begins; inspect partial effect and input release | Pending; pre-dispatch refusal does not substitute for this case |
| Lock / sleep | Active approved session interrupted by OS lock/sleep and then user unlocks | Pending; requires an operator present to unlock |
| Permission revoke | Revoke only companion Accessibility in System Settings during an approved session, verify refusal, restore manually | Pending; never edit the TCC database |
| Normal external host selection in flight | Host clipboard/selection activity concurrent with start/Stop; preserve host preferences and data | Pending; isolated preview and headless tests do not substitute |

## Test driver

`scripts/interruption-acceptance.py MODE --evidence PATH` supports `stop`, `user-input`, `environment`, and `window-close`. It starts a dedicated companion, waits for manual native approval, captures only the fixture input target, and maintains the existing lease through heartbeats. After interruption it verifies the expected state/reason, generation invalidation, rejection of the captured write, and observation refusal. It never approves, resumes or retries a mutation. Evidence paths must be new; the script retains earlier failures.

For Stop, an intervening physical-input pause is recorded while waiting for native cancellation. It is not treated as a Stop success. For other modes the first non-ready state must match the scenario. The operation attempted after interruption must be refused; no test payload is supposed to be applied. The script cannot independently read the paused fixture through the harness, so refusal evidence must not be described as a post-interruption visual-value comparison.

The owned companion is cancelled during cleanup, then stdin is closed. If it remains running, only that owned process is terminated. A negative exit code after successful assertions reflects this cleanup and is retained; it is not graceful app-exit acceptance. No other running process is killed.

Initial Stop attempt 1 observed userInput before Stop and failed its expected-state check. Attempt 2 failed at RPC initialization while a UI-tool-reopened idle companion was still present. That idle test window was closed; attempt 3 passed. These results do not establish a fix for the separately tracked intermittent synthetic stdio timeouts.

Window-close attempt 1 rejected the captured request but did not record snapshot age, so expiry cannot be excluded. Attempt 2 explicitly failed because loss of foreground prevented refreshing the snapshot (age 78.2 seconds). Neither establishes fresh-target closure acceptance. The next run uses operator closure and records snapshot age; refreshing observations is read-only, throttled to one attempt per second, and cannot bypass focus checks.

Window-close attempt 3 ended with TARGET_NOT_FOUND before initial capture; this is not captured-target closure acceptance. A manual lock test is prepared separately. Normal keyboard/menu interaction can trigger userInput before an OS environment notification, so report the actual pause reason rather than attributing every refusal to lock handling.
