# XPC peer admission feasibility

This standalone macOS experiment has no dependency on harness mutation code. It exports only a fixed `ping` and a fixed acknowledgement after the handshake. It cannot create sessions, approve, observe the desktop, perform actions, or receive user text. The existing SDK remains unchanged.

```sh
python3 scripts/xpc-peer-probe.py --named --evidence docs/evidence/xpc-NEW.json
```

The runner compiles in Swift 5 compatibility mode, ad-hoc signs a temporary executable, pins its exact CDHash on both ends, and creates one uniquely named per-user launchd Mach service per scenario. Each service is unloaded in a finally block. The temporary server also has a 30-second lifetime bound. No persistent plist is installed in Library/LaunchAgents, no root privilege is used, and no application permission is requested. The service name is not an authentication secret. The positive and negative peers use the same binary, with one requirement changed to a nonmatching hash in each negative case.

## Actual results

The separate-process named-service probe established:

| Signing requirements | Ping delivered | Second call delivered | Client result |
|---|---:|---:|---|
| Both match | 1 | 1 | Reply accepted |
| Listener rejects client | 0 | 0 | Connection error 4097 |
| Client rejects server | 1 | 0 | Signing failure 4102 |

The first request can reach a server whose signature will fail the client's requirement. Therefore its payload must contain no sensitive data or operational intent. The second method in this probe is called only after an authenticated reply on the same connection. The production design must also invalidate that state on connection interruption/replacement; this experiment does not implement production reconnect, session or action transport.

The initial tests deliberately failed on a presumed specific error code and then on the assumption that client-side requirements prevent the first request from being delivered. Those failed logs are retained. The final positive result is a limited feasibility observation, not proof that any production peer authentication or permission-attribution gate is complete.

## Required next boundaries

1. Choose and verify the independently launched, visible companion registration and lifecycle. A temporary unbundled launchd helper does not establish the companion's TCC identity.
2. Specify host-approved signing requirements for both broker and authorized clients. These must not be supplied by a remote client or inferred from a bundle name alone. Exact development hash pins are not Developer ID identity or update policy.
3. Use a verifiable first exchange without credentials, observations, session grants or action payloads. Bind readiness to the exact connection; revoke it on interruption.
4. Bind server-side session ownership to an admitted connection and invalidate its grants when it disconnects. Native approval remains local; no XPC method may grant approval.
5. Bound payloads, outstanding calls and deadlines, then preserve journal/idempotency and all execution guards through the new adapter.
6. Test mismatched signatures, stale/replaced connections, denied permissions, startup/upgrade/restart, and the normal Ultra sandbox path before routing native mutations through it.

## Primary references

- [NSXPCConnection.setCodeSigningRequirement](https://developer.apple.com/documentation/foundation/nsxpcconnection/setcodesigningrequirement(_:)): set before resume; malformed requirements raise an exception. This probe validates syntax with SecRequirementCreateWithString first.
- [NSXPCListener](https://developer.apple.com/documentation/foundation/nsxpclistener): named Mach listeners require launchd registration.

The local macOS SDK headers were also inspected for availability (connection requirements are available from macOS 13). This host does not establish minimum-OS or Intel compatibility.

## Fresh connection ownership check

The final named-service probe exports a separate object per accepted connection. After the matching client's handshake and acknowledgement, that client exits. A second correctly signed client connects to the same still-running server and invokes the post-handshake method without ping. The server replies handshakeRequired and records no additional admitted invocation. This demonstrates that the prototype's handshake state is connection-local rather than shared across clients. It is not a native session grant or a production reconnect policy.

Evidence: `docs/evidence/xpc-connection-ownership-2026-10-27-1.json`. The same run also reruns both signature-negative cases. The server stores only boolean diagnostic handshake state; it never receives a native grant, fixture handle or user content.

## Real SDK module probe

`SDKPeer.swift` and `SDKClient.swift` link the actual `ComputerUseIPC` module as separate signed executables. Run `python3 scripts/xpc-sdk-probe.py --evidence <new-path>` for eight bounded named-service cases. See [authenticated IPC](../../docs/authenticated-ipc.md). The original feasibility probe remains separate evidence.
