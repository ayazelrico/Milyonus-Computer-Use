# Bounded pointer gesture preparation

CU-018 now has an internal `PointerGesture` sequence builder and an opt-in native fixture. Experimental scroll and fixed fixture-drag SDK/MCP routes are described below. The basic two-action native fixture slice passed on 2026-10-27; full interruption acceptance remains open. Historical preparation notes below describe their state at implementation time.

## Construction guarantees

- Coordinates must be finite, within the executor's absolute 100,000-point bound, and inside a positive rectangular target region. Right and bottom edges are excluded.
- Drag paths interpolate linearly between distinct endpoints. All samples remain inside the target region. The final sample and release use the exact requested endpoint.
- Drag uses 1–120 segments and a 1–2,000 millisecond total delay, with at least one millisecond per segment and no individual delay above the executor's 1,000 millisecond limit.
- Scroll accepts nonzero signed pixel displacement, bounded to 2,000 pixels per axis. Events contain at most 100 pixels per axis and preserve both signed totals exactly, including remainders.
- The builder does not emit input. `InputSequenceExecutor` still authorizes each event, fences cancellation and attempts held-input release on failure.

Geometry is only a construction constraint. It does not prove visibility, foreground ownership, application identity, occlusion, or a valid session. Before exposing these sequences, the native execution layer must resolve a fresh observation, validate each path point against the current target, journal intent and completion, and independently verify the effect. Unknown effects must not be replayed.

## Opt-in fixture

The fixture executable accepts `--gesture-fixture`. Default launches retain the existing edit/save layout. The optional layout adds:

- `fixture.drag.canvas`: a synthetic canvas with down/drag/up handling.
- `fixture.drag.status`: completion count and local endpoint coordinates; releases outside the canvas or shorter than ten points are rejected.
- `fixture.scroll`: a real AppKit scroll view containing 30 synthetic rows with stable accessibility identifiers.

A release during cancellation can still produce a partial application effect. The canvas completion label is evidence of what the application received, not evidence that the harness approved or completed a request. No user content is involved.

The fixture was compiled but not launched in this increment. Its native rendering, accessibility tree, scroll positions and pointer behavior still need acceptance. Existing native edit/save evidence applies only to its recorded older binary, not this new optional layout.

## Next integration gate

The experimental vertical scroll route below implements bounded contracts, schemas, SDK calls, native preflight and directional postcondition verification. The fixed fixture drag route also has guarded integration; arbitrary drag paths remain unsupported. Test geometry changes, occlusion, physical input, Stop, permission loss and unknown effects in the optional fixture. Preserve session generation, journal and native approval requirements throughout. Do not broaden the fixture-only application allowlist.

## Experimental native scroll route

`desktop_scroll` and the optional `NativeScrollHarnessClient.scroll` SDK method now accept an `ActionRequest` with `kind: "scroll"` and nonzero `scrollPixels` between -2,000 and 2,000. Positive means up, negative means down. Text and caller coordinates are not accepted. The dedicated `Schemas/v1/scroll.schema.json` describes this tool's request. Existing press/setValue encodings remain unchanged when the new optional field is absent.

The companion advertises `experimentalNativeFixtureScroll`, separate from accepted semantic actions. The observed target must be the enabled `fixture.scroll` AX scroll area from the optional gesture fixture. Native preflight rejects a missing/non-numeric scrollbar value, a boundary in the requested direction, or a center hit whose bounded ancestor chain does not reach the exact target. Every input event rechecks session authorization, foreground/window identity, fresh target geometry, scrollbar identity and the hit-test ancestry.

Intent/completion use the existing execution claim and private action journal with the distinct `nativeScroll` fingerprint. Changed pixel deltas cannot reuse the same idempotency key. Semantic execution refuses scroll before creating an intent. Failure or unverifiable effects pause the session and are never automatically replayed.

Verification requires an independently observed vertical scrollbar value to move in the requested direction. This verifies directional movement, not an exact pixel distance: native scrolling and boundary clamping can alter the final displacement. No movement after dispatch is treated as unknown, not proof of no effect. The model planners still expose only edit/save actions; this experimental route is for explicit SDK clients.

Native implementation is compiled but not accepted on a live fixture. The actual AX enabled state, scrollbar exposure, ancestry hit tests and direction behavior need validation. An unsupported AX structure fails closed. General drag paths remain unsupported. The fixed fixture drag route is described below. No additional applications are supported.

### SDK request example

After a person approves a fixture session and the optional gesture fixture is foreground, use a fresh observation to locate the scroll capability:

```swift
let observation = try await client.observe(sessionID: session.id)
guard let target = observation.elements.first(where: {
    $0.identifier == "fixture.scroll" && $0.actions.contains(.scroll)
}) else { throw HarnessError.unsupportedCapability }
let request = ActionRequest(
    requestId: UUID().uuidString,
    sessionId: session.id,
    idempotencyKey: UUID().uuidString,
    observationId: observation.id,
    generation: session.generation,
    elementId: target.id,
    kind: .scroll,
    scrollPixels: -200
)
let result = try await client.scroll(request)
```

Here `client` is a connected `StdioHarnessClient`, and `session` is the current approved generation. Re-observe after a completed action. Do not blindly generate a new idempotency key after a timeout or unknown result. Native approval, heartbeat and physical-input safeguards are unchanged. Older clients that do not decode the scroll action are not compatible with observations from the optional gesture fixture; the ordinary edit/save fixture remains available.

## Experimental fixed fixture drag

`desktop_drag` and `NativeDragHarnessClient.drag` accept `kind: "drag"` with the existing session, generation, observation, element and idempotency identifiers. Text, scroll deltas, caller coordinates and duration overrides are forbidden. The dedicated `drag.schema.json` describes the wire request.

The route resolves only the enabled `fixture.drag.canvas` group. It sweeps from the horizontal quarter point to the three-quarter point at half height. Geometry must accommodate at least a 40 × 20 point canvas. The sequence contains 20 drag segments and 300 milliseconds of scheduled delay; authorization/hit-test work can add wall-clock time. Every point is inside the resolved rectangle. Preflight tests the complete sampled path before intent. Each dispatched event rechecks authorization, foreground/window identity, unchanged target geometry and an exact AX hit at that event's point. Drag does not use scroll's descendant hit-test rule.

The distinct `nativeDrag` journal method prevents cross-method replay. Unknown effects, interruptions and verification failures follow the existing engine's uncertain-effect policy. Cancellation releases held mouse input at the last attempted drag point. That cleanup can itself cause a partial application effect; no retry is attempted.

Success requires the fixture's independent status receipt to contain exactly one additional completion and both expected local endpoints, with a two-point rounding tolerance. A partial release, unchanged count, malformed receipt or wrong endpoint cannot establish success. The current fixture uses a centered horizontal path, so AppKit's local vertical axis does not change the expected midpoint.

The companion advertises `experimentalNativeFixtureDrag` separately from accepted semantic operations. Provider planners still only propose edit/save actions. Native gesture receipt delivery, occlusion, interruption and permission-loss acceptance remain pending. No native gesture run was performed in this increment.

SDK usage follows the scroll example, selecting `fixture.drag.canvas` with `.drag` in its actions and constructing `kind: .drag` without `scrollPixels`, then calling `client.drag(request)`.

## Deterministic SDK acceptance command

The `ComputerUseAcceptance` target contains a reusable runner with no provider dependency or native approval path. Given an already approved session, it checks that both gesture surfaces are available, scrolls toward the interior of the current range, observes a changed scrollbar value, performs the fixed drag using fresh handles, and independently verifies the completion counter and endpoints. PID, session generation, observation freshness and non-truncated observations are checked between actions. A failure stops the sequence; mutations are never retried.

The AX adapter exports finite normalized scrollbar values as strings in fixture observations so the client can verify movement after the native action result. It does not export secure-field values or broaden the application allowlist.

For a deliberately scheduled native test, start the packaged fixture with `--gesture-fixture`, then run:

```sh
.build/debug/milyonus-cu gesture-fixture-selftest "/absolute/path/to/MilyonusComputerUse.app/Contents/MacOS/MilyonusComputerUse" --allow-native-fixture-input
```

Use the checked-in packaging workflow before native testing. Do not replace a running executable. Exactly one fixture must already be running; the command does not start it or alter system permissions. Approve the session in the companion and leave the gesture fixture foreground. The command waits up to 120 seconds for approval, and performs only bounded read-only retries during initial activation.

The command emits a final JSON object on success or failure with UTC timestamps, companion and fixture executable SHA-256 hashes, fixture PID, status, and typed error or measured results. Failure exits nonzero. `nativeAcceptance: true` requires both independently verified gestures and successful session cancellation. Connection shutdown runs after either outcome. If the process is externally killed, there may be no final object; that absence is not a pass. Capture a new output file for each run rather than reusing old passing evidence.

This command has been compiled and its runner tested with synthetic clients. It has not been run against a live fixture in this increment. Its eventual success would establish only the two-action fixture slice, not the full interruption/hardware/release matrix.

### Geometry and negative acceptance cases

The independent runner now requires the expected AX role for each gesture target and valid initial scroll geometry. After scrolling it resolves the scroll target again and requires unchanged bounds before accepting scrollbar movement. This prevents a replaced/resized fixture surface from supplying misleading completion evidence. Final drag geometry must still match its pre-action observation.

Synthetic cases cover upward movement toward the interior, wrong-direction movement, missing/ambiguous/non-finite scrollbar values, incorrect target roles and geometry changes after scroll or drag. These are acceptance-runner checks, not live native interruption evidence.

## First live acceptance finding (2026-10-27)

The approved run failed with `UNSUPPORTED_CAPABILITY`. A read-only fixture AX probe identified a missing `AXEnabled` attribute on the standard scroll view. The optional fixture now sets accessibility enabled explicitly, while the harness retains its fail-closed check. The Debug regression suite passed and the development bundles were rebuilt. A new live run is required to accept this fix; the first failure and binary hashes are retained in `evidence/native-gestures-2026-10-27-attempt-1.json`.

## Second live acceptance passed (2026-10-27)

After the fixture enabled-state fix, the approved two-action SDK command passed with independent verification: scrollbar 1 → 0.7214484679665738; drag count 0 → 1 with verified endpoints. Session cancellation succeeded. See `evidence/native-gestures-2026-10-27-attempt-2.json` for exact executable hashes and times. This is actual native fixture evidence, not synthetic or provider evidence. General applications and the full interruption matrix remain unaccepted.
