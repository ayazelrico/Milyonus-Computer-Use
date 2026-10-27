# Bounded capture geometry

`CaptureGeometry` computes single-window raster dimensions using one uniform scale, capped at two pixels per point and 2,048 pixels on the longest edge. Each dimension rounds upward to a pixel with a minimum of one. This preserves aspect ratio to within one-pixel rounding instead of independently clamping width and height. Pixel conversion happens only after finite bounded values are established, avoiding invalid floating-point-to-Int traps.

`Rect.isValid` now also requires finite, representable upper edges. Positive dimensions whose addition overflows or rounds back to the origin are rejected. Pixel-to-desktop conversion normalizes the pixel fraction before multiplying by the desktop extent, avoiding intermediate overflow for otherwise valid finite geometry. A resulting point must remain inside the rectangle.

The native capture adapter uses these dimensions, checks returned image bounds before PNG encoding, rechecks cancellation after asynchronous operations, and rechecks capture permission after the screenshot and after window re-enumeration. It refuses a frame if the original fixture window ID, owning PID, bundle, title/layer or rectangle cannot be matched after capture. This prevents a detected resize/replacement from returning an old transform.

Frames remain memory-only with the existing 8 MiB encoded-PNG cap. No image egress or new application scope is enabled. A post-capture snapshot does not detect every transient change-and-revert race, and the underlying framework call is not made forcibly cancellable or isolated from a stalled service by these checks.

Synthetic coverage includes wide/tall aspect preservation, normal Retina sizing, negative origins, invalid/non-finite/overflowing rectangles, huge finite coordinate conversion, fractional dimensions and extreme aspect ratios. Native movement, resize, display hot-plug, TCC revocation and cancellation acceptance remain open. Historical capture evidence predates this increment and does not certify the new native checks.

## Capture result deadline

Capture and fixture-window inventory now share a ten-second `ContinuousClock` budget per invocation. Checks run before work, after framework awaits, before encoding and before returning. The exact deadline is expired; repeated checks never renew it. Cancellation takes precedence when checked. A late framework result or late PNG encoding cannot be returned as a successful fresh result.

This is a result-admission deadline, not a hard execution timeout. A framework call that never returns can still hold its task; worker isolation or framework-level interruption remains required for a hard latency guarantee. No retry, task-racing timeout or detached capture is introduced.

`capturedAt` records when the screenshot request began, rather than stamping the completed result as newly captured. It is a conservative request timestamp, not the exact hardware exposure timestamp. Inventory output is capped at 100 fixture windows, and permission is rechecked before returning inventory or an encoded frame.

Deadline tests use injected monotonic instants to verify exact-boundary expiry, delayed-result refusal, non-renewal, invalid budgets and task cancellation without waiting on real time or invoking capture APIs. Live framework delay/cancellation/revocation acceptance remains open.

## Fixture window selection and revalidation

The native adapter converts ScreenCaptureKit metadata into value snapshots and uses the same fixture selection policy before and after capture. Selection requires exactly one layer-zero window with the fixture bundle identifier and exact main-window title, a nonzero window ID, a positive owning PID and valid bounds. Missing candidates and initial ambiguity are distinct errors.

After capture, selection runs again across the complete enumeration, then compares the selected metadata with the original snapshot. A second eligible fixture window now makes the result stale even if the original window remains present. Replacement, movement, resize, changed owner, title or layer also reject the result. Auxiliary windows and unrelated application windows do not create fixture ambiguity.

Standalone tests exercise this shared policy with synthetic metadata, including initial ambiguity, invalid IDs/geometry, changed identities and a second fixture process appearing after capture. They do not exercise ScreenCaptureKit itself. Bundle identifiers and PIDs are metadata checks, not authenticated code identity; production process authentication and transient change-and-revert detection remain open.
