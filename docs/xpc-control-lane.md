# Independent XPC control lane

The same authenticated XPC connection now carries one ordinary request and one independent control request. Each lane has its own pending continuation and client deadline. The server holds separate tasks, so an awaited ordinary operation does not occupy the control slot. Admission limits remain bounded: 262,144 bytes for ordinary requests and 4,096 bytes for control requests. The total is at most two in-flight handlers per connection. Terminal failure or task cancellation closes the connection and drains both lanes without replay.

The control lane is not a second action route. The companion parses it using the same strict JSON decoder and permits only `session_heartbeat`, `session_pause` and `session_cancel`. The connection must own the current session; heartbeat generation and native readiness checks are unchanged. Opening sessions, capability discovery, observation and all desktop action names are refused on this lane. Core policy stays outside the model.

The ordinary lane still admits the existing lifecycle operations for compatibility. Desktop methods remain disabled on the development XPC route pending live native approval, permission lifecycle and interruption acceptance. Native control buttons remain independent of either wire lane.

## Evidence scope

The independent-process probe uses the actual library listener and SDK. A bounded synthetic ordinary request remains suspended; the client first observes that the server is waiting, then sends heartbeat and Stop control messages. Heartbeat receives a reply before Stop releases the suspended request. This proves transport concurrency, not native event cancellation. The twelve-case run is `evidence/xpc-control-2026-10-28-1.json`.

The standalone regression additionally checks duplicate ordinary-request rejection, the smaller control payload limit, successful control exchange while an ordinary request is silent, and connection invalidation on cancellation. It uses real anonymous XPC but no desktop API.

The packaged companion acceptance checks control-lane session cancellation and rejection of session_open on that lane, followed by disconnect and reconnect lifecycle. The first attempt was refused before launch because package receipt verification ran while repackaging was still finishing; that failed evidence is preserved. No stale package was launched by that attempt.

## Limits

These are asynchronous handlers on one XPC connection, not real-time priority scheduling. A synchronous main-actor native call can still delay main-actor control handling. Long native sequences must yield and revalidate session/ownership between effects. Permission attribution, approved-session teardown, native mid-action Stop, deployment identity and the historical stdio timeout remain separate acceptance items.
