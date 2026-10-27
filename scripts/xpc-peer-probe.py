#!/usr/bin/env python3
"""Exercise real anonymous XPC signing checks without exposing a desktop service."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import os
import plistlib
import uuid

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--evidence', required=True)
parser.add_argument('--named', action='store_true', help='Use a temporary per-user launchd Mach service; unloaded after each case')
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
source = root / 'Experiments/XPCPeerProbe/main.swift'
output = Path(args.evidence)
if output.exists():
    raise SystemExit('Evidence already exists')
record = {'suite': 'named-xpc-signing-feasibility' if args.named else 'anonymous-xpc-signing-feasibility', 'status': 'failed',
          'startedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'sourceSHA256': hashlib.sha256(source.read_bytes()).hexdigest(), 'cases': [],
          'limitations': 'Ad-hoc hash pin only; no Team ID trust, desktop action, TCC identity or production authentication acceptance. Topology is recorded separately.'}
try:
    with tempfile.TemporaryDirectory(prefix='milyonus-xpc-probe-') as folder:
        executable = Path(folder) / 'probe'
        subprocess.run(['swiftc', '-swift-version', '5', str(source), '-o', str(executable)], check=True, timeout=60)
        subprocess.run(['codesign', '--force', '--sign', '-', str(executable)], check=True, capture_output=True, timeout=20)
        signature = subprocess.run(['codesign', '-dv', '--verbose=4', str(executable)], check=True, capture_output=True, text=True, timeout=10)
        match = re.search(r'^CDHash=([0-9a-f]{40})$', signature.stderr, re.M)
        if not match:
            raise RuntimeError('Missing CDHash')
        good = 'cdhash H"' + match.group(1) + '"'
        bad = 'cdhash H"' + '0' * 40 + '"'
        record['binarySHA256'] = hashlib.sha256(executable.read_bytes()).hexdigest()
        record['topology'] = 'temporary-launchd-service' if args.named else 'same-process-anonymous'
        for name, client, server, expected in [
            ('matching-both-peers', good, good, 'replied'),
            ('listener-rejects-client', bad, good, 'rejected'),
            ('client-rejects-server', good, bad, 'rejected')]:
            if args.named:
                label = 'com.milyonus.computeruse.probe.' + uuid.uuid4().hex
                domain = 'gui/' + str(os.getuid())
                plist = Path(folder) / (label + '.plist')
                server_log = Path(folder) / (label + '.stdout')
                plist.write_bytes(plistlib.dumps({'Label': label,
                    'ProgramArguments': [str(executable), '--server', label, client],
                    'MachServices': {label: True}, 'StandardOutPath': str(server_log),
                    'StandardErrorPath': str(Path(folder) / (label + '.stderr'))}))
                subprocess.run(['launchctl', 'bootstrap', domain, str(plist)], check=True, capture_output=True, timeout=10)
                try:
                    run = subprocess.run([str(executable), '--client', label, server], check=True, capture_output=True, text=True, timeout=15)
                    result = json.loads(run.stdout)
                    if name == 'matching-both-peers':
                        # The first client exited. A fresh admitted connection must not inherit its handshake.
                        fresh = subprocess.run([str(executable), '--client-unprimed', label, server],
                                               check=True, capture_output=True, text=True, timeout=15)
                        result['freshConnectionWithoutHandshake'] = json.loads(fresh.stdout)['outcome']
                        if result['freshConnectionWithoutHandshake'] != 'handshakeRequired':
                            raise RuntimeError('Fresh connection inherited handshake admission')
                finally:
                    subprocess.run(['launchctl', 'bootout', domain + '/' + label], check=True, capture_output=True, timeout=10)
                events = server_log.read_text().splitlines() if server_log.exists() else []
                result['serverInvocations'] = events.count('invoked') + events.count('afterHandshake')
                result['postHandshakeInvocations'] = events.count('afterHandshake')
                result['temporaryJobRemoved'] = True
            else:
                run = subprocess.run([str(executable), client, server], check=True, capture_output=True, text=True, timeout=15)
                result = json.loads(run.stdout)
            record['cases'].append({'name': name, **result})
            if result['outcome'] != expected:
                raise RuntimeError('Unexpected signing admission result')
            if result.get('serverInvocations') != (2 if expected == 'replied' else (0 if name == 'listener-rejects-client' else 1)):
                raise RuntimeError('Unexpected exported-method invocation count')
            if args.named and result['postHandshakeInvocations'] != (1 if expected == 'replied' else 0):
                raise RuntimeError('Post-handshake message reached unverified peer')
        record['serverIdentityPreventsFirstRequestDelivery'] = False
        record['status'] = 'passed-limited-probe'
except Exception as error:
    record['errorType'] = type(error).__name__
    record['error'] = str(error)[:200]
finally:
    record['finishedAt'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    output.write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(record))
raise SystemExit(0 if record['status'] == 'passed-limited-probe' else 1)
