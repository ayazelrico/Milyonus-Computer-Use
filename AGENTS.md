# Repository working instructions

- Keep source, comments, UI, errors, tests, and new implementation documentation in English.
- Read `plan.md`, `Plan Actions.md`, and `docs/STATUS.md` before expanding scope. Historical planning text is Turkish; implementation documentation is English.
- Preserve the user's Agent Ultra checkout. Integration must use a narrow adapter and retain its existing sandbox, plain-chat and hidden-beta behavior.
- Never claim a phase passed without the actual gate evidence. Keep synthetic, native, provider, and distribution evidence separate.
- Core safety decisions belong outside the model planner. No RPC may create its own native approval.
- Never weaken foreground, target identity, session generation, journal, or permission checks to make an acceptance test pass.
- Run `swift build` and `swift run computer-use-selftest` after meaningful source changes. `scripts/verify.sh` also launches real companion processes and requires no other active companion session.
- GUI tests use the fixture first. Do not use a user's messages, purchases, credentials, or destructive operations as test material.
- The development host has Command Line Tools without XCTest/Testing. Maintain the standalone test runner with nonzero failure exit status.
- Avoid replacing running executable bytes in place. Package via the checked-in script.
- Record limitations in `docs/STATUS.md`; do not silently broaden the supported app or platform list.
