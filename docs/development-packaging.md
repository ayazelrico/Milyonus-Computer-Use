# Development packaging safeguards

`./scripts/build-apps.sh [debug|release]` delegates to `scripts/package-dev.py`. This is local ad-hoc packaging, not a production installer or notarized release.

The packager holds an exclusive non-blocking file lock for the run. Before building and again before publication, it reads process executable names with `ps -axo comm=` and refuses if `MilyonusComputerUse` or `ComputerUseFixture` is running. It does not read process arguments, stop processes, activate apps or request permissions. A failed process inventory is an error, not evidence that apps are stopped. Same-named executables elsewhere also conservatively block packaging.

Both apps are built in a private temporary staging directory under `build/`. Each staged bundle receives metadata, an ad-hoc signature and strict signature verification before either destination is changed. Executable bytes in a running process are never deliberately overwritten in place.

Publication moves the old bundle to a recovery path, then renames the complete staged bundle into place. If that rename fails, the old bundle is restored. On failure the staging directory is retained, including previous bundles, even if restoration itself fails. Inspect the printed recovery path before manually resolving a failed run. Successful publication removes that run's staging material.

Limitations:

- The two directory renames are not an atomic swap, and publishing two apps is not an atomic transaction. A failure can leave one app updated and the other unchanged; retained previous bundles support recovery.
- Process checks have a check/use race: another program or a person could launch an app after a check. The packaging lock only coordinates cooperating packaging runs. Do not launch the fixture or companion during packaging.
- SIGKILL or host power loss can interrupt publication. Staging leftovers are intentionally not automatically deleted on the next run.
- This does not establish Developer ID identity, notarization, production upgrade safety or native acceptance.

`python3 scripts/test-package-dev.py` runs headless checks for process-name admission, inventory failure, complete directory publication, rollback and retained recovery material. Tests use temporary synthetic files and do not launch native apps. Actual packaging evidence is separate in `docs/evidence/package-build.log`.

## Lock and destination admission checks

The lock must be a regular file owned by the current user, with one hard link and no group/other permissions. Symlinks are not followed, and non-blocking open prevents a special file such as a FIFO from hanging admission. All existing app destinations must be real directories, not symlinks or ordinary files; both are checked before building and before publication.

The headless suite now includes a real second Python process holding the packaging lock, verifies refusal while held and reacquisition after release, and exercises unsafe lock files, invalid destinations and simultaneous publication/restore failures. Only temporary synthetic files and an owned Python child are used. No fixture/companion is launched. Process-name refusal itself remains tested with a synthetic process inventory; this is not a native application lifecycle acceptance test.

## Full orchestration regression scenarios

The packaging suite also calls the real `main` workflow against temporary synthetic binaries and existing synthetic app directories, while substituting Swift/codesign/process-inventory results. It tests every signing/verification failure position, either missing source binary, a process appearing after staging, an invalid second destination, and a successful complete publication with metadata and staging cleanup.

These tests establish orchestration behavior under injected tool outcomes. They do not prove that a real codesign failure, application launch race or machine crash behaves identically. Actual ad-hoc packaging is recorded separately. `verify-background.sh` runs this suite before actual packaging; `verify.sh` inherits it through that background workflow.

## Read-only recovery inventory

Run `./scripts/build-apps.sh --recovery-status` to print a JSON inventory of candidate `.package-*` directories. It does not build, sign, restore, delete, create a lock, start an app or read file contents. It checks only the known staged/previous bundle names and reports their filesystem types. Directory descriptors and no-follow opens prevent a directory-to-symlink replacement from redirecting child inspection.

The scan stops after 1,000 build-directory entries or 100 candidates and sets `truncated` when it reaches a limit. Results are a non-atomic snapshot; a candidate may belong to an active packager rather than a failed run. `signatureVerified` is always false: directory presence is not proof of integrity, completeness or safe restoration. This command intentionally performs no automatic recovery or cleanup. Missing output directories return an empty inventory without creating them.

## Package receipt

After both staged apps pass signature verification, the packager prepares `build/package-receipt.json`. It records the configuration, UTC creation time, SHA-256 and size of each signed executable and Info.plist, plus hashes of Package.swift and Swift files under Sources. Source snapshots taken before the build and before publication must match; a mismatch aborts publication.

The receipt is replaced only after both app directories have been published. Earlier failures preserve the old receipt. Because publishing apps and replacing the receipt are not a single transaction, a failed/interrupted run can leave an old receipt alongside new binaries. Always compare the recorded hashes with actual files before relying on the record. Source changes after the final snapshot, change-and-revert races, toolchain differences and unlisted resource/build inputs are not ruled out.

This is a local consistency record, not a signed attestation or proof of reproducible compilation. Receipt hashing rejects final-component symlinks, special files, files over 128 MiB and changes detected during hashing. It does not authenticate the local machine or grant native acceptance. Signature verification remains separately recorded in the packaging log.

### Verify a receipt

Run `./scripts/build-apps.sh --verify-receipt` for a read-only comparison of the four known package files and current Swift/manifest inputs. It prints JSON with per-file matches and `sourceInputsMatch`, returning zero only for `status: matched`. A mismatch returns nonzero. Invalid/missing/oversized receipts and inaccessible files also fail; they are never reported as matches.

Receipt admission rejects duplicate JSON members, unsupported versions/algorithms/configurations, malformed digest records and records over 1 MiB. The writer applies the same size bound before app publication. Paths in the receipt never select files to open: package locations are fixed, and source inputs are independently enumerated from the repository. Descriptor-relative package opens refuse symlinks in intermediate directories and final files.

Verification does not rebuild, repair, sign, delete, restore or launch anything. It is a consistency snapshot, not fresh codesign verification, an authenticated attestation, or proof of native acceptance. The background workflow now runs it after packaging and stops on failure.
