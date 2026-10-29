# Capture worker: next bounded implementation slice

Status: design only, 2026-10-29. No new worker capture RPC or image transport is implemented by this document.

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

A missing operator authentication, valid signing identity or physical display is recorded as that specific prerequisite, not bypassed with remembered grants. No change to Agent Ultra, arbitrary application support or automatic approval belongs in this slice.
