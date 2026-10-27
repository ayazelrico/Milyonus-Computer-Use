# Session metadata consistency

`Session.validate()` checks bounded ASCII session IDs, nonempty bundle IDs of at most 255 UTF-8 bytes without NUL, positive generations, finite expiry timestamps and the relationship between state and pause reason. Only `paused` may carry a non-null pause reason. A paused session may omit that optional field for compatibility; no reason is fabricated.

All stdio session replies pass this validator before SDK delivery, including open, status, heartbeat and cancellation. Existing fixture bundle, expected session ID, open-generation/state, heartbeat-generation/state and cancellation-state checks remain in place. Contradictory or malformed replies close the transport with `PROTOCOL_MISMATCH`, without retry or native approval.

Expiry is validated as finite metadata, not compared with the client's wall clock. The companion's monotonic session/heartbeat deadlines remain authoritative. This validation does not turn a ready-shaped reply into a native grant, infer approval from a timestamp, or make a terminal session active again.

The wire schema mirrors the state/pause-reason rule and bundle character-length bound. Runtime UTF-8 byte bounds are stricter for non-ASCII text; decoded date finiteness is also checked directly. No fields or protocol version change.

Synthetic tests cover every state with every pause reason, identifier/bundle/generation/time bounds, and the core controller's open/approve/heartbeat-expire/resume/cancel/expire transitions using an injected clock. Pipe tests cover inconsistent reasons and malformed expiry strings on all four session response routes, including subsequent transport closure. These tests do not involve real native UI approval, permissions or desktop input.
