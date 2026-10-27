#!/usr/bin/env python3
"""Compare effective permission probes under direct and Launch Services startup.

No sessions, UI windows, permission prompts or TCC modifications are requested.
The comparison cannot identify the responsible process or prove denied AX operations.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--evidence', required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
app = root / 'build/MilyonusComputerUse.app'
binary = app / 'Contents/MacOS/MilyonusComputerUse'
destination = Path(args.evidence)
if destination.exists():
    raise SystemExit('Refusing to overwrite evidence')

def decode(data):
    if len(data) > 16384:
        raise ValueError('Probe output exceeds limit')
    value = json.loads(data)
    if (value.get('suite') != 'companion-permission-probe'
            or value.get('sessionOpened') is not False
            or value.get('desktopActions') != 0
            or value.get('permissionRequested') is not False
            or value.get('bundleID') != 'com.milyonus.computeruse'
            or set(value.get('permissions', {})) != {'accessibility', 'screenRecording'}
            or not all(type(x) is bool for x in value['permissions'].values())):
        raise ValueError('Unexpected probe result')
    return value

record = {'suite': 'permission-launch-comparison', 'startedAt': datetime.now(timezone.utc).isoformat(),
          'binarySHA256': hashlib.sha256(binary.read_bytes()).hexdigest(), 'status': 'failed',
          'scope': 'Effective trust reporting only; no approval, session or desktop action.'}
try:
    # Refuse stale packaged sources before invoking a flag an old binary may ignore.
    receipt = subprocess.run(['python3', str(root / 'scripts/package-dev.py'), '--verify-receipt'],
                             cwd=root, capture_output=True, timeout=20, check=True)
    if json.loads(receipt.stdout).get('status') != 'matched':
        raise ValueError('Package receipt did not match')
    direct = subprocess.run([str(binary), '--permission-probe'], capture_output=True, timeout=20, check=True)
    record['directChild'] = decode(direct.stdout)
    with tempfile.TemporaryDirectory(prefix='milyonus-permission-probe-') as folder:
        out = Path(folder) / 'stdout.json'
        err = Path(folder) / 'stderr.log'
        subprocess.run(['/usr/bin/open', '-g', '-W', '-n', '--stdout', str(out), '--stderr', str(err),
                        str(app), '--args', '--permission-probe'], capture_output=True, timeout=25, check=True)
        record['launchServices'] = decode(out.read_bytes())
    record['permissionsMatch'] = record['directChild']['permissions'] == record['launchServices']['permissions']
    record['status'] = 'measured'
except Exception as error:
    record['errorType'] = type(error).__name__
finally:
    record['finishedAt'] = datetime.now(timezone.utc).isoformat()
    destination.write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(record))
raise SystemExit(0 if record['status'] == 'measured' else 1)
