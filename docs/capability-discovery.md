# Typed capability discovery

P4 now provides the optional `CapabilityHarnessClient` interface. `StdioHarnessClient.capabilities()` calls the read-only `system_capabilities` tool and returns `HarnessCapabilities`. The companion encodes that same shared contract instead of an untyped dictionary. `Schemas/v1/capabilities.schema.json` describes its wire representation.

```swift
let capabilities = try await client.capabilities()
if capabilities.experimentalNativeFixtureScroll && capabilities.maximumScrollPixels >= 200 {
    // Offer an experimental fixture test; native session approval is still required.
}
```

The response distinguishes:

- Semantic action vocabulary (`press`, `setValue`).
- Native text and resolved-element click implementation flags.
- Experimental fixture scroll and fixed-drag flags.
- Input bounds and the fixed 5-second renewal / 15-second heartbeat lease.
- Current Accessibility and Screen Recording permission snapshots.
- Fixture-only mutation scope, required native approval, no image egress, and non-production status.

Flags describe implemented features. They do not grant a session, prove live acceptance, authorize an application or bypass foreground/target checks. Permissions are a point-in-time snapshot and are checked again by native execution. Discovery does not start a session, request permissions or change focus.

The SDK accepts capability version 1 with its current fixture scope and heartbeat schedule. Duplicate/unsupported semantic actions, expanded application scope, removed native approval, image egress, a production-ready claim, incompatible limits or malformed types fail with `PROTOCOL_MISMATCH` and close the transport. There is no silent policy fallback. Smaller valid limits and disabled feature flags are allowed. Unknown extra top-level fields are ignored by the typed decoder; the published schema deliberately rejects them for conformance checks. Unknown permission keys are rejected at runtime.

This is explicit discovery, not automatic dispatch negotiation. Existing edit/save callers do not gain new behavior, and existing client protocols remain source-compatible. An older companion missing required capability fields is incompatible with this new discovery call; callers must use matching builds. The gesture acceptance CLI now checks both experimental flags, the scroll bound and Accessibility before opening its session.

Debug/Release and synthetic-child tests verify the contract and fail-closed transport behavior. They do not establish native gesture acceptance, authenticated IPC or production readiness.

## Opt-in negotiated dispatch

`NegotiatedHarnessClient(base: transport)` wraps a client supporting discovery and native methods. It queries and validates current capabilities before each mutation, then checks the relevant feature and input limit before forwarding exactly one request. It never caches permission snapshots, retries mutations, approves sessions or changes native target policy.

- Semantic actions require membership in `supportedActions`.
- Native click/text and experimental scroll/drag require their corresponding feature flags.
- Native text uses the advertised UTF-16 limit; scroll uses the advertised signed-delta bound.
- Invalid request shapes are rejected before discovery. Discovery errors propagate without mutation.
- Unknown action results pass through without replay.
- Status, observation and cancellation delegate directly. Cancellation must not depend on discovery succeeding.

The gesture acceptance CLI now uses this wrapper. Existing direct SDK consumers and Example Host retain their current behavior until they explicitly adopt it. Discovery can race a server-side change; all session, permission, focus and geometry decisions remain authoritative in native execution. A successful capability check alone never grants permission to act.
