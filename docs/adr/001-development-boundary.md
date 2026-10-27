# ADR 001: Development boundary and permission identity

Date: 2026-10-24. Status: accepted for the development prototype; production topology is not accepted.

The host has macOS 26.6.2 on Apple Silicon and Swift 6.3.3 from Command Line Tools. Its SDK compiles a macOS 14 deployment target. No macOS 14 runtime or Intel machine has been tested. No valid Developer ID signing identity is installed.

The companion is a visible AppKit application. It owns Accessibility requests, session approval, observation, and execution. The CLI is read-only. The fixture is a separate bundled application with explicit Accessibility identifiers. Only its input and local save button are writable. There is no general app control, script executor, shell executor, or network listener.

For the prototype, the caller launches the companion as a direct child with inherited stdio pipes. MCP messages travel over these pipes. This avoids prematurely adding a publicly addressable or same-user socket service. A global advisory lock prevents cooperating companion processes from controlling the desktop simultaneously. It does not authenticate arbitrary processes or defend against same-user malware.

The preferred production XPC broker, peer/code-signature authentication, sandbox transport integration, per-session lease heartbeat, and worker-process isolation remain open. The direct-child transport is not represented as satisfying those requirements. A malicious local process that replaces the fixture or simulates native approval is outside the prototype's demonstrated defenses. Do not broaden the app allowlist until those boundaries have separate evidence.

The MCP surface cannot create a native grant. Opening a session leaves it awaiting approval. The native approval button requires Accessibility and an existing fixture process. The grant expires after five minutes using a monotonic clock. Pause/resume invalidates observations; resume requires a fresh native approval. Sleep, login-session resignation, screen locking, or observed physical keyboard/mouse input pauses a ready session.

The first packaged permission probe reported Accessibility=false and ScreenRecording=true. This observation applies to that invocation and does not prove that every build or helper inherits the same TCC identity. Development bundles are ad-hoc signed, not Developer ID signed or notarized. The user must complete the macOS permission step to unblock native execution acceptance.
