# Capture worker: next bounded implementation slice

Status: internal metadata worker components verified, 2026-10-29. Approved broker integration and image transport remain pending.

## Existing evidence and prerequisites

The development AX worker has real approved observations, measured Stop during a fixture AX stall and new-read permission denial/restoration. Local capture has marker/dimension and pre-publication interruption evidence through a diagnostic child. Neither establishes independently launched capture-worker permission or capture-call containment. Current supported target remains the fixture. Developer ID installation/update attribution remains open.

## First executable increment

Start with an independently launched, self-pinned read-only worker returning bounded capture metadata only. Keep the existing worker connection/incarnation/process-slot lifetime. The broker supplies the exact fixture process-start identity and known window ID under an approved session; the collector must require those identities before capture and revalidation rather than selecting any new fixture. No worker may create approval or request OS permission.

Measure the worker's effective Screen Recording permission independently, preserving a false result as refusal. For the initial acceptance, compute a hash and decoded dimensions in the worker and discard pixel bytes; label this metadata-only diagnostic, not an image-capable SDK route. Broker Stop must cancel the pending continuation and retire only the owned child. Test actual framework stalls separately from a delayed test reply.

This increment requires a fixed operation discriminator and typed metadata response distinct from AX observation. Do not relabel frame metadata as an Observation or change the existing AX payload interpretation. Preserve current AX routes and capabilities until new native evidence exists.

## Frame transport decision before image delivery

The existing fixed AX envelope is capped at 262144 bytes. PNG capture currently permits 8 MiB; base64 would increase the payload further. Raising the shared AX parser limit is not an acceptable image transport design.

Before adding image delivery, choose and document a separate authenticated channel with one image per request, explicit byte count, encoding, dimensions, content hash, exact ticket/window/process association and one in-flight reservation. The consumer must bound allocation before decoding and reject trailing, partial, conflicting or duplicate content. Broker admission must recheck ownership, session generation, target identity, permission and deadline before publishing the completed frame. Cancellation must discard partial content and close/reap only owned resources. Avoid caller-provided file paths and persistent raw-frame artifacts.

The first image-capable SDK API must make retention and provider egress explicit. Metadata-only acceptance is insufficient to claim safe pixel transport, image authorization or provider compatibility.

## Acceptance order and stop conditions

1. Compile and validate the typed operation without adding public capabilities.
2. Native approved fixture metadata capture with independently reported helper permission and exact process/window binding.
3. Stop/deadline/connection loss with owned retirement and no late metadata publication.
4. Permission interruption measured for the helper; do not substitute AX permission evidence.
5. Only after selecting frame transport: bounded complete image delivery, marker verification and partial-transfer cleanup.

A missing operator authentication, valid signing identity or physical display is recorded as that specific prerequisite, not bypassed with remembered grants. No change to Example Host, arbitrary application support or automatic approval belongs in this slice.

## Implemented component checkpoint

The separate `--fixture-capture-metadata-worker-v1` role now uses the existing self-derived signature pin, actual parent PID, nonce bootstrap and independent orphan watchdog. It exits before companion UI/session/journal construction. Its first sentinel and fixed request/result kinds differ from AX; capture metadata is never decoded as an AX observation. The shared ticket value retains request/incarnation/connection/session/generation/process-start/window/budget binding.

CaptureWorkerWire is capped at 16384 bytes, rejects unknown/duplicate keys and requires an explicit nonzero window. Replies contain either bounded validated metadata or a classified refusal. The metadata includes SHA-256, PNG byte count, dimensions, bounds, capture time and the worker's measured Screen Recording success; it contains no pixels or filesystem path. Elapsed report values are rounded down to nanoseconds, while request budgets retain exact wire validation. Parent admission must still check real elapsed time and freshness rather than trusting this report.

FixtureCaptureWorker calls capture with the requested exact process-start/window identity and bounded budget, hashes PNG data locally and discards it after returning metadata. Missing permission is queried by the worker and never replaced by a broker grant. Existing unbound public diagnostic capture retains its behavior. No new public SDK capability or companion RPC is exposed yet.

An actual independently launched signed-role probe passed non-fixture and changed-start refusals through the authenticated capture protocol; both children retired and the temporary service was removed. This uses only the probe's own non-fixture PID and captures no image. Positive native capture-worker permission, broker-owned approved dispatch/cancellation and metadata publication are still required. The next integration must connect this distinct reply type to the retained process slot and broker's session admission without coercing it into an Observation.
