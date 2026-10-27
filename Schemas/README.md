# Version 1 wire schemas

`v1` describes the currently implemented fixture development protocol: action requests, observations, sessions, action results and heartbeat requests. The schema namespace is versioned; this is not a claim that the larger planned policy/grant or artifact contracts are complete.

The independent Draft 2020-12 test reads actual JSON emitted by `milyonus-cu contract-fixtures`, validates every schema, then tests invalid enums, unknown fields, invalid timestamps, generation/PID bounds, NUL text, oversized trees and invalid rectangles. It uses pinned `jsonschema[format]` test dependencies, not a validator implemented alongside the Swift models.

```sh
python3 -m venv .tools/schema-venv
.tools/schema-venv/bin/pip install -r scripts/schema-requirements.lock
.tools/schema-venv/bin/python scripts/validate-schemas.py
```

The lock file contains the complete installed test dependency set. `.tools/` is ignored. The runtime Swift package still has no external package dependencies.

JSON Schema string lengths count characters, not UTF-8 bytes or UTF-16 units. Swift additionally enforces action UTF-8 and native-text UTF-16 limits. Application authorization, freshness, current focus, heartbeat expiry and idempotency also remain runtime checks; passing a schema never grants access.

The output schemas are intentionally strict. Swift's synthesized Codable decoder may ignore unknown object fields, so MCP validates request field names separately. Do not use Codable alone as a substitute for the request boundary.

Experimental vertical scrolling has a dedicated `scroll.schema.json`. Its `scrollPixels` field is required only for `kind: scroll`, nonzero and bounded to ±2,000; press/setValue reject that field. This schema does not establish native acceptance.

Experimental fixed fixture dragging has a dedicated `drag.schema.json`. It accepts no coordinates, duration override, text or scroll delta. Session and native target policy remain mandatory runtime checks.

`capabilities.schema.json` validates the shared version-1 discovery response, including fixture scope, native approval, experimental feature flags and heartbeat/input limits. A valid response never grants a session.
