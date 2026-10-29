# Local fixture capture acceptance plan

Date: 2026-10-29. Status: prepared; native cases below have not been run by this update.

## Existing implementation and boundary

`ScreenCapture.captureFixture` selects the sole main fixture window, bounds geometry, captures without cursor/audio, re-enumerates windows and validates the original metadata before returning PNG data. Current limits are 2048 pixels per dimension, 8 MiB encoded PNG and a ten-second monotonic admission deadline. These bounds do not guarantee interruption of a stalled framework call; see ADR 002.

Selection currently matches bundle ID, exact main-window title and layer, then requires a positive PID and nonzero window ID. Revalidation compares PID/window/bundle/title/layer/bounds. Capture now additionally pins kernel process-start identity before acquisition and rechecks it before capture and publication; publisher authentication remains open. Capture alone is not authorization for coordinate input. Do not expose new app support or provider image egress on the strength of this acceptance.

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

## Native local probe results — 2026-10-29

A standalone local probe now exercises the actual ScreenCapture implementation, with opt-in fixture marker and duplicate-window modes. Preparation compiles the probe without launching windows. No capture permission prompt is generated, no network request is made, and PNG data remains in memory. A native inventory wait requires visible positive-size fixture windows before positive/ambiguous cases; production target and post-capture revalidation are unchanged.

- C2 passed: no fixture yields TARGET_NOT_FOUND without a frame.
- C3 passed: two eligible windows yield TARGET_AMBIGUOUS without choosing the first.
- C1/C8 partial positive evidence: decoded PNG dimensions 1240×824 for 620×412-point bounds, adjacent RGB marker verified locally, no disk frame/provider upload, owned fixture removed. This does not establish publisher/start identity, independent absolute marker coordinates, installed companion attribution or all retention paths.

Early positive runs observed startup TARGET_NOT_FOUND, zero-size INVALID_REQUEST, one STALE_OBSERVATION and strict-color VERIFICATION_FAILED. Those records remain retained. The marker visibly rendered; captured color samples differed from pure source RGB. Capture now explicitly requests sRGB. This did not eliminate all channel differences, so the marker identity rule explicitly tests dominant channel >0.8 with >0.4 separation at three adjacent 3×3 patches separated by the expected scaled width. This is a changed test criterion for marker identity, not a color-fidelity pass; `colorFidelityAccepted` is false. No production identity, permission or geometry safeguard was relaxed. The display-profile/color-fidelity question remains open.

Evidence: `capture-absent-native-2026-10-29.json`, `capture-marker-native-2026-10-29-7.json`, `capture-ambiguous-native-2026-10-29.json`. Actual in-flight close/move/permission/cancellation C4–C7 and additional-display C9 remain open. No claim that the full H4 gate is complete.

## Actual pre-publication transition checks — 2026-10-29

The public capture API still has no callback parameter. A package-only acceptance overload provides a rendezvous after the actual ScreenCaptureKit image returns and before final enumeration/validation. The callback receives PID, window ID and bounds only, never image pixels or native handles. Deadline/cancellation and effective permission are checked again after it returns. It cannot waive selection, revalidation or publication checks; no companion RPC exposes the callback.

The probe verifies that the selected fixture PID is a sibling owned by its runner, including kernel start identity immediately before signalling. The fixture's explicit move hook changes only its own origin by 80/40 points; the existing close hook closes only its own window. Real ScreenCaptureKit inventory observes the transition before the callback returns. Both cases passed with STALE_OBSERVATION and no published frame. Monotonic timestamps establish image-return → observed transition → refusal. Evidence: `capture-move-native-2026-10-29.json` and `capture-close-native-2026-10-29.json`.

These are actual-window changes while the overall capture method is pending, specifically after framework image completion. They do not prove changes occurred while the OS was producing pixels. No forced interruption of a blocked framework call is claimed. Inventory diagnostics now include fixture-only PID and x/y coordinates to distinguish actual movement from a synthetic metadata change.

The same rendezvous supports a caller-task cancellation and a ten-second delayed return exceeding the unchanged capture deadline. These checks test result admission after a real image, not preemption of the framework. Capture permission interruption and additional physical displays remain separate gates.

## Current gate accounting

| Gate | Actual evidence | Remaining limit |
|---|---|---|
| C1 | Local marker, decoded dimensions and process-start binding | Absolute marker-to-desktop mapping and publisher authentication not accepted |
| C2 | No-window refusal | Accepted only for recorded development process attribution |
| C3 | Two-window refusal | Accepted only for recorded development process attribution |
| C4 | Actual close after image return, before publication, refused | OS image-generation interruption itself is not established |
| C5 | Actual move and resize after image return, before publication, refused | Movement/resize during OS image generation remain untested |
| C6 | Not run for capture | AX permission tests do not substitute for Screen Recording revocation |
| C7 | Actual image then caller cancellation/deadline, no publication | Framework preemption and stalled capture-worker containment remain open |
| C8 | Probe keeps PNG in memory, no provider/disk output | Does not validate every consuming application or journal path |
| C9 | One current host/display configuration | Additional physical displays and supported OS/hardware matrix remain open |

`summarize-capture-evidence.py` validates selected evidence status, refusal, cleanup and monotonic event ordering. It reports each source/fixture hash separately and does not convert historical records into current-build passes. The seven-case audit in `capture-evidence-audit-2026-10-29.json` is evidence bookkeeping, not a new native test run.

The explicit fixture resize hook also passed the same pre-publication boundary: the same PID/window changed from 620×412 to 700×472 points, then capture returned STALE_OBSERVATION without publishing a frame. `capture-resize-native-2026-10-29.json` records image/transition/refusal times; the dedicated evidence audit checks both width and height changes and unchanged target identity. The public fixture default and capture API are unchanged by this hook.
