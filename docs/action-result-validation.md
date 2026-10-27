# Action result consistency

`ActionResult.validate()` applies the same identifier and outcome checks at the Swift SDK, execution completion and persistent journal boundaries. Identifiers must be 1–128 ASCII bytes using letters, digits, dot, underscore or hyphen.

| Effect | Allowed verification | Error |
|---|---|---|
| `applied` | `passed` | Must be absent/null |
| `applied` | `failed` or `unavailable` | Optional typed error |
| `notApplied` | `unavailable` | Optional typed error |
| `unknown` | `unavailable` | Optional typed error |

Verification is about an applied effect. A refused/unconfirmed effect cannot also claim passed or failed postcondition verification. An unavailable verification does not establish that no effect happened. Optional error fields remain compatible with existing valid receipts; no new fields or protocol version are introduced.

The stdio SDK closes its transport on a contradictory result for every mutation route. It never retries an uncertain response. Execution validates callback results before late-completion normalization, so cancellation cannot hide an invalid success claim. Invalid completion leaves the durable intent unresolved and invokes existing conservative pause handling. Terminal cancelled sessions are not revived.

Journal completion rejects invalid results before modifying or persisting an entry. Opening a journal containing a contradictory completed result fails with `PERSISTENCE_FAILED`; the file is neither repaired nor deleted. This intentionally rejects malformed historical records rather than treating them as evidence of completion. The JSON Schema enforces the same effect/verification/error relationships.

Coverage includes the outcome matrix, identifier bounds, malformed result transport responses on all five mutation routes, unchanged journal bytes after refused completion, malformed persisted records, and invalid late callback normalization. Tests use local synthetic stdio children and temporary journals. No companion, native input or provider is involved; live interruption and production distribution gates remain open.
