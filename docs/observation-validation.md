# Observation structure and payload admission

`Observation.validate()` is shared by the execution engine and stdio SDK. It checks bounded ASCII observation/session/element handles, a nonempty bundle ID bounded to 255 UTF-8 bytes without NUL, positive PID, finite capture timestamp, the `accessibility` source, and at most 300 elements.

Element handles must be unique across the observation. Roles must be nonempty, optional rectangles must have finite representable positive geometry, and action lists must contain distinct supported actions. Role, identifier, label and value text share an exclusive 48,000-byte UTF-8 budget, matching the current native traversal budget. The validator subtracts remaining capacity before addition to avoid integer overflow. It does not silently trim oversized payloads or discard invalid elements.

A truncated observation can remain structurally valid as partial diagnostic data. Structure validation does not authorize actions from it: the native target cache and gesture acceptance runner reject incomplete observations. The general agent runner gained its explicit check in the later [adapter-boundary increment](agent-adapter-boundary.md). This method does not establish freshness, foreground focus, code identity, native approval, secure-field redaction or postcondition truth. Session/application correlation remains a separate boundary check.

Invalid observations produced by a driver cause the engine to invalidate target state and throw `PROTOCOL_MISMATCH`. Invalid stdio observations close the dedicated SDK transport. Neither path retries or transforms bad data into apparently complete data.

JSON Schema rejects duplicate whole element objects, duplicate actions, empty roles and more than 300 elements. Runtime validation additionally enforces unique handles when objects differ, aggregate UTF-8 bytes, finite timestamps and rectangle-edge arithmetic; those constraints are not all expressible with these standard schema keywords. Schema string lengths count characters, while runtime byte bounds are stricter for non-ASCII bundles.

Synthetic contract tests cover valid/partial observations, the exact node/text boundaries, duplicate handles/actions, invalid source/role/geometry/date and multibyte text. Driver and synthetic stdio tests verify rejection at the actual boundaries and target/transport cleanup. No native window, capture, approval or provider was used; native observation acceptance remains separate.
