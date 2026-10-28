#!/usr/bin/env python3
"""Launch only the project companion and check unapproved XPC session lifecycle."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import uuid

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--evidence', required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
output = Path(args.evidence)
if output.exists():
    raise SystemExit('Evidence already exists')
record = {'suite': 'packaged-companion-xpc-lifecycle', 'status': 'failed',
          'startedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'limitations': 'Development signing; unapproved sessions only. No native actions, TCC grant/revoke or production distribution acceptance.'}

def run(argv):
    return subprocess.run(argv, check=True, capture_output=True, text=True, timeout=30, cwd=root)

def pin(path):
    return re.search(r'^CDHash=([0-9a-f]{40})$', run(['codesign', '-dv', '--verbose=4', str(path)]).stderr, re.M).group(1)

try:
    run(['python3', 'scripts/package-dev.py', '--verify-receipt'])
    # Never replace or terminate an existing user's companion session.
    running = subprocess.run(['pgrep', '-x', 'MilyonusComputerUse'], capture_output=True)
    if running.returncode == 0:
        raise RuntimeError('Existing companion detected; no launch attempted')
    build = root / '.build/debug'
    companion = root / 'build/MilyonusComputerUse.app/Contents/MacOS/MilyonusComputerUse'
    record['companionSHA256'] = hashlib.sha256(companion.read_bytes()).hexdigest()
    with tempfile.TemporaryDirectory(prefix='milyonus-companion-xpc-') as folder:
        folder = Path(folder)
        client = folder / 'client'
        run(['swiftc', '-swift-version', '6', '-parse-as-library', '-I', str(build / 'Modules'),
             str(root / 'Experiments/XPCPeerProbe/CompanionSessionClient.swift'),
             *map(str, sorted((build / 'ComputerUseIPC.build').glob('*.swift.o'))), '-o', str(client)])
        run(['codesign', '--force', '--sign', '-', str(client)])
        label = 'com.milyonus.computeruse.lifecycle.' + uuid.uuid4().hex
        domain = 'gui/' + str(os.getuid())
        plist = folder / 'service.plist'
        plist.write_bytes(plistlib.dumps({'Label': label, 'ProgramArguments': [str(companion),
            '--broker-development', label, pin(client)], 'MachServices': {label: True},
            'StandardOutPath': str(folder / 'stdout'), 'StandardErrorPath': str(folder / 'stderr')}))
        run(['launchctl', 'bootstrap', domain, str(plist)])
        try:
            record['result'] = json.loads(run([str(client), label, pin(companion)]).stdout)
            if record['result'].get('status') != 'passed':
                raise RuntimeError('Lifecycle did not pass')
        finally:
            run(['launchctl', 'bootout', domain + '/' + label])
            record['temporaryJobRemoved'] = True
        record['status'] = 'passed-unapproved-lifecycle'
except Exception as error:
    record['errorType'] = type(error).__name__
    record['error'] = str(error)[:500]
    if isinstance(error, subprocess.CalledProcessError):
        record['diagnostic'] = error.stderr[-2000:]
finally:
    record['finishedAt'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    output.write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(record))
raise SystemExit(0 if record['status'] == 'passed-unapproved-lifecycle' else 1)
