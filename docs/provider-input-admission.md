# Provider observation admission

Both the OpenAI Responses and Anthropic Messages planners use the same fixture-input admission check, including when called directly without `AgentRunner`. Scope and bounded goal/step/node checks run first, followed by shared observation structure validation. Truncated snapshots, timestamps at least ten seconds old or more than one second ahead, and duplicate exported fixture identifiers are rejected.

The exported identifiers remain `fixture.input`, `fixture.save` and `fixture.status`. Ambiguous identifiers are rejected even when their element handles differ. Existing field minimization remains unchanged: unrelated elements, labels, ephemeral handles, process metadata and secure fixture identifiers are not included in the request. This is fixture-specific minimization, not a general redaction guarantee for arbitrary adapters or applications.

Invalid context is rejected before invoking the host's credential closure. The deadline must also be finite and positive. Following credential retrieval, cancellation and deadline checks remain in force and observation admission runs again immediately before transport submission. A delayed credential lookup cannot silently turn an expired snapshot into a new outbound request. No retry, fallback, new approval path or additional provider is introduced.

Timestamp screening is conservative metadata validation, not proof of real capture freshness or authorization. Native policy and monotonic target/session checks remain separate. Provider completion remains a proposal subject to the runner's independent verification.

Synthetic tests invoke each planner directly with duplicate handles, duplicate exported targets, truncated/stale/future observations, oversized text, an excessive step budget and an infinite deadline. For every rejected case they verify zero credential reads and zero transport sends. Existing positive tests still verify minimized request bodies and strict proposal parsing. Post-credential freshness is enforced in code; actual slow credential/native/provider acceptance remains separate. No real key or network call is used by these tests.
