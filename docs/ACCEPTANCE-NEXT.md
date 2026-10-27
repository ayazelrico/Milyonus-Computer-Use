# Acceptance-first execution queue

Updated: 2026-10-27.

Further generic SDK/protocol hardening is not the default next task. Prioritize the acceptance gaps below. Add implementation or regression tests when a concrete acceptance failure requires them. Passing synthetic tests never closes native, provider, Ultra or distribution gates.

| Priority | Work | Current prerequisite / owner | Completion evidence |
|---|---|---|---|
| 1 | Git recovery point | Completed: baseline 64c8c55; fixture fix 34139f0 | Local commits preserve implementation and failure evidence; no credentials or build products |
| 2 | Native scroll and drag | Basic slice completed: second approved attempt passed on 2026-10-27 | Dated attempt-2 JSON verifies both native actions, independent postconditions and binary hashes; full interruption matrix remains open |
| 3 | Real OpenAI execution | User: configure OPENAI_API_KEY and MILYONUS_OPENAI_MODEL in the invoking environment; agent: execute the existing explicit provider fixture command during an approved foreground window | Actual provider response plus independently verified native completion, reported separately |
| 4 | Agent Ultra live acceptance | User: foreground availability and native approval; agent: use the isolated preview first and preserve the existing checkout/application | Approved action, independent observation, Stop, close and quit results; normal-host selection lifecycle remains a separate gate |
| 5 | Signed distribution | User: installed Developer ID Application identity and existing notarytool profile; agent: build/sign/notarize and verify | Signature, notarization/stapling, system assessment and subsequent clean installation/upgrade acceptance |

## Prerequisite check performed

The current command process has neither OPENAI_API_KEY nor MILYONUS_OPENAI_MODEL set. This is an environment check, not a search of unrelated credential stores. `security find-identity -v -p codesigning` reports zero valid identities. Do not paste credentials into chat or commit them; configure them locally for the invoking process. A certificate without its private key is insufficient for signing.

The native fixture is a real AppKit application using real macOS events. Its acceptance does not establish support for arbitrary third-party applications. The current allowlist remains fixture-only. See [gesture instructions](gesture-execution.md), [provider requirements](provider-matrix.md), [Ultra integration](../Integrations/AgentUltra/README.md) and [release runbook](release.md).

## Open reliability defect

Unexpected inherited-output and mismatch/closed-input timeouts remain unresolved. Preserve failed logs and existing deadlines. New diagnostic counters are available; a later passing run is not a fix. Investigate the recorded failure paths as a bounded defect task, not as justification for indefinitely adding unrelated validation layers. See [timeout investigation](stdio-timeout-investigation.md).

## Working agreement

Do not launch foreground acceptance while the user is working under the background-only restriction. Do not create native approvals through RPC or automation. When a prerequisite is missing, report its specific owner and condition; do not represent substitute synthetic work as progress on that acceptance gate. Commit subsequent coherent changes so this baseline remains recoverable. Local commits are not an off-device backup or a published release.

## Provider progress and next executable step

On 2026-10-27 the user selected Anthropic using their supplied credential/model. Both the real two-proposal contract check and one-action native fixture pilot passed; evidence is recorded separately in STATUS.md. This advances real-provider acceptance without claiming an OpenAI pass. OpenAI remains conditional on its own configuration. The next executable acceptance task is the isolated Ultra live action/Stop/close/quit slice, with a fresh foreground window and native approval; the normal host lifecycle remains separate.

OpenAI follow-up: model discovery and two native attempts were executed on 2026-10-27 with a transient user credential. The latest failed with NO_PROGRESS; diagnose bounded per-step metadata before another native attempt. The earlier missing-configuration prerequisite no longer explains this live failure, but credentials are not retained for future runs.
