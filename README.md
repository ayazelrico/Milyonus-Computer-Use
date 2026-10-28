# Milyonus Computer Use

A native macOS computer-use harness under active development. The current build is a **fixture-only development preview**, not a general desktop-control product.

The package contains a visible AppKit control app, an isolated test application, a read-only diagnostic CLI, typed Swift contracts and client, an MCP stdio interface, session approval and cancellation, bounded Accessibility observations, semantic actions, native Unicode text input, a bounded provider-independent agent loop, and a crash-aware action journal.

All implementation code, UI copy, runtime messages, and implementation documentation are in English. The original approved planning documents remain available as historical Turkish planning inputs: [plan.md](plan.md) and [Plan Actions.md](<Plan Actions.md>). Current implementation status and unmet release gates are tracked in [docs/STATUS.md](docs/STATUS.md).

## Build

Requirements: macOS 14 or newer, Swift 6.2 or newer toolchain. This checkout has been compiled and tested on macOS 26.6.2, Apple Silicon, Swift 6.3.3. macOS 14 runtime and Intel are not yet verified.

```sh
swift build
swift run computer-use-selftest
./scripts/build-apps.sh
```

Command Line Tools on the development machine does not ship XCTest or Swift Testing. The standalone test executable checks contracts, coordinates, sessions, persistence and lease behavior, prints every test result, and exits nonzero on failure. It is not a wrapper that ignores failed assertions.

Development bundles are created at:

- `build/MilyonusComputerUse.app`
- `build/ComputerUseFixture.app`

They are ad-hoc signed. Developer ID signing and notarization are separate release steps. Updating a development bundle can affect macOS permission attribution; do not assume permission behavior matches a stable Developer ID build.

## Native control window

Open the companion and use its native permission controls if macOS access is missing. Accessibility is necessary for UI observations and actions. Screen Recording is used only by the capture probe in this preview. The harness never edits the TCC database or grants itself OS permissions.

A session is limited to the local fixture, expires after five minutes, and remains inactive until approved in the native companion. Pause, Stop, resume approval, sleep/session interruption, and observed physical input invalidate or interrupt execution. The fixture must be active for observation and mutation. Switching to another app is a safe failure, not a reason to bypass focus checks.

MCP sessions require a heartbeat every five seconds and pause after 15 seconds without renewal. The Swift SDK maintains this independently of inference. A late heartbeat cannot resume control; see [session lifecycle](docs/session-lifecycle.md).

The native grant is separate from MCP: there is no approval tool. This protects against model requests granting themselves permission; it is not a claim that arbitrary local software cannot synthesize a native button click.

Direct-child SDK launches can have different effective macOS permissions from launching the companion normally. The companion’s System Settings toggle alone is not a verified SDK revocation mechanism. See [measured permission attribution](docs/permission-attribution.md); production broker identity remains an open gate.

## Automated checks

For background verification while using the computer, initialize the test-only schema validator once:

```sh
python3 -m venv .tools/schema-venv
.tools/schema-venv/bin/pip install -r scripts/schema-requirements.lock
./scripts/verify-background.sh
```

This command compiles, runs Swift and independent JSON Schema tests, and packages bundles without launching app windows. Full transport verification below launches visible companions and should run only when that will not interrupt the user.

Close idle companion instances before testing. The verification script does not kill an existing user's session to acquire its lock.

```sh
./scripts/verify.sh
```

This builds, runs core tests, packages both apps, exercises MCP over actual pipes, and exercises the Swift SDK. Its protocol and SDK tests deliberately do not approve a session or mutate the desktop.

For real Accessibility action testing:

```sh
open build/ComputerUseFixture.app
python3 -u scripts/live-fixture.py --native-text --native-click
```

When the companion shows the pending session, click **Allow pending fixture session** and leave the fixture foreground while the test runs. The script performs ten Unicode text/save iterations, checks independent fixture state, rejects stale targets, suppresses duplicate effects, checks secure-field exclusion, and exercises pause/cancellation. It cannot approve itself. Interacting with the computer can correctly interrupt it.

For a silent-client expiry test, add `--heartbeat-expiry`; for repeated pointer stress, add `--iterations 30`. Each mode has a separate evidence artifact. The expiry test requires both the deadline and a `heartbeatLost` pause reason, so physical interruption cannot masquerade as lease-expiry success.

To test the Swift SDK and agent loop without credentials or provider traffic:

```sh
swift run milyonus-cu agent-fixture-selftest "$PWD/build/MilyonusComputerUse.app/Contents/MacOS/MilyonusComputerUse"
```

This deterministic planner waits 18 seconds before proposing an edit, exceeding both the observation freshness window and the heartbeat lease. The SDK must keep the session alive and the runner must obtain a fresh target before executing. Native approval is still required. This is not model inference.

A successful slice is not the full 20-scenario G3 acceptance matrix. See [docs/STATUS.md](docs/STATUS.md) for the actual evidence and missing cases.

Read-only diagnostics:

```sh
swift run milyonus-cu doctor
swift run milyonus-cu capture-fixture
```

`capture-fixture` captures only the supplied fixture window and prints dimensions, byte count, and a content hash. It does not write the image to disk or transmit it to a provider. `doctor` reports permissions for its own invocation; permission attribution may differ from a Launch Services or direct-child companion launch.

## MCP connection

Use the packaged companion executable as a stdio server:

```json
{
  "mcpServers": {
    "milyonus-computer-use": {
      "command": "/absolute/path/Milyonus-Computer-Use/build/MilyonusComputerUse.app/Contents/MacOS/MilyonusComputerUse",
      "args": ["--mcp"]
    }
  }
}
```

This is a configuration example. The project does not edit global agent profiles or provider credentials. Supported negotiated protocol versions are `2025-11-25` and `2025-03-26`; other versions fail explicitly. Only newline-delimited JSON-RPC is written to stdout.

Tools: `system_capabilities`, `session_open`, `session_status`, `session_heartbeat`, `session_pause`, `session_cancel`, `desktop_observe`, `desktop_action`, `desktop_type_text`, `desktop_click`. Actions currently support `setValue` for `fixture.input` and `press` for `fixture.save`. `desktop_type_text` replaces the same input through native keyboard events, accepts at most 1,024 UTF-16 units, and verifies the resulting value. Empty text deletes the selected field contents. `desktop_click` uses native pointer events at the resolved Save button center and requires an exact hit test before each event. Other identifiers and action kinds are rejected.

Every action binds a session, generation, current observation, target identifier and idempotency key. Repeating a completed request returns its earlier action result. Reusing the key with changed content or a different execution method fails. An unresolved persisted intent is an unknown effect and cannot be automatically replayed. Even a successful native action may have failed or unavailable verification; callers must inspect both fields.

## Swift integration

Use `ComputerUseClient.StdioHarnessClient` to launch and connect to a dedicated companion. It implements the typed `HarnessClient` protocol. Its optional `NativeTextHarnessClient` capability provides `typeText(_:)`. Always call `shutdown()` when the owner closes; cancellation and RPC timeout terminate the child transport rather than retrying uncertain actions. Concurrent opens and late opening/heartbeat replies are fenced by the [SDK ownership lifecycle](docs/sdk-session-lifecycle.md). Shared [action-result validation](docs/action-result-validation.md) rejects contradictory outcomes before SDK delivery or journal completion. [Observation validation](docs/observation-validation.md) checks received target structure and payload limits separately from freshness and native authorization.

[Example Host integration notes](Integrations/ExampleHost/README.md) explain the proposed boundary. The Example Host checkout has not been modified. Its existing CLI sandbox, hidden external host beta and host workspace behavior are not relaxed by this package.

## Agent orchestration

`ComputerUseAgent.AgentRunner` accepts a host-defined goal, completion condition, approved session, and an `ActionPlanner`. It checks app/session scope, obtains a fresh observation after planning, verifies target continuity, bounds actions and elapsed time, and stops after three consecutive actions without visible progress. The planner cannot redefine the completion condition. The [adapter boundary](docs/agent-adapter-boundary.md) rejects structurally invalid, incomplete or stale observations even when a custom client bypasses the stdio SDK. Unknown effects are never retried. Planner transports must enforce the supplied inference deadline; an opt-in OpenAI Responses adapter is implemented, with synthetic transport tests; real inference acceptance requires a configured key and explicit model. See [provider matrix and pilot command](docs/provider-matrix.md).

Native input sequences check authorization before every event, retain one execution claim across asynchronous verification, and release held inputs during cancellation cleanup. Native Stop can run while verification awaits the fixture. The internal emitter also has pointer/scroll/key primitives. Fixture Save clicking has live evidence; experimental fixture-only scroll/drag routes are documented below and still await native acceptance. Arbitrary coordinates, general drag paths and key chords are not public capabilities.

## Data and limitations

The companion stores a private journal in `~/Library/Application Support/MilyonusComputerUse/actions-v1.json`. It contains action hashes and result metadata, not raw input text. The hard cap is 2,000 entries; automatic retention/export is not implemented. Unresolved intents must not be discarded just to retry an operation. The adjacent advisory lock coordinates cooperating companion processes and is not peer authentication.

Not yet implemented or accepted: arbitrary-app control, arbitrary coordinate/scroll/drag and arbitrary key APIs, multi-display native acceptance, OCR, browser DOM adapters, real provider inference acceptance, production XPC broker authentication, full Example Host integration, worker-process AX isolation, full recovery/performance matrix, signed public distribution, and cross-platform support.

See the [threat model](docs/security/threat-model.md), [development ADR](docs/adr/001-development-boundary.md), and [release runbook](docs/release.md). Do not broaden the fixture allowlist and call the result production-safe.

### Anthropic provider verification

Configure `ANTHROPIC_API_KEY` and `MILYONUS_ANTHROPIC_MODEL` in the host process environment. Never commit credentials. Run `milyonus-cu anthropic-plan-check` for two real provider proposals using synthetic observations and no desktop actions. Run `milyonus-cu anthropic-fixture /absolute/companion/executable --allow-fixture-egress` for the native fixture pilot; native approval and fixture foreground focus remain required. The adapter sends minimized AX fields, not screenshots, and does not implement Anthropic's built-in computer-use toolset.

### Native host integration

`ComputerUseIntegration` exports a default-disabled `ComputerUseSessionCoordinator` for a dedicated computer-use mode. It owns connection cleanup and rejects late run/status results. It requires a host selection-suspension hook and does not grant native approval. See [Example Host integration](Integrations/ExampleHost/README.md) for lifecycle requirements and the outstanding application wiring gates.

### Experimental fixture gestures

The optional gesture fixture and SDK/MCP vertical scrolling and fixed drag implementations are described in [Bounded pointer gesture preparation](docs/gesture-execution.md). These routes require native approval and fresh fixture targeting, and have synthetic coverage only. They are advertised separately as `experimentalNativeFixtureScroll` and `experimentalNativeFixtureDrag`; live native acceptance remains pending. The model planners continue to support the accepted edit/save action vocabulary.

The explicit `gesture-fixture-selftest` CLI can record a future approved two-action native run, including executable hashes and independent post-action observations. See the gesture guide for prerequisites; the basic two-action native fixture slice passed on 2026-10-27; the full interruption matrix remains open.

Typed feature and permission snapshots are available through `CapabilityHarnessClient.capabilities()`. See [Capability discovery](docs/capability-discovery.md) for compatibility checks and the distinction between discovery and native authorization.

Authenticated XPC implementation and evidence: [docs/authenticated-ipc.md](docs/authenticated-ipc.md), [connection-owned sessions](docs/connection-session-ownership.md), and [independent control lane](docs/xpc-control-lane.md). The opt-in typed SDK and independently started companion have passed one approved fixture AX edit; the full native, integration and distribution gates remain open.
