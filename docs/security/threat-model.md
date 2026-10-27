# Development threat model

## Assets and trust boundaries

Protect desktop control, input contents, observations, session authority, and execution history. Treat all model requests and all observed UI text as untrusted. Native approval is a distinct host-side operation. It is never an RPC tool, a model-generated boolean, or a field in a request.

The currently supported boundary is a dedicated visible companion child process and the bundled fixture application. It is not a production sandbox for malicious local software. Same-user executable replacement, malicious AX servers, synthetic native approval, and compromised providers are not fully isolated. No public network endpoint exists.

## Enforced controls

- Only `com.milyonus.computeruse.fixture` may be granted a session.
- Only `fixture.input` supports setValue; only `fixture.save` supports press.
- A valid session, current generation, fresh observation, unchanged target identity, active application, focused window, enabled element, and current AX permission are required.
- Secure text fields and their descendants are excluded from observations; secure subroles are rechecked before execution.
- MCP ready sessions require periodic client heartbeats. Missing heartbeats pause and fence generation; only native approval can restore authority. Heartbeats cannot extend the session lifetime.
- Observation traversal, text export, request bytes, input text, journal size, and session duration are bounded.
- The journal stores fingerprints and results, never raw text. Files are private at creation, synchronized, and atomically replaced. Unresolved intents survive restart as unknown effects.
- Reusing an action key with a changed payload or execution method fails. Reusing a completed key returns its previous result. A native AX timeout is unknown, never proof that nothing happened.
- Screenshot egress is not exposed through MCP. The fixture-only capture probe has live evidence; only dimensions, size and hash are emitted.
- Native text checks exact keyboard focus before each event. Native pointer clicking checks the exact Save element under the pointer before each event. Held inputs are released on failure/cancellation; this cleanup is attempted, not guaranteed if macOS refuses events.
- Asynchronous native execution retains a single claim while allowing Stop and session cancellation. There is no mutation retry.
- MCP has no approve, shell, AppleScript, external send, arbitrary path read, or general clipboard tool.

## Residual risks and release blockers

1. The native app uses MainActor for bounded AX calls. Per-message timeout and traversal limits reduce blocking but do not prove the 100 ms Stop budget. A separate worker process and adversarial AX tests are required.
2. App identity is currently a bundle identifier and observed process object, not signed-code attestation. A counterfeit local fixture is not excluded by cryptographic identity.
3. UI permission clicks can be synthesized by another authorized local process. Native approval is a separation from model RPC, not a hardware-backed proof of a physical human.
4. Global event monitors do not cover every form of physical interaction or every OS state. Hardware tests are outstanding.
5. The process lock coordinates this implementation only. There is no system-wide mutex for other computer-use tools.
6. The journal has a hard 2,000-entry cap and fails closed when full. Retention/rotation and secure export are not yet implemented. No automatic deletion destroys unresolved intents.
7. A malicious window may change between validation and execution. AX object identity checks narrow but cannot eliminate that race.
8. Generic GUI action risk classification is not solved. The fixture allowlist is intentional; arbitrary apps must not be enabled by editing a constant and calling the product safe.
9. AX text may include sensitive application data. The fixture-only scope and absent image egress limit this prototype; production redaction and provider-specific egress grants are outstanding.
10. The development SDK accepts an executable path. Its caller must supply the locally built companion; production signature verification is pending.

Critical controls must remain enabled even when real test acceptance is blocked. A denied action is evidence for a negative test, not evidence that normal computer use works.

The optional OpenAI planner runs in the host client, separately from the companion. It requires an explicit fixture-egress opt-in and a host-supplied credential. It sends a minimized fixture observation to the fixed OpenAI Responses endpoint with persistence disabled in the request. Real provider retention, account access, quota and live inference have not been verified. See `docs/provider-matrix.md`.
