# Accessibility observation admission

The fixture AX traversal has a shared, deterministically tested budget: 300 visited nodes, depth 20, less than 48,000 exported UTF-8 text bytes and 500 milliseconds on a continuous monotonic clock. Visited nodes include secure fields even though their values and descendants are not exported. Text accounting includes roles as well as identifiers, labels and values. Cycle detection remains in the native adapter.

The budget begins before resolving the focused window. It is checked before node admission, after gathering text and after the final window revalidation. Hitting a limit marks the result `truncated`; the exact time and byte boundaries are excluded. Arithmetic rejects oversized byte counts without overflow. Existing per-attribute string limits and per-parent child limits remain in place.

Observation timestamps and the internal target-age clock now start before traversal. Targets are accumulated locally and published only after cancellation, permission, foreground application and focused-window checks succeed. A truncated result is available as partial diagnostic data, but publishes no native targets; action resolution explicitly rejects truncated observations as stale. A failed observation leaves the previous cache invalidated.

These are admission safeguards, not a hard runtime deadline or an atomic desktop snapshot. AX calls remain synchronous on the main actor with native messaging timeouts. A call may overrun the traversal budget before the adapter can mark the result truncated. A separate worker process is still required for isolation from hung or hostile AX servers. Permission/focus changes that occur and revert between checks are not proven detectable.

The budget tests use injected monotonic instants and counts; they do not call AX APIs or launch a companion. Native cancellation, permission revocation, focus/window switching and large-tree acceptance for this increment remain pending. Older native logs do not certify the rebuilt binary.

## Session boundary after a platform read

`ExecutionEngine.observe` rechecks task cancellation and the original ready session generation after the synchronous driver returns. If the heartbeat lease or session lifetime expired during the read, or the session was cancelled/reapproved, it invalidates cached targets and returns the appropriate error. Returned observation scope must match the requested session and application. Driver errors also invalidate the cache. No heartbeat is renewed by reading.

Core tests advance an injected clock during the driver call, change session generation, inject a mismatched bundle, throw a permission error and cancel the observing task. These are synthetic boundary tests with no native approval or GUI interaction. The production driver still requires native permission/focus checks; the engine boundary does not replace them.
