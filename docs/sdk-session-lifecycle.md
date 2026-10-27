# SDK session-opening lifecycle

The stdio SDK admits only one pending `session_open` call. A concurrent open fails locally with `LEASE_BUSY` before issuing another RPC. This is an SDK concurrency guard, not native approval; the companion still controls whether any session can be created or approved.

An opening request captures an internal lifecycle token. Cancellation while opening invalidates that token before sending the cancellation RPC, and shutdown invalidates it as well. A late open reply can be adopted only while the connection and task are live and the original token still matches. Otherwise the dedicated connection is closed and the open call fails as cancelled, without assigning ownership or starting a heartbeat. Closing is conservative because a remote session may have been created before its reply arrived.

Cancellation and shutdown are not blocked by the opening guard. A cancellation response racing terminal shutdown may complete normally or fail as cancelled; either way, the old open cannot create local ownership. A closed client cannot reopen. Existing cancellation of arbitrary pending RPCs still closes the dedicated transport; this change does not relax that rule or introduce retries.

Synthetic pipe tests hold an open reply until a subsequent cancel request, then send the cancel reply and delayed open reply. They verify local refusal of a second open, unchanged RPC counts for rejected calls, no ownership or heartbeat after cancellation, and terminal shutdown. A package-only state snapshot exposes booleans for these tests, never session identifiers or grants. Tests use no sleep to manufacture reply ordering and launch no native companion.

These tests do not certify native approval, foreground behavior or actual heartbeat timing under GUI load. The earlier inherited-output timeout remains a separate unresolved reliability finding.

## Heartbeat ownership fencing

Each successful open creates a fresh internal lifecycle token, even if a peer reuses the same session ID. The automatic heartbeat task captures that token and session ID when it starts. Every tick checks both before status, after status, after renewal, and before continuing after an expected pause/generation refusal. An obsolete status reply cannot cause a heartbeat for a cancelled or replacement session.

The tick's generic error handler closes the connection only if it still owns that lifecycle. Lower-level malformed-response, timeout and task-cancellation rules remain unchanged: those may still close the dedicated transport conservatively. In particular, cancelling the timer while one of its RPCs is pending retains the existing transport-cancellation behavior; this change is not a guarantee of seamless same-connection reuse in that case.

A package-only entry point executes the same tick used by the five-second timer without changing the timer interval. Synthetic tests hold status replies until cancel or replacement open, deliberately reuse a session ID, and assert that only the expected cancel/open RPCs are issued. A positive control verifies that the current lifecycle still sends status and one heartbeat, and shutdown prevents further ticks. No native approval or real-time GUI heartbeat acceptance is implied.
