#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p docs/evidence
# Do not launch companion/fixture processes or call UI/permission APIs here.
# Fresh dependent objects avoid stale public enum layouts in incremental builds.
swift package clean
swift build > docs/evidence/debug-build.log 2>&1
swift run computer-use-selftest > docs/evidence/selftest.log 2>&1
cat docs/evidence/selftest.log
schema_python="${MILYONUS_SCHEMA_PYTHON:-$PWD/.tools/schema-venv/bin/python}"
if [[ ! -x "$schema_python" ]]; then
    printf 'Schema validator missing. Create .tools/schema-venv and install scripts/schema-requirements.lock.\n' >&2
    exit 1
fi
"$schema_python" scripts/validate-schemas.py > docs/evidence/schema-conformance.json
python3 scripts/test-package-dev.py > docs/evidence/package-guard-tests.log 2>&1
./scripts/build-apps.sh > docs/evidence/package-build.log 2>&1
./scripts/build-apps.sh --verify-receipt > docs/evidence/package-receipt-verification.json
printf 'Background checks passed. No native app was launched; GUI/provider acceptance is separate.\n'
