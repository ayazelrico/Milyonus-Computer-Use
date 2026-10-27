# Provider capability and acceptance matrix

Updated: 2026-10-27.

Latest OpenAI native attempt 5 passed with `gpt-5.4-mini-2026-03-17` on 2026-10-27: one edit, then finish, with independent completion and session cancellation. Earlier focus/no-progress/approval-timeout failures remain retained. The repeated-write cause was observed in attempt 3; explicit completion instructions were then validated through real contract and native checks. No persistent credential configuration was saved.

| Adapter | Implemented | Verified locally | Still required |
|---|---|---|---|
| OpenAI Responses structured planner | HTTPS request, strict JSON plan, explicit model, host-owned credential, deadline, bounded reply, refusal handling, no retries | Synthetic transport tests for request construction, minimized observation egress, malformed plans, wrong scope, incomplete output, refusal, size limit and HTTP failure | Broader cancellation/redirect transport acceptance and 10 tasks × 5 native pilot runs |
| Anthropic Messages tool planner | Explicit model, API version 2026-10-21, one strictly validated proposal, bounded transport, fixture-only egress | Synthetic transport coverage; renewed real two-proposal contract check and one native fixture edit with independent completion for claude-opus-5-5 on 2026-10-27 | Broader agent and interruption matrix |
| Other providers | `ActionPlanner` extension point only | Provider-independent runner tests | Concrete adapters and their own acceptance evidence |

The first adapter is a text/Accessibility planner. It does not implement OpenAI's built-in computer-use tool or send screenshots. The companion does not receive a provider key and still exposes no image-egress tool.

## Data boundary

The host must opt in using `allowFixtureObservationEgress: true`. The planner binds to one session and the bundled fixture's bundle ID. It sends the host goal/completion condition and only `fixture.input`, `fixture.save`, and `fixture.status` fields. Ephemeral handles, process identifiers, bounds, labels, unrelated fields and secure-field values are omitted. Visible values are untrusted data inside the user input, never developer instructions. Prompt instructions are defense in depth; native checks remain authoritative.

The host supplies a credential closure. The adapter keeps the resulting key only in memory for the request and uses a fixed `https://api.openai.com/v1/responses` endpoint. The default transport refuses redirects and uses ephemeral URLSession storage. It does not log request/response bodies or provider error bodies. It requests `store: false`; this is not a claim of zero provider retention under every account policy.

HTTP errors, incomplete output, refusals, extra plan fields, unsupported actions and incorrect targets fail explicitly. There is no model fallback or automatic retry. A valid `finish` proposal still needs independent host completion verification.

## Native pilot entry point

The operator must configure `OPENAI_API_KEY` and `MILYONUS_OPENAI_MODEL` in the invoking environment. Do not put keys in command arguments, repository files or chat messages. Model selection is explicit; no model name is silently assumed.

```sh
swift run milyonus-cu agent-fixture \
  "$PWD/build/MilyonusComputerUse.app/Contents/MacOS/MilyonusComputerUse" \
  --allow-fixture-egress
```

Start the fixture first. The CLI creates a pending native session, waits up to 120 seconds for approval, then permits up to six planner steps over a 90-second run. The fixed task sets `fixture.input` to `Agent fixture verification` followed by a fresh nonce; the completion condition is set by the host before inference. The Swift SDK sends heartbeats independently of inference. On completion or failure the child transport is closed. This opt-in command may incur provider API charges.

The development environment currently has neither `OPENAI_API_KEY` nor `MILYONUS_OPENAI_MODEL` configured. No credential was searched for in files or copied from another product. Synthetic tests are not real inference evidence.

## Official references

Request format and strict structured output follow the [official OpenAI Structured Outputs guide](https://developers.openai.com/api/docs/guides/structured-outputs), consulted on 2026-10-25. The implementation independently validates output and handles refusal/incomplete responses.

## Anthropic pilot

`anthropic-fixture <absolute-companion-executable> --allow-fixture-egress` uses `ANTHROPIC_API_KEY` and `MILYONUS_ANTHROPIC_MODEL`. The user supplied a credential for this test; it was passed through non-echoing stdin into the parent process environment, not persisted in repository files or forwarded to the companion. No existing product credential store was read.

The adapter posts only minimized fixture data to `https://api.anthropic.com/v1/messages`. It uses API version `2026-10-21`, a strict `propose_fixture_step` schema and auto tool selection with parallel calls disabled. The adapter independently requires exactly one valid proposal; plain text, multiple calls, unknown tools, truncated output and refusals cannot execute. Unlike the OpenAI request, no unsupported `store` parameter is sent; provider retention is governed by the account policy.

Official references consulted on 2026-10-25: [API versions](https://platform.claude.com/docs/en/api/versioning), [Messages API](https://platform.claude.com/docs/en/api/messages/create), and [parallel tool use](https://platform.claude.com/docs/en/agents-and-tools/tool-use/parallel-tool-use). Opus 5.5 does not support forced `any`/`tool` choice, so this adapter uses `auto` and rejects a reply without the expected proposal.

## Shared input admission

Both adapters enforce [fixture input admission](provider-input-admission.md) even when used directly without AgentRunner. Malformed, incomplete, stale or ambiguous observations are rejected before credential lookup and rechecked before HTTP submission. This is synthetic contract evidence; real provider/native acceptance remains tracked separately above.

Both decoders also apply [strict response JSON validation](provider-response-validation.md), rejecting duplicate members and excessive nesting before proposal interpretation. Synthetic coverage is separate from real inference acceptance.

Actual native evidence: `evidence/anthropic-live-2026-10-27-native.json`. One fixture action passed independent completion and session cancellation. This is Anthropic evidence only and does not satisfy OpenAI or external host acceptance.

`openai-plan-check` is the OpenAI equivalent of `anthropic-plan-check`: two real planner requests against synthetic observations, no native actions. `openai-contract-2026-10-27.json` and `openai-live-2026-10-27-native-attempt-5.json` keep provider-contract and native evidence separate.
