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
parser.add_argument('--typed', action='store_true')
parser.add_argument('--approval', action='store_true', help='Await manual native approval; launches only project fixture and companion')
args = parser.parse_args()
if args.approval and not args.typed:
    parser.error('--approval requires --typed')
root = Path(__file__).resolve().parent.parent
output = Path(args.evidence)
if output.exists():
    raise SystemExit('Evidence already exists')
record = {'suite': 'packaged-companion-xpc-lifecycle', 'status': 'failed',
          'startedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'limitations': ('Development signing; manual native approval lifecycle, zero desktop effects.' if args.approval else 'Development signing; unapproved sessions only.') + ' No TCC revoke or production distribution acceptance.'}

def run(argv, timeout=30):
    return subprocess.run(argv, check=True, capture_output=True, text=True, timeout=timeout, cwd=root)

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
    fixture = None
    if args.approval:
        if subprocess.run(['pgrep', '-x', 'ComputerUseFixture'], capture_output=True).returncode == 0:
            raise RuntimeError('Existing fixture detected; no launch attempted')
        fixture = subprocess.Popen([str(root / 'build/ComputerUseFixture.app/Contents/MacOS/ComputerUseFixture')],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    with tempfile.TemporaryDirectory(prefix='milyonus-companion-xpc-') as folder:
        folder = Path(folder)
        client = folder / 'client'
        objects = sorted((build / 'ComputerUseIPC.build').glob('*.swift.o'))
        if args.typed:
            objects += sorted((build / 'ComputerUseClient.build').glob('*.swift.o')) + sorted((build / 'ComputerUseContracts.build').glob('*.swift.o'))
        source = 'TypedSessionClient.swift' if args.typed else 'CompanionSessionClient.swift'
        run(['swiftc', '-swift-version', '6', '-parse-as-library', '-I', str(build / 'Modules'),
             str(root / 'Experiments/XPCPeerProbe' / source),
             *map(str, objects), '-o', str(client)])
        run(['codesign', '--force', '--sign', '-', str(client)])
        label = 'com.milyonus.computeruse.lifecycle.' + uuid.uuid4().hex
        domain = 'gui/' + str(os.getuid())
        plist = folder / 'service.plist'
        plist.write_bytes(plistlib.dumps({'Label': label, 'ProgramArguments': [str(companion),
            '--broker-development', label, pin(client)], 'MachServices': {label: True},
            'StandardOutPath': str(folder / 'stdout'), 'StandardErrorPath': str(folder / 'stderr')}))
        run(['launchctl', 'bootstrap', domain, str(plist)])
        try:
            record['result'] = json.loads(run([str(client), label, pin(companion)] + (['approval'] if args.approval else []), timeout=140 if args.approval else 30).stdout)
            if record['result'].get('status') != 'passed':
                raise RuntimeError('Lifecycle did not pass')
        finally:
            run(['launchctl', 'bootout', domain + '/' + label])
            record['temporaryJobRemoved'] = True
        record['status'] = 'passed-approved-lifecycle' if args.approval else 'passed-unapproved-lifecycle'
except Exception as error:
    record['errorType'] = type(error).__name__
    record['error'] = str(error)[:500]
    if isinstance(error, subprocess.CalledProcessError):
        record['diagnostic'] = error.stderr[-2000:]
finally:
    if 'fixture' in locals() and fixture is not None and fixture.poll() is None:
        fixture.terminate()
        try:
            fixture.wait(timeout=5)
        except subprocess.TimeoutExpired:
            fixture.kill(); fixture.wait(timeout=5)
    record['finishedAt'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    output.write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(record))
raise SystemExit(0 if record['status'] in ['passed-unapproved-lifecycle', 'passed-approved-lifecycle'] else 1)
