# Agent Ultra integration boundary

Agent Ultra now has a narrow, default-disabled native preview integration. The changes are limited to its local package dependency, native menu/quit lifecycle, selection suspension, dedicated preview controller and regression tests. Its Code shadow workspace, CLI sandbox, plain chat path, hidden Ultra beta and accounts are unchanged.

The new Swift package exports `ComputerUseClient`, `ComputerUseContracts`, and `ComputerUseAgent`. `StdioHarnessClient` launches the visible companion, negotiates MCP, and exposes typed session, observe, action, and cancellation methods. The caller cannot approve a session.

```swift
import ComputerUseClient
import ComputerUseContracts

let client = try StdioHarnessClient(companionExecutable: companionURL)
try await client.connect()
let session = try await client.openFixtureSession()
// Present the pending session in native UI; a person approves in the companion.
// Poll status with a bounded delay. Never treat awaitingApproval as ready.
// Observe only after the returned session state is ready.
let observation = try await client.observe(sessionID: session.id)
// Select a current, unambiguous target from this observation before constructing an ActionRequest.
// Forward Stop immediately; do not wait for a provider response.
try await client.cancel(sessionID: session.id)
await client.shutdown()
```

This is an API illustration, not a complete agent loop. Observation will fail if approval has not happened. The SDK sanitizes the child environment and does not forward provider credentials. A timeout shuts down the connection; it must not lead to automatic action repetition.

Before wiring this into production Agent Ultra:

1. Complete G0's live signed/TCC/IPC decisions and G3's native action acceptance.
2. Reinspect Agent Ultra's current dirty tree; do not use the previous inspection as a clean baseline.
3. Add a separate ComputerUseSessionCoordinator and explicit feature flag. Do not change the existing Ultra model rounds into implicitly privileged actors.
4. Connect the SDK events/status to DesktopSink and AgentHub without giving WebView approval authority.
5. Resolve SelectionMonitor interaction with the harness's physical-input pause policy.
6. Prove the selected CLI sandbox can reach only the intended broker channel. Preserve existing write, AppleEvent, and launch restrictions.
7. Run existing desktop and extension regression tests, then a real observe/action/verify/Stop flow.

Until these checks pass, this directory is integration preparation, not an accepted Agent Ultra feature.

The optional typed capabilities are `NativeTextHarnessClient.typeText(_:)` and `NativePointerHarnessClient.click(_:)`. They accept the same observation-bound `ActionRequest`, with setValue and press respectively. A key cannot be reused between semantic and native execution. The current pointer capability is limited to the fixture Save element.

`AgentRunner` supplies the provider-independent loop, with a host-defined completion condition, fresh targeting after inference, request/result correlation, scope validation, no-progress termination, and bounded action/time budgets. An opt-in `OpenAIResponsesPlanner` is now available; its synthetic HTTP tests are not evidence of real inference. The SDK sends client heartbeats independently of planner latency, and native pause reasons are exposed in session status.

## Implemented host coordinator (P5 preparation)

The package now exports `ComputerUseIntegration` and its native `@MainActor` `ComputerUseSessionCoordinator`. The coordinator is compiled and tested in this repository and is now wired to a dedicated native preview in Agent Ultra. The initial coordinator increment was read-only for Ultra; the subsequent application increment adds the limited wiring described below.

The default feature flag is off. Even with the flag enabled, `.plainChat`, `.code` and `.ultra` cannot begin a session; only `.computerUse` can. The caller provides a factory for a dedicated `ManagedHarnessClient`, which extends the typed SDK with `connect` and `shutdown`. Construction must not share an active connection with another coordinator.

The host must implement the required `selectionSuspension` callback before enabling this feature. Acquire a host-owned suspension token on `true`; release only that token on `false`, preserving user preferences and other consumers. The current preview implements this hook using SelectionMonitor tokens and waits for active clipboard work to drain before beginning a session. The inspected monitor can generate copy/pasteboard interactions, so a no-op production hook is unacceptable.

Lifecycle:

1. A trusted native host action calls `begin(mode: .computerUse)`; suspension is acquired before the factory launches a companion.
2. The coordinator connects and requests a fixture session. Only `awaitingApproval` is accepted as the initial state. It has no approval or automatic-resume method.
3. A bounded native host timer calls `refresh()`. Newer UI revisions supersede older in-flight poll replies. The view exposes identifiers, phase, generation, pause reason and typed errors, never observation text or credentials.
4. Only a ready session can call `run(goal:completion:planner:)`. The host supplies the goal, independent completion condition and explicitly configured provider; none is inferred from WebView content.
5. `stop()` invalidates ownership before asynchronous cleanup, closes the dedicated transport and then cancels the runner. Beginning another session during cleanup is rejected. Late connection, status or planner results cannot revive the old run.
6. Completion and errors close the transport and release the selection suspension. The host must await `stop()` when closing its computer-use view or shutting down; deallocation is not a lifecycle notification.

`ComputerUseViewState` is a Codable UI projection with a monotonically increasing revision and per-run UUID. Native sink code should use these to reject late events. It does not contain an executable action, grant or client object. Production WebMessage routing must remain an explicit whitelist and must not expose the host factory/feature flag.

## Application preview wiring and remaining gates

The local package dependency assumes sibling checkouts named `Milyonus-Agent-Ultra` and `Milyonus-Computer-Use`. This is a development layout, not a distributable dependency arrangement. No installed app bundle is replaced by building these sources.

The native status menu shows **Computer Use Preview** only when the trusted host launch environment has `MILYONUS_COMPUTER_USE_PREVIEW=1`. Set `MILYONUS_COMPUTER_USE_COMPANION` to the absolute companion executable path. The feature is off for ordinary launches; no preference migration enables it. No WebView message or existing chat mode can set these values.

The preview has **Start local fixture check** and **Stop session**. Open the project's fixture first. Start queues one deterministic local check, acquires selection suspension, waits for any active copy/clipboard restoration to finish, then requests a native companion session. After the user approves and the host observes readiness, the check fills `fixture.input` with a fresh nonce and independently verifies completion. No API key, model, network request, save action or screenshot egress is involved. The fixture must remain foreground. There is deliberately no post-approval button to click in Ultra, which would move focus away from the fixture.

Closing the preview stops its session. App termination in preview-enabled mode awaits cleanup before replying to AppKit's termination request. Stop releases only the preview's selection token, leaving user preferences and other suspension consumers intact. The monitor's periodic timer cannot reinstall event tracking while tokens remain held; pending reads are invalidated by generation, and new clipboard work is refused.

Validation: the Ultra build succeeded and its complete `--desktop-selftest` reported **3293 passed, 0 failed**, including 13 new assertions for the exact opt-in flag, token ownership, duplicate release, rejection of new copy work, draining, and resumption. The harness reported **93 cases / 552 assertions**, zero failures. These checks do not prove visual layout, native preview approval/quit behavior, signed IPC or real-provider end-to-end completion.

Remaining:

- Perform the live Ultra preview observe/action/verify/Stop/close/quit matrix, including selection work already in flight.
- Complete production identity/broker and sandbox transport acceptance; keep the feature default-disabled.
- Complete the real-provider desktop pilot and broader native/agent acceptance matrices.
- Replace the development sibling-path dependency with a reviewed distribution arrangement.

The direct-child stdio client belongs in a trusted native host. It must not be made callable from a sandboxed CLI through a general escape route. `AgentSandbox` was not changed. A production authenticated broker remains an open G0 requirement.

## Isolated preview verification

`scripts/build-ultra-preview.sh` in the harness checkout builds a separate ad-hoc bundle with identifier `com.milyonus.computeruse.ultrapreview`. Launch its executable with `--computer-use-preview-only` and the preview/companion environment variables above. This path bypasses the normal accounts, chat, bridge and main application startup. It does not replace or terminate an existing Milyonus app. Optional `MILYONUS_COMPUTER_USE_DIAGNOSTICS=1` records phase/error metadata on stderr, not text values or credentials.

A live controller-operated check verified pending-session display, Stop, companion exit and closing the pending-session window with preview process exit code 0. The existing Ultra app remained running. This is limited lifecycle evidence, not approved action or normal-host selection-monitor acceptance. See `ultra-preview-lifecycle.json` for the exact tested binary.

Subsequent review fixed release of a suspension accidentally enabling a monitor that had never started. `start()` is idempotent and tracking installation now requires that lifecycle to have started. Diagnostic output records state changes rather than every poll revision.

## Optional authenticated XPC factory

The harness now includes an opt-in `XPCSessionClient` using an independently registered companion service. `XPCFactoryExample.swift` shows the native host injection point; it is compiler-checked against the actual package modules. The coordinator's factory is explicitly main-actor isolated, allowing Foundation XPC connection ownership without unsafe isolation assumptions. Existing stdio factories remain supported.

The example defaults to enabled=false. A trusted host must supply the service name and peer signing policy; WebView messages, model proposals and sandboxed tools must not choose them. For the current development fixture route, the companion must be independently started with `--broker-development <service> <client-cdhash> --fixture-actions`. The typed client also explicitly opts into fixture actions. Native session approval remains in the companion, and automatic heartbeats use the independent control lane after ready is observed.

This example does not install a service, change Ultra launch preferences or replace its current preview transport. The actual normal-host selection/clipboard and mid-action lifecycle acceptance remains open. Ad-hoc rebuilds currently require renewed permission registration on this host; production needs stable signing and distribution acceptance.
