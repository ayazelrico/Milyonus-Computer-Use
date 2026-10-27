# Release and recovery runbook

## Development validation

1. Build with `swift build` and run `swift run computer-use-selftest`.
2. Package with `scripts/build-apps.sh`; verify both signatures.
3. Run protocol and Swift-client smoke tests with no other companion session holding the lock.
4. Perform the live fixture test with a native approval. Keep synthetic, protocol and actual AX results distinct.
5. Run `milyonus-cu capture-fixture` while the fixture exists. Confirm only fixture metadata leaves the command.
6. Review the complete phase checklist. Passing the current automated tests does not override an unmet release gate.

## Production signing

No valid Developer ID identity was found during this implementation. The script below is prepared but has not been run successfully:

```sh
DEVELOPER_ID='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='your-existing-keychain-profile' \
./scripts/notarize.sh
```

The script uses an existing Keychain notary profile, signs with hardened runtime, submits both bundles, staples the tickets and performs system assessment. It does not accept secrets in source files, create accounts, buy a certificate, or publish a download.

Before distribution, validate the actual Developer ID build on a clean login, all advertised OS/architecture combinations, permission grant/revoke/update flows, independent client integration, update cancellation, and uninstall. Record bundle hashes and build revision with the evidence. Ad-hoc signatures are not a substitute for these checks.

## Safe interruption and recovery

- Use the native Stop button to cancel the current session. Old observations and generations must not be reused.
- If the companion is unresponsive, quit only that companion process. AX operations already delivered may have taken effect. Inspect the fixture/application state before deciding what to do next.
- Relaunch creates no automatic replay. Reconnect does not authorize an unresolved action to run again.
- If the journal is corrupt, newer than this binary, unreadable, public, or over its cap, startup fails closed. Preserve it for diagnosis. There is intentionally no silent reset button.
- A failed action with `effect=unknown` requires reconciliation, not a fresh idempotency key. A new key is not a safe retry policy.
- If another companion owns the lock, close its session normally. The verifier must not kill it silently.
- If a development update loses Accessibility attribution, use the OS permission UI. Never alter TCC database files or weaken system protections.

## Upgrade and rollback acceptance still required

The package script replaces executable inodes rather than overwriting the bytes of a running executable. This avoids invalidating live mapped code during development copying; it does not make live product upgrades safe. Production updating must first stop sessions, preserve journal compatibility, validate the replacement signature, and require a new observation/approval after restart.

Rollback must not open or overwrite a newer journal schema. Uninstall must explain how to remove only this product's state and revoke its permissions, without touching Agent Ultra accounts or unrelated files. These flows are documented requirements, not yet tested product features.

## Local-state file admission

Journal files must be private regular files owned by the current user, with exactly one hard link. The read opens nonblocking before inspecting the file descriptor so a substituted FIFO cannot hang startup while waiting for a writer. The journal's size and schema checks still apply after file-type admission.

The writer lock additionally requires a private owned parent directory and a private, single-link regular file. Unsafe permissions and alternate hard-link paths are rejected, not automatically repaired. This protects against accidental aliasing and unsafe local state; it does not authenticate arbitrary same-user clients or replace the planned production broker.

A rejected file is preserved. Do not delete or chmod unknown state automatically to force a launch. Diagnose the exact file type, owner, permissions and schema before recovery. Development tests construct temporary FIFO/hard-link/public-file cases; they never rewrite the user's production journal.


Journal completion is bound to the original action fingerprint and execution method. Response request IDs must match the completion request. A completed result cannot be replaced, even when its effect is unknown; only an identical completion is accepted again. Invalid completion leaves the prior record intact, and the execution engine pauses. An unresolved intent after restart remains an unknown effect and must not be replayed. These checks preserve the v1 on-disk format.


After any journal persistence error, the current ledger refuses further mutations, even if storage appears repaired. An intent-write failure pauses the session before effects; a completion-write failure pauses with unknown effect. Stop the companion, diagnose storage without deleting evidence, and reopen to validate persisted state. Reopening does not resolve an unknown intent or provide desktop approval. See [journal recovery evidence](evidence/journal-recovery.md) for tested boundaries and outstanding durability tests.


The regression runner can inject package-internal exceptions immediately before file synchronization, rename and directory synchronization. Production callers use the public initializer with these checkpoints disabled. A post-rename failure can leave a complete new record readable on disk even though the caller receives a persistence error; the current ledger remains latched and the session remains paused. The recovery matrix documents this case without claiming power-loss durability.


Abrupt process termination before rename can leave a private .journal-*.tmp file. Recovery reads only journal.json; it does not promote or automatically remove orphaned temporary records. Preserve them when diagnosing a crash. The standalone regression runner verifies SIGKILL recovery and writer-lock reacquisition in disposable directories; it does not test OS reboot, power loss or native companion recovery.


Journal loading rejects malformed keys, fingerprints and result identifiers as well as duplicate keys, excess entries and excess file size. Rejection preserves the file for diagnosis. At the 2,000-entry limit, existing entries may still be completed and read; new intents are refused. There is no automatic eviction, because dropping unresolved or completed records could erase replay protection. Capacity exhaustion requires a separately designed retention/recovery procedure; deleting the journal is not a supported workaround.


SDK teardown closes inherited input and sends SIGTERM to its dedicated child. After a one-second grace period it attempts SIGKILL if that owned Process remains running. Escalation targets only the direct child, not process groups or unrelated apps. Forced exit does not prove an in-flight desktop effect was undone; treat unresolved journal intents as unknown after restart. Native held-input cleanup and descendant-process behavior still need separate acceptance.


The SDK now uses nonblocking pipe I/O with bounded serialized frames, a ten-second request/write deadline and cancellation-aware reads. Stop clears queued frames and pending timers; partial writes are never replayed. Read-end closure does not depend on descendant-held stdout reaching EOF. The companion rejects duplicate JSON member names before dispatch, using the same bounded validator as SDK reply handling. Native acceptance for this latest companion build remains outstanding.
