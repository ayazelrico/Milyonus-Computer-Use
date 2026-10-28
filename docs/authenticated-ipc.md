# Authenticated broker connection foundation

`ComputerUseIPC` provides a main-actor-owned XPC connection and a typed peer policy. It is a separate library; the existing stdio SDK and Example Host adapter do not use it yet. No native action, approval, observation, grant or raw proxy is exposed by this module.

A production policy requires an Apple Developer ID Application certificate, an exact ten-character Team ID, and an exact signing identifier. Inputs are validated before compiling a Security requirement. Remote messages cannot supply policy. An explicitly named development constructor pins an exact CodeDirectory hash; it is not an update or publisher policy. The Developer ID expression compiles, but no installed production identity is available for a real signed-peer test.

The first request contains only a random public nonce. The client becomes authenticated only after receiving the same nonce and protocol version 1 through the signature-checked connection. Prior separate-process experiments established that an incorrectly signed server can receive this first request before its reply is rejected. Never add desktop data, credentials, native grants or action intent to this exchange.

Authentication belongs to one connection generation. Interruption, invalidation, timeout, cancellation and explicit close clear authentication and invalidate that connection. Late callbacks cannot authenticate a new generation. Reconnect creates a new nonce. XPC callbacks are explicitly Sendable and transfer state updates to the main actor; merely creating a Task inside an actor-inferred Foundation error closure is insufficient.

The package now declares Swift tools 6.2 because actor-isolated destruction is used to clean up the Foundation connection. Validation is on Swift 6.3.3; Swift 6.0 is no longer advertised. The deployment target remains macOS 14, whose runtime has not been tested.

## Independent process evidence

Run `python3 scripts/xpc-sdk-probe.py --evidence <new-json-path>` to build the real library and link separate peer/client executables against its object files. Each is ad-hoc signed independently. Ten temporary per-user launchd jobs exercise matching peers, wrong client signature, wrong server signature, wrong nonce, wrong version a silent peer, client cancellation, peer exit, and the library listener’s successful and refused client lifecycles. Each job is removed in a finally block. This exposes only the handshake and uses no desktop APIs or user content.

The first run on 2026-10-28 authenticated matching peers, then crashed in the Foundation error callback on wrong-client rejection. A symbol-only crash inspection identified `_dispatch_assert_queue_fail` in `AuthenticatedBrokerConnection`'s actor-inferred proxy error closure. The explicit Sendable callback fix passed all six separate-process cases in `evidence/xpc-sdk-2026-10-28-2.json`; the failed first record is preserved. The earlier full-suite run also exited with signal 5 and its incomplete buffered output is retained as `selftest-xpc-first-attempt.log`.

The expanded eight-case run passed in `evidence/xpc-sdk-2026-10-28-3.json`, including cleared authentication after peer exit. Debug and Release standalone suites each passed 231 cases / 2476 assertions / zero failures.

## Remaining integration

This is an authenticated connection foundation, not a production broker. The visible independently launched companion still needs a registered service, trusted host policy, bounded request routing, connection-owned native grants, disconnect cancellation and a tested permission grant/revoke lifecycle. Do not route native actions through this library until those server boundaries are implemented. Existing fixture-only scope and all execution checks remain unchanged. Developer ID, normal external host integration, minimum-OS and distribution acceptance remain separate gates.

## Server connection ownership foundation

`BrokerHandshakeListener` owns a bounded set of XPC connections (default four; configurable from one to eight). It sets the trusted client signing requirement before resuming each connection and exports only the bounded nonce handshake. Connection admission itself is not a native grant or a verified handshake. UUIDs identify transport lifetimes only.

Interruption, invalidation and explicit shutdown remove owned connections before invoking the disconnect observer, outside the state lock. Removal is idempotent, so the observer runs once per removed connection. The observer may arrive on an XPC queue and must transfer any UI/core work to its owning actor. A future native router must bind the exact connection ID to its session and cancel only that session; no such router is implemented here.

The real SDK client also connects to a separate executable using this actual library listener. Evidence checks authentication followed by exactly one disconnect notification, and rejection of an incorrectly pinned client followed by cleanup. All temporary launchd registrations are removed. No app is installed or permission requested by this probe. Peer limits are a resource bound, not a same-user denial-of-service guarantee.
