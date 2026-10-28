# Acceptance-first execution queue

Updated: 2026-10-28. This queue supersedes the chronological notes previously appended here. Historical results remain in STATUS.md and evidence files.

| Priority | Work | Current state | Next concrete acceptance |
|---|---|---|---|
| 1 | Independent broker permission identity and peer admission | Same-binary launch-context discrepancy reproduced. The actual IPC/core modules passed eleven independent-process cases, including unapproved session cancellation on disconnect. The independently launched companion passed approved cleanup/reconnect, one opt-in AX fixture edit, and effective Accessibility toggle revocation with a concurrent userInput pause. Native input routes and full interruption acceptance remain open. | Independently launched visible companion with host-controlled signing policy, authenticated channel, connection-owned grants and disconnect cancellation. Then prove its own permission grant/revoke lifecycle. |
| 2 | Native interruption matrix | Pre-dispatch Stop, physical input and screen lock slices passed. Fresh-target closure remains unaccepted. | Isolate fresh-target closure and focus loss; then stop during delivered native events, sleep and partial-effect cleanup. |
| 3 | Normal Agent Ultra integration | 3713 current host headless assertions passed; isolated native action/Stop-after-completion/close passed. | Normal-host selection/clipboard work in flight and mid-action cancellation, preserving the existing host sandbox and user preferences. |
| 4 | Broader real-provider pilot | One-action native Anthropic and OpenAI slices passed; OpenAI repeated-write failure diagnosed and completion instructions fixed. | The planned task/repetition and interruption matrix; no claim that a single successful fixture task completes this gate. |
| 5 | Distribution | Ad-hoc packaging/signature/receipt checks passed. Zero valid signing identities installed. | Developer ID Application signing and an existing notarization profile, then clean installation, update and uninstall acceptance. |

## Completed basic slices

- Git baseline and subsequent coherent commits exist; source and evidence are recoverable locally. No remote backup or publication is implied.
- Actual fixture scroll and fixed drag passed independent postconditions.
- Actual Anthropic and OpenAI each completed one fixture edit with independently verified completion and session cancellation.
- Isolated Ultra completed one fixture action, Stop-after-completion, close and process cleanup.
- Native captured-request checks rejected writes after Stop, human input and screen lock.

## Architectural finding that changes test ordering

The current SDK launches a direct child over inherited pipes. A read-only same-binary comparison reported Accessibility/capture true in that context but false under Launch Services. The companion's own Settings toggle is therefore not a demonstrated SDK revocation control. See [permission attribution](permission-attribution.md). Repeating toggles does not resolve this boundary, and unrelated application permissions must not be disabled to force a pass.

The read-only [XPC experiment](../Experiments/XPCPeerProbe/README.md) establishes useful peer-check primitives, not a production broker. Wrong server identity can still receive the first request before its reply is rejected; that first request must contain no operational or sensitive payload. Fresh connections must perform their own authenticated exchange. Exact ad-hoc CDHash pins are development evidence, not a Developer ID policy.

## Constraints and external inputs

Native session approval remains manual. User authorization to test does not create a native grant. Keep tests confined to project windows and fixture content; preserve all focus, identity, generation, permission and journal checks. Lock/unlock and OS permission interventions need an operator. Provider credentials used earlier were transient and are not stored for future runs. Do not ask for secrets in chat; configure subsequent runs locally.

The existing Ultra checkout contains unrelated user changes; do not reset, clean or commit that checkout as part of harness work. Production signing credentials, minimum-OS/Intel hardware and physical display coverage are not available from this host's passing tests.

## Open reliability defect

The inherited-output and mismatch/closed-input stdio timeouts remain unresolved. Preserve their failed logs and existing deadlines. A passing stress run is not a root-cause fix. Investigate this as a bounded defect task, not as a reason to add endless unrelated validation layers or to defer concrete native acceptance.

Commit completed increments and continue with the next executable item. A commit is a checkpoint, not a phase gate. Update STATUS.md with actual evidence and limitations; never close one gate using another gate's test results.
