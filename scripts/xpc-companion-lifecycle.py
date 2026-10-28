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
import time
import uuid

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--evidence', required=True)
parser.add_argument('--typed', action='store_true')
parser.add_argument('--native-interruption', choices=['baseline', 'stop', 'disconnect', 'window-close', 'focus-loss'])
parser.add_argument('--permission-revoke', action='store_true', help='Observe user-authorized companion permission revocation and refuse a captured action')
parser.add_argument('--fixture-action', action='store_true', help='One approved fixture AX edit and independent verification')
parser.add_argument('--approval', action='store_true', help='Await manual native approval; launches only project fixture and companion')
args = parser.parse_args()
if args.native_interruption:
    args.typed = True
    args.fixture_action = True
if args.permission_revoke:
    args.fixture_action = True
if args.fixture_action:
    args.approval = True
if args.approval and not args.typed:
    parser.error('--approval requires --typed')
root = Path(__file__).resolve().parent.parent
output = Path(args.evidence)
if output.exists():
    raise SystemExit('Evidence already exists')
scope = 'Development signing; unapproved sessions only.'
if args.native_interruption:
    scope = 'Development signing; fixture-only native receiver evidence.'
elif args.permission_revoke:
    scope = 'Development signing; actual companion permission revocation plus possible physical-input pause, zero desktop effects.'
elif args.fixture_action:
    scope = 'Development signing; one manually approved fixture AX edit.'
elif args.approval:
    scope = 'Development signing; manual native approval lifecycle, zero desktop effects.'
record = {'suite': 'packaged-companion-xpc-lifecycle', 'status': 'failed',
          'startedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'limitations': scope + ' No production distribution acceptance.'}

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
    record['fixtureSHA256'] = hashlib.sha256((root / 'build/ComputerUseFixture.app/Contents/MacOS/ComputerUseFixture').read_bytes()).hexdigest()
    fixture = None
    if args.approval:
        if subprocess.run(['pgrep', '-x', 'ComputerUseFixture'], capture_output=True).returncode == 0:
            raise RuntimeError('Existing fixture detected; no launch attempted')
        if not args.native_interruption:
            fixture = subprocess.Popen([str(root / 'build/ComputerUseFixture.app/Contents/MacOS/ComputerUseFixture')],
                                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    with tempfile.TemporaryDirectory(prefix='milyonus-companion-xpc-') as folder:
        folder = Path(folder)
        folder = folder.resolve()
        trace = folder / 'events.ndjson'
        if args.native_interruption:
            fixture = subprocess.Popen([str(root / 'build/ComputerUseFixture.app/Contents/MacOS/ComputerUseFixture'),
                '--gesture-fixture', '--event-trace', str(trace)] + (['--close-on-test-signal'] if args.native_interruption == 'window-close' else (['--hide-on-test-signal'] if args.native_interruption == 'focus-loss' else [])), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            trace_deadline = time.monotonic() + 3
            while not trace.exists() and fixture.poll() is None and time.monotonic() < trace_deadline:
                time.sleep(0.02)
            if not trace.exists():
                raise RuntimeError('Fixture receiver trace unavailable; no approval requested')
        client = folder / 'client'
        objects = sorted((build / 'ComputerUseIPC.build').glob('*.swift.o'))
        if args.typed:
            objects += sorted((build / 'ComputerUseClient.build').glob('*.swift.o')) + sorted((build / 'ComputerUseContracts.build').glob('*.swift.o'))
        source = 'NativeInterruptionClient.swift' if args.native_interruption else ('TypedSessionClient.swift' if args.typed else 'CompanionSessionClient.swift')
        if args.native_interruption:
            objects += sorted((build / 'ComputerUseAcceptance.build').glob('*.swift.o')) + sorted((build / 'ComputerUseCore.build').glob('*.swift.o'))
        run(['swiftc', '-swift-version', '6', '-parse-as-library', '-I', str(build / 'Modules'),
             str(root / 'Experiments/XPCPeerProbe' / source),
             *map(str, objects), '-o', str(client)])
        run(['codesign', '--force', '--sign', '-', str(client)])
        label = 'com.milyonus.computeruse.lifecycle.' + uuid.uuid4().hex
        domain = 'gui/' + str(os.getuid())
        plist = folder / 'service.plist'
        plist.write_bytes(plistlib.dumps({'Label': label, 'ProgramArguments': [str(companion),
            '--broker-development', label, pin(client)] + (['--fixture-actions'] if args.fixture_action else []) + (['--native-fixture-input'] if args.native_interruption else []), 'MachServices': {label: True},
            'StandardOutPath': str(folder / 'stdout'), 'StandardErrorPath': str(folder / 'stderr')}))
        run(['launchctl', 'bootstrap', domain, str(plist)])
        try:
            mode_args = [args.native_interruption, str(trace), str(fixture.pid)] if args.native_interruption else (['revoke' if args.permission_revoke else ('fixture' if args.fixture_action else 'approval')] if args.approval else [])
            record['result'] = json.loads(run([str(client), label, pin(companion)] + mode_args, timeout=230 if args.permission_revoke else (140 if args.approval else 30)).stdout)
            if record['result'].get('status') != 'passed':
                raise RuntimeError('Lifecycle did not pass')
        finally:
            run(['launchctl', 'bootout', domain + '/' + label])
            record['temporaryJobRemoved'] = True
            if args.native_interruption and trace.exists():
                raw = trace.read_bytes()
                if len(raw) > 16384:
                    raise RuntimeError('Receiver trace exceeded bound')
                record['receiverEvents'] = [json.loads(line) for line in raw.splitlines()]
        record['status'] = ('passed-native-input' if args.native_interruption == 'baseline' else 'passed-native-interruption') if args.native_interruption else 'passed-permission-interruption' if args.permission_revoke else ('passed-fixture-action' if args.fixture_action else ('passed-approved-lifecycle' if args.approval else 'passed-unapproved-lifecycle'))
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
raise SystemExit(0 if record['status'] in ['passed-unapproved-lifecycle', 'passed-approved-lifecycle', 'passed-fixture-action', 'passed-permission-interruption', 'passed-native-interruption', 'passed-native-input'] else 1)
