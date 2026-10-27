# Session lifecycle and client liveness

The companion has a five-minute monotonic session lifetime. MCP sessions additionally require a successful `session_heartbeat` at least every 15 seconds while ready. The advertised client interval is five seconds. Reading status, observing or sending actions does not renew liveness.

| State | Permitted transition | Authority |
|---|---|---|
| No session / cancelled / expired | awaitingApproval | Open scoped fixture session |
| awaitingApproval | ready | Native approval only |
| ready | paused | Native pause, physical interruption, environment change, uncertain effect or missing heartbeat |
| paused | awaitingApproval | Native resume request |
| Any nonterminal state | cancelled | Stop/cancel/disconnect |
| Any nonterminal state | expired | Five-minute deadline |

A heartbeat carries `sessionId` and `generation`. The controller validates both and current readiness before renewing. Heartbeats never grant approval, resume a paused session or extend the total lifetime. Missing a heartbeat increments generation once and pauses; late heartbeats cannot revive that session. Terminal states remain terminal on repeated reads and cancellation calls.

The half-second UI watchdog observes expiry and invalidates targets. Execution also checks the monotonic deadline immediately before actions and before each native input event, so correctness does not depend on the watchdog firing on time. This does not prove arbitrary hostile AX calls cannot stall the main thread; worker isolation remains an open gate.

`StdioHarnessClient` starts a five-second heartbeat task after opening its own session. It polls status while waiting for approval, renews only ready sessions, and cancels the task on cancellation/shutdown. A native pause racing a heartbeat is an authorization refusal, not permission to resume. Other transport failures close the child. Direct MCP clients must implement the advertised heartbeat tool.

Native-only sessions created outside MCP have no external-client liveness requirement. They retain total expiry, native control, focus checks and physical-input interruption.
