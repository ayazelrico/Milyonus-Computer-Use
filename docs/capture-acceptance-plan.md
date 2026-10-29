# Local fixture capture acceptance plan

Date: 2026-10-29. Status: prepared; native cases below have not been run by this update.

## Existing implementation and boundary

`ScreenCapture.captureFixture` selects the sole main fixture window, bounds geometry, captures without cursor/audio, re-enumerates windows and validates the original metadata before returning PNG data. Current limits are 2048 pixels per dimension, 8 MiB encoded PNG and a ten-second monotonic admission deadline. These bounds do not guarantee interruption of a stalled framework call; see ADR 002.

Selection currently matches bundle ID, exact main-window title and layer, then requires a positive PID and nonzero window ID. Revalidation compares PID/window/bundle/title/layer/bounds. This metadata does not authenticate a publisher or uniquely establish process-start identity. Capture alone is not authorization for coordinate input. Do not expose new app support or provider image egress on the strength of this acceptance.

## Fixed matrix

| ID | Controlled fixture case | Required independent evidence |
|---|---|---|
| C1 | One stationary main fixture window | Exact fixture PID/window, known rendered marker, expected bounds, PNG decoded dimensions and transform |
| C2 | No fixture window | Refusal; no frame artifact |
| C3 | Two eligible fixture windows | Ambiguous-target refusal; no first-window selection |
| C4 | Fixture closes while capture is pending | Late frame refused; no publication |
| C5 | Fixture moves or resizes between enumeration and revalidation | Stale observation refused; no old transform published |
| C6 | Only companion capture permission revoked | Effective grant before/after and refused capture; distinguish permission transition from other interruptions |
| C7 | Framework result completes after deadline or caller cancellation | No late publication; report worker containment separately |
| C8 | Allowed local frame handling | No network upload, no raw frame in journal, bounded in-memory output and explicit artifact retention |
| C9 | Additional display/scaling configurations | Actual layout, pixel/point mapping and independent marker coordinates; unsupported hardware remains untested |

C3–C7 require deterministic fixture/driver hooks or operator transitions before native execution. Synthetic selection/deadline cases do not substitute for these native cases. Do not claim an event happened during capture unless timestamps establish that boundary.

## Execution procedure

1. Record source commit, package receipt, executable hashes, OS/architecture, effective capture permission and actual display layout. Verify no conflicting companion session.
2. Use only this project's fixture. The operator's other windows and credentials are not test content. If capture scope cannot exclude them, stop that case.
3. Freeze expected geometry/markers and test trigger before starting. Read and compare the returned PNG locally; model self-report is not verification.
4. Keep each case result separate: passed, failed, blocked or not run. Record target identity, times, transform, permission state, observed error and whether any frame escaped admission.
5. Remove owned temporary artifacts/processes. Never close unrelated windows or reset other applications' permissions.

No GUI session is launched by this document. The next background implementation is a deterministic capture-driver boundary for admission checks; native permission, OS framework timing and physical display coverage still need actual acceptance.
