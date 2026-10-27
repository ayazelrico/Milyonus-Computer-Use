#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/verify-background.sh
.build/debug/milyonus-cu doctor > docs/evidence/doctor.json
# These checks launch visible companions. Use verify-background.sh while the user is working.
# Never terminate a user's active session to acquire the process lock.
python3 scripts/protocol-smoke.py > docs/evidence/protocol-smoke.json
.build/debug/milyonus-cu client-check "$PWD/build/MilyonusComputerUse.app/Contents/MacOS/MilyonusComputerUse" > docs/evidence/client-smoke.json
printf 'Automated checks passed. These checks do not grant TCC or prove live GUI execution.\n'
