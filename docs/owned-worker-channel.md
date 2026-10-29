# Owned worker XPC admission

Date: 2026-10-29. Scope: authenticated transport foundation and process capacity; no native AX worker integration.

## Implemented authority boundary

The existing public broker listener and SDK paths retain their signing-policy behavior. New package-scoped overloads provide a worker-only path: at most one connection, no control handler, the existing signature requirement and an additional exact owned-process check before exporting the endpoint. A trusted launcher supplies a short, thread-safe provider of the selected incarnation's running PID. It must capture that exact process owner, never a worker-supplied PID or a global latest-worker resolver.

The ownership provider uses OwnedReadWorkerProcess.runningProcessIdentifier. Stop immediately makes this value nil even while the child remains alive during teardown. BrokerConnectionContext checks that liveness on existing admission boundaries. If ownership fails once, context revocation is permanent; a later matching PID cannot restore that connection. No worker method creates a native grant, renews a lease or bypasses session/target checks.

The worker client additionally checks the server's connection PID after the signature-checked nonce reply and before marking the channel authenticated. The same constraint is checked before each data send. This PID comes from NSXPCConnection, not a remote JSON field. [Apple's processIdentifier documentation](https://developer.apple.com/documentation/foundation/nsxpcconnection/processidentifier) describes its use in listener acceptance. Signature validation is retained: PID matching alone is not a publisher policy.

The initial exchange remains only a public nonce and protocol version. A wrong server can receive that first exchange before its reply is rejected; no fixture metadata, grant or observation is included in it. Ordinary payloads still require the completed signature/nonce/process checks. Existing byte limits, per-lane bounds, deadlines and generation fences are unchanged.

## One owned worker through retirement

ReadWorkerProcessSlot is broker-owned and retained across reads. An idle reservation already occupies the slot. Cancelling it latches Stop, while an already launching/running child continues to occupy capacity until its actual exit/failure is recorded. A replacement attempt returns LEASE_BUSY; there is no queue or automatic retry. A never-launched, stopped reservation is retired without spawning it, and cannot later be started through an old reference.

The real child test installs SIGTERM ignore and acknowledges readiness in a private marker. After Stop, authentication admission is nil immediately, but the slot refuses replacement until SIGKILL cleanup is observed. Only then can a new owner be reserved. This closes the foundation's earlier retiring-worker-slot gap. The slot still must be connected to the eventual production transport; creating a second independent slot is not a cross-broker lock.

## Independent-process probe

`python3 scripts/owned-worker-peer-probe.py --evidence <new-path.json>` compiles the actual IPC/core objects into an independently ad-hoc signed probe. Each case registers a temporary uniquely named per-user launchd service, starts a broker that owns its selected child, then removes that job. No companion, user window, Accessibility request or native grant is involved.

The fixed matrix is:

| Case | Required actual result |
|---|---|
| Selected owned child | Signature and process admission, one verified bounded metadata exchange, child exit |
| Same binary/signature sibling | Sibling handshake refused; selected child subsequently succeeds |
| Wrong client signature | No metadata handler invocation |
| Wrong server signature | Client never sends metadata after the initial nonce exchange |
| Wrong server PID | Signature alone insufficient; client never sends metadata |

The final source probe uses ReadWorkerProcessSlot for the selected child. The deliberately different sibling has its own test process owner, and is not that selected slot's worker. These are transport/process observations with known synthetic metadata, not actual AX collection or model inference.

## Verification

Debug build/selftests and optimized Release selftests each passed 252 cases / 2644 assertions / zero failures. The independent owned-peer matrix passed five cases. The existing named SDK probe passed all 12 scenarios after the listener constructor/context changes, including signature refusals, control-lane behavior and unapproved session cleanup. These counts represent different evidence classes and are not added into a native acceptance total.

The preliminary 251-case log predates the final process-stop/slot assertions; it is retained as historical evidence. The final source and log association is recorded in `evidence/worker-channel-acceptance-2026-10-29.json`.

## Remaining work

This is not a packaged native helper. Before companion integration, implement the fixed bounded read-ticket/reply wire format and native collector, trusted packaged-helper selection, private startup rendezvous, separate worker TCC measurement and broker-owned handle publication. Worker startup must not race admission before its owned running identity is available; the probe uses a private test gate, not a claimed production bootstrap.

Stable Developer ID identity, installed topology, native Stop under an AX stall and mutation/preflight isolation remain separate gates. Process.run itself cannot be forcibly preempted by the supervisor; unresolved launches must retain the slot. The current companion is not switched to this worker path, and prior packaged native evidence remains tied to its own hashes.
