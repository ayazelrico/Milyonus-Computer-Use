# Permission attribution depends on launch topology

## Measured result

On 2026-10-27 the same packaged companion executable, with the exact same `--permission-probe` arguments, reported:

| Launch | Parent PID | Accessibility | Screen Recording |
|---|---|---|---|
| Direct child of the test runner | Test runner | true | true |
| Launch Services (`open -g -W -n`) | 1 | false | false |

The measurements and common binary SHA-256 are in `evidence/permission-launch-comparison-2026-10-27-2.json`. The user's System Settings screenshot showed the companion Accessibility switch disabled. Normal application launch also displayed Accessibility not granted. This reproduces a launch-context difference; it is not a stale-value-only explanation and does not mean the toggle is broken.

Apple documents that macOS tracks which user-visible code is responsible for a helper, and that this relationship affects privacy attribution: [Apple DTS explanation](https://developer.apple.com/forums/thread/125438). Responsible-code inheritance is a plausible explanation of this host's difference, but the exact responsible process was not identified. `launchctl procinfo` required root; no escalation, private API, TCC database inspection or reset was performed. Do not infer that a particular unrelated app's permission should be revoked.

## Meaning for the prototype

The SDK currently starts the companion as a direct child using inherited pipes. `AXIsProcessTrusted()` reports effective trust in that process context; it does not prove that the companion's own System Settings entry granted access. Native session approval, foreground checks, generation fencing, target validation and journal checks remain required even when effective trust is true.

Turning off only the companion's visible Accessibility entry is therefore not a demonstrated revocation mechanism for this development SDK topology. The failed revocation run remains failed. Earlier native action results are still evidence of actual fixture actions, but they are not evidence of independently scoped companion permission identity or production isolation.

Do not work around this by changing trust results, checking a guessed parent name, granting permissions automatically, modifying TCC, or launching another helper solely to escape attribution. Production needs an independently launched broker and authenticated transport, stable signing identity, and separate native permission grant/revoke acceptance. Moving from inherited pipes to a named endpoint without peer authentication would exchange this issue for another security gap.

## Reproduction

Close project companion/fixture processes before packaging. Build with the checked-in packaging script, verify its receipt, then run:

```sh
python3 scripts/permission-attribution.py --evidence docs/evidence/permission-comparison-NEW.json
```

The helper first verifies the packaged source receipt, then calls `--permission-probe` through both launch modes. That flag exits before constructing the normal companion delegate, journal, writer lock, event monitor or session, and requests no permission. It prints only bundle/process metadata and permission booleans. The Launch Services invocation uses private temporary stdout/stderr files and no visible app window. The evidence path must not exist. A measured mismatch is a diagnostic result, not an acceptance pass.

The first comparison attempt used the previous package after packaging had refused an active fixture, and timed out. It is retained as a failed run; only attempt 2 used the package containing the probe. Always verify packaging completion before executing new flags.

Attempts 3 and 4 independently reproduced the same permission difference; attempt 4 includes package-receipt admission. Final Debug and Release suites both passed 227 cases / 2448 assertions / zero failures.
