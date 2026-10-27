# Evidence index

Evidence is local to this checkout and host. A log file's existence is not proof of a passing test; inspect its terminal result and the matching build.

- `debug-build.log`: latest debug compile output.
- `package-build.log`: latest development packaging and ad-hoc signature verification.
- `selftest.log`: standalone contract/core assertions and exit summary.
- `protocol-smoke.json`: real MCP-pipe checks without native approval.
- `client-smoke.json`: Swift SDK handshake/session/cancel checks.
- `doctor.json`: CLI invocation permission snapshot.
- `capture-probe.json`: actual ScreenCaptureKit capture metadata, if successful.
- `live-fixture.json`: latest live run status, checks, UTC timestamps and tested binary SHA-256. Only `status: passed` is accepted; a running/failed record is not a pass. Earlier records without a status predate this evidence format.
- `verification-summary.log`: aggregate offline verification output.

Earlier `swift-test.log` records the missing XCTest module in the installed Command Line Tools. It is retained as a toolchain limitation, not a passing test.

Early live attempts stopped before mutation because the fixture was not foreground, lacked a discoverable active window, or the session was paused. Packaging initially copied over a running executable; packaging now replaces the executable inode. UI automation also encountered stale app bindings after relaunch. These observations motivated fresh process binding and retained focus checks. They do not count as successful native task runs.

Native approval driven by a test controller must be labeled as automation, not represented as proof of a physical user's approval. A user-operated native approval is separately described when it occurs.

- `release-build.log` and `release-selftest.log`: optimized compilation and standalone test results. A full Release build may compile the companion executable; these commands do not launch or repackage a native companion app.
- `source-manifest.json`: source and script SHA-256 hashes for the recorded verification snapshot. Native evidence independently identifies the exact companion binary it executed.

- `live-fixture-semantic-keyboard-heartbeat.json`: isolated native heartbeat deadline/reason acceptance, including Unicode input and semantic saves.
- `live-fixture-pointer-keyboard.json`: latest native pointer/keyboard run, with its actual iteration count.
- `sdk-agent-attempt-metadata.json`: latest SDK run status, exact companion/client hashes, exit code and synthetic-versus-provider scope.
- `sdk-agent-fixture.json`: deterministic real Swift-SDK/agent-loop run, with an 18-second synthetic planning delay. `realInference: false` is intentional; this does not prove provider compatibility. The latest attempt passed with one action and independent completion verification; earlier approval/focus failures remain documented.
- `regression-findings-2026-10-25.md`: failed/interfered runs and limits of subsequent acceptance.

- `schema-conformance.json`: 25 independent Draft 2020-12 checks using actual Swift wire fixtures. Runtime-only byte limits and authorization remain separate.
- `background-verification.log`: checks executed without launching native app windows; does not include MCP subprocess or GUI acceptance.

- `anthropic-preflight.json`: real text-only API authentication/model response; zero desktop actions.
- `anthropic-live-planner.json`: real provider action/finish proposal contract check against synthetic observations; not native acceptance.
- `anthropic-agent-fixture.json`: live provider desktop pilot outcome; a TIMEOUT/error is not accepted.

- `ultra-integration-build.log`: build of the modified Agent Ultra checkout with the local harness package dependency. Existing unrelated compiler warnings remain visible.
- `ultra-integration-selftest.log`: complete headless Ultra regression suite, 3293 passed / 0 failed; not GUI acceptance.
- `ultra-integration-manifest.json`: exact hashes of the host files modified by this integration and the tested host binary.

- `ultra-preview-lifecycle.json` and `ultra-preview-live.log`: controller-operated pending-session Stop and window-close evidence in the isolated preview, without native approval or mutation. Binary hash is recorded.
- `ultra-preview-build.log` / `ultra-preview-selftest.log`: latest host build and full regression result after preview isolation/lifecycle fixes.
- `ultra-preview-selftest-aborted.log`: retained failed test attempt (exit 134) that instantiated AppKit panel cleanup in the headless runner; replaced with a pure decision-rule regression. It is not passing evidence.
- `ultra-preview-package.log`: independent ad-hoc preview packaging; does not replace the installed Ultra app.


- client-transport.md: current synthetic-child pipe, response admission, cancellation, backpressure, timeout and duplicate-member evidence with native limitations.
- journal-recovery.md: journal admission, failure injection and isolated SIGKILL recovery boundaries.
- selftest-before-nonblocking-fixture-fix.log and selftest-before-inherited-output-fixture-fix.log: retained failed fixture expectations from nonblocking-I/O development; not passing evidence.
- ../security/review.md: consolidated development findings and remaining release blockers; not an independent audit.

- `../gesture-execution.md`: CU-018 bounded gesture construction and opt-in fixture scope. Current Debug/Release logs contain 156 cases / 1329 assertions / zero failures. Gesture coverage is synthetic; the optional native layout has only been compiled.

- Current scroll integration: clean Debug and Release logs each contain 160 cases / 1372 assertions / zero failures; `schema-conformance.json` contains 36 passing checks. Tests include bounded contracts, journal routing/idempotency, uncertain-effect pause and synthetic pipe response correlation. No native scroll run or packaging was performed.

- Fixed fixture drag adds synthetic receipt/counter/endpoint checks, method admission, duplicate suppression, uncertain-effect persistence, held-button cancellation, and SDK response correlation. Dedicated `drag.schema.json` is included in independent schema validation. Native gesture acceptance is still pending.

- Latest fixed-drag source: clean Debug and optimized Release logs each report 165 cases / 1424 assertions / zero failures. Independent schema validation reports 42 checks passed.

- `ComputerUseAcceptance` runner coverage is synthetic: success uses fake observations; negative cases assert that no subsequent mutation is dispatched. The explicit native gesture CLI is prepared but unexecuted. No JSON report claiming live gesture acceptance was created.

- Latest acceptance-runner validation: Debug and optimized Release logs each report 170 cases / 1454 assertions / zero failures. Independent wire schemas: 42 passed. No native run is implied.

- Latest P4 capability-discovery source: Debug and Release logs each report 174 cases / 1495 assertions / zero failures. `schema-conformance.json` reports 51 checks passed. `../capability-discovery.md` describes compatibility limits; no native session was opened.

- Latest negotiated-dispatch source: Debug and optimized Release logs each report 177 cases / 1509 assertions / zero failures. Synthetic clients verify fresh limits, disabled-feature admission, no replay and discovery-independent cancellation. Native acceptance remains open.

- Latest gesture geometry source: Debug and Release logs each report 180 cases / 1526 assertions / zero failures. `gesture-package.log` records updated ad-hoc bundles and strict signature checks, not native execution or notarization.

- `package-guard-tests.log`: six headless Python process-admission/publication/recovery checks. `package-build.log`: actual staged ad-hoc packaging with strict signature verification. These do not prove native input or production installation acceptance. Swift regression remains 180 cases / 1526 assertions / zero failures.

- Packaging admission update: `package-guard-tests.log` now records ten passing headless tests, including real cross-process lock contention/release and synthetic rollback failure. `package-build.log` records actual staged ad-hoc packaging, without app launch.

- `package-guard-tests.log` now contains 15 headless tests. Full packaging orchestration cases substitute external tools in temporary repositories; their success messages are synthetic and do not count as actual signature evidence. Actual packaging remains in `package-build.log`.

- `background-verification.log`: completed clean background workflow after full packaging-orchestration tests (180 Swift cases, 1526 assertions, 51 schema checks, 15 Python tests and actual development packaging). No GUI/provider acceptance is implied.

- Recovery inventory: `package-guard-tests.log` now records 20 passing headless tests. `packaging-recovery-status.json` is the actual read-only snapshot (zero candidates, signatures unverified). No restoration, cleanup or native input occurred.

- Package receipt increment: 24 passing headless packaging tests; `package-receipt-check.json` records actual matching hashes for four package files and 32 Swift/manifest inputs. `build/package-receipt.json` is a local consistency record, not signed attestation or native execution evidence.

- Receipt verification: `package-receipt-verification.json` records the real read-only comparison of four package files and 32 source inputs. `package-guard-tests.log` includes negative receipt/CLI cases; synthetic pipeline signatures are not actual signing evidence.

- P2 capture geometry: Debug/Release suites report 184 cases / 1571 assertions / zero failures; wire-schema checks remain 51. Native capture identity/cancellation changes are compiled only. See `../capture-geometry.md`; no new image was captured.

- P2 capture deadline and selection: latest Debug/Release suites report 191 cases / 1628 assertions / zero failures. Monotonic deadline and complete-enumeration window policy tests use synthetic values; the native capture route compiles but has no new live acceptance. Actual development packaging passed; `package-receipt-verification.json` matches four package files and 35 source inputs. No native application was launched.

- P2 AX observation admission: `debug-build.log`, `selftest.log`, `release-build.log` and `release-selftest.log` contain the latest traversal/session-boundary validation. Tests use synthetic clocks and drivers; no native AX acceptance is inferred. `package-receipt-verification.json` matches four packaged files and 36 source inputs after rebuilding the development bundles. See `../accessibility-observation.md` for limits and pending native work.

- P3 execution admission: latest Debug/Release suites pass 201 cases / 2026 assertions / zero failures. Synthetic preflight/journal timing and cancellation tests prove callback non-entry and persisted refusal receipts for their injected scenarios. Schema checks remain 51/51; actual development packaging and receipt verification passed (four package files, 36 source inputs). No native interruption test or provider call was performed.

- P3 late-completion verification: latest Debug/Release suites pass 204 cases / 2096 assertions / zero failures. Fake-driver/clock tests cover late callback verification and immutable normalized receipts; no native interruption acceptance is claimed. Schema checks pass 51/51; development package receipt matches four files and 36 source inputs.

- Action-result consistency: `selftest-result-validation-first-attempt.log` preserves a failed 208-case Debug run with an inherited-stdout test timeout. The unchanged Debug rerun passed 208 cases / 2189 assertions; the timeout's root cause remains unresolved. Independent schema checks now total 54. Current build/test logs and `../STATUS.md` distinguish latest results from this retained failure.

- Result-consistency final verification: latest Debug/Release builds and suites passed (208 cases / 2189 assertions / zero failures), with 54 schema checks and matching development package receipts. The retained earlier timeout remains unresolved; no native acceptance is inferred.

- Inherited-output investigation: `inherited-output-stress-debug.log` and `inherited-output-stress-release.log` each record 20 cases / 60 assertions / zero failures. They repeat the original shutdown assertions without relaxed deadlines, using only synthetic pipe children. The earlier timeout remains unresolved; see `../stdio-timeout-investigation.md`. No native package rebuild was needed for these test-only changes; the existing receipt was reverified.

- SDK opening lifecycle: latest Debug/Release suites pass 210 cases / 2204 assertions / zero failures. Held-reply synthetic tests verify concurrent-open refusal and cancellation fencing without native approval or GUI activity. Schema checks remain 54/54; actual development packaging and receipt verification passed (four files, 36 source inputs). This does not resolve the earlier inherited-output timeout.

- Heartbeat ownership: latest Debug/Release suites pass 213 cases / 2219 assertions / zero failures. Held-status synthetic tests cover cancellation, replacement with reused IDs and current-owner renewal. Schemas pass 54/54; development packages and receipt checks passed. Native timer/GUI acceptance is separate, and the prior inherited-output timeout is not resolved by these results.

- Observation admission: latest Debug/Release suites pass 216 cases / 2250 assertions / zero failures. Contract, fake-driver and synthetic stdio tests cover structural and byte-budget rejection. Schemas pass 57/57; development packaging/receipt checks passed (four files, 37 source inputs). No native observation or provider acceptance is claimed; the earlier inherited-output timeout remains unresolved.

- Session consistency: latest Debug/Release suites pass 219 cases / 2330 assertions / zero failures. State/reason matrix, injected-clock core transitions and synthetic SDK reply tests passed. Schemas pass 59/59; package receipt matches four files and 38 source inputs. No native approval or GUI/provider acceptance is claimed, and the prior inherited-output timeout remains unresolved.

- Agent adapter boundary: final Debug/Release suites pass 222 cases / 2370 assertions / zero failures. `selftest-agent-boundary-first-attempt.log` retains the initial failure caused by a positive fake adapter reusing observation IDs; that fixture now emits fresh IDs while dedicated rejection tests remain. Schemas remain 59/59; package receipts match four files and 38 source inputs. No native/provider acceptance is inferred.

- Provider input admission: latest Debug/Release suites pass 223 cases / 2418 assertions / zero failures. Direct-adapter synthetic tests reject invalid contexts before credential reads or transport sends for both providers. Schemas remain 59/59; package receipt matches four files and 39 source inputs. No real inference or native acceptance is implied.

- Provider-response validation: final Debug/Release suites pass 227 cases / 2448 assertions / zero failures; schemas remain 59/59 and the development receipt matches four files and 39 source inputs. `selftest-provider-response-first-attempt.log` preserves two unexpected existing stdio-case timeouts. Expanded payload-free diagnostics and a deliberate unanswered-request test do not establish their root cause. No native/provider acceptance is implied.

- `native-gestures-2026-10-27-attempt-1.json` and `.log`: actual approved native attempt, failed with `UNSUPPORTED_CAPABILITY`. A read-only AX probe found missing scroll `AXEnabled`. The fixture-only fix has passing Debug regression (227/2448) and updated packaging, but no second native acceptance yet; Release logs predate this fix.

- `native-gestures-2026-10-27-attempt-2.json` and `.log`: actual manually approved two-action native fixture acceptance passed. Scrollbar 1 → 0.7214484679665738; drag count 0 → 1 with independent verification and successful session cancellation. Exact binary hashes are recorded; no real inference or broader interruption acceptance is implied.
