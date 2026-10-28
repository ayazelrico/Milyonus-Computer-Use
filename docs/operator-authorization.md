# Operator authorization for this development session

On 2026-10-28 the user explicitly authorized continuing the planned project tests and asked that Accessibility and AUTHORIZE permissions be treated as already authorized for testing. General authorization to run the fixture, companion and isolated integration tests persists; do not ask for that general authorization again at each commit or test.

The user also explicitly requested that the agent repair the project's Accessibility setting. This authorizes changes to this companion's own registration through the normal macOS UI and restoration of its prior grant after a permission interruption test. It does not authorize changing unrelated applications' permissions or accessing unrelated windows as test content. Password/Touch ID entry remains with the user if macOS requests it.

Authorization to test is separate from measured system state. Record AXIsProcessTrusted/Screen Recording results from the independently launched executable. Do not replace a false result with true in a test fixture or evidence file. Ad-hoc rebuilds on this host have invalidated effective grants even while Settings showed an enabled same-name entry.

Native session approval remains governed by AGENTS.md: "No RPC may create its own native approval." A ready session must result from the actual native control and retain its existing scope, expiry and generation. Never pre-mark future sessions approved, auto-click the approval control, disable physical-input pause, or broaden the application policy to remove test interaction.

If a live acceptance needs a new native session, prepare and launch it first, request only that concrete native interaction, and continue independent background work while it is pending. Commits are checkpoints, not a reason to request renewed general authorization.
