#!/usr/bin/env python3
"""Test the compiled ComputerUseIPC library across separate ad-hoc signed processes."""
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
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--evidence', required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
output = Path(args.evidence)
if output.exists():
    raise SystemExit('Evidence already exists')
record = {'suite': 'sdk-named-xpc', 'status': 'failed', 'cases': [],
          'startedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'limitations': 'Read-only handshake; exact development CDHash pins. No desktop actions, native grants, TCC or Developer ID acceptance.'}

def run(argv, **kwargs):
    return subprocess.run(argv, check=True, capture_output=True, text=True, timeout=60, **kwargs)

try:
    run(['swift', 'build'], cwd=root)
    build = Path(run(['swift', 'build', '--show-bin-path'], cwd=root).stdout.strip())
    objects = sorted((build / 'ComputerUseIPC.build').glob('*.swift.o'))
    if {p.name for p in objects} != {"AuthenticatedBrokerConnection.swift.o", "PeerIdentity.swift.o", "BrokerHandshakeListener.swift.o"}:
        raise RuntimeError('Unexpected IPC object inventory')
    record['libraryObjects'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in objects}
    with tempfile.TemporaryDirectory(prefix='milyonus-sdk-xpc-') as folder:
        folder = Path(folder)
        binaries, pins = {}, {}
        for name in ['SDKPeer', 'SDKClient', 'SDKListener']:
            binary = folder / name
            run(['swiftc', '-swift-version', '6', '-parse-as-library', '-I', str(build / 'Modules'),
                 str(root / 'Experiments/XPCPeerProbe' / (name + '.swift')),
                 *map(str, objects), '-o', str(binary)])
            run(['codesign', '--force', '--sign', '-', str(binary)])
            signature = run(['codesign', '-dv', '--verbose=4', str(binary)])
            pins[name] = re.search(r'^CDHash=([0-9a-f]{40})$', signature.stderr, re.M).group(1)
            binaries[name] = binary
        record['binarySHA256'] = {k: hashlib.sha256(v.read_bytes()).hexdigest() for k, v in binaries.items()}
        scenarios = [('matching', 'echo', False, False, 'authenticated', 1),
                     ('wrong-client', 'echo', True, False, 'authenticationFailed', 0),
                     ('wrong-server', 'echo', False, True, 'authenticationFailed', 1),
                     ('wrong-nonce', 'wrongNonce', False, False, 'protocolMismatch', 1),
                     ('wrong-version', 'wrongVersion', False, False, 'protocolMismatch', 1),
                     ('silent-peer', 'silent', False, False, 'timeout', 1),
                     ('client-cancellation', 'silent', False, False, 'cancelled', None),
                     ('peer-exit', 'disconnect', False, False, 'authenticated', 1),
                     ('library-listener-close', 'library', False, False, 'authenticated', 0),
                     ('library-listener-rejects-client', 'library', True, False, 'authenticationFailed', 0)]
        for name, mode, wrong_client, wrong_server, expected, calls in scenarios:
            label = 'com.milyonus.computeruse.sdkprobe.' + uuid.uuid4().hex
            domain = 'gui/' + str(os.getuid())
            plist = folder / (label + '.plist')
            log = folder / (label + '.stdout')
            server_name = 'SDKListener' if mode == 'library' else 'SDKPeer'
            plist.write_bytes(plistlib.dumps({'Label': label, 'ProgramArguments': [str(binaries[server_name]), label,
                '0' * 40 if wrong_client else pins['SDKClient'], mode], 'MachServices': {label: True},
                'StandardOutPath': str(log), 'StandardErrorPath': str(folder / (label + '.stderr'))}))
            run(['launchctl', 'bootstrap', domain, str(plist)])
            try:
                result = json.loads(run([str(binaries['SDKClient']), label,
                    '0' * 40 if wrong_server else pins[server_name],
                    'cancel' if name == 'client-cancellation' else mode]).stdout)
                if mode == 'library':
                    deadline = time.monotonic() + 2
                    while time.monotonic() < deadline:
                        if log.exists() and 'disconnected' in log.read_text().splitlines():
                            break
                        time.sleep(0.01)
                    result['disconnectCallbacks'] = log.read_text().splitlines().count('disconnected') if log.exists() else 0
            finally:
                run(['launchctl', 'bootout', domain + '/' + label])
            result.update(name=name, temporaryJobRemoved=True,
                          helloInvocations=log.read_text().splitlines().count('hello') if log.exists() else 0)
            record['cases'].append(result)
            if (result['outcome'] != expected or result['authenticated'] != (expected == 'authenticated')
                    or not result['closed'] or (calls is not None and result['helloInvocations'] != calls)
                    or (name == 'peer-exit' and not result['disconnected'])
                    or (mode == 'library' and result.get('disconnectCallbacks') != 1)):
                raise RuntimeError('Unexpected admission result: ' + name)
        record['status'] = 'passed-limited-sdk-probe'
except Exception as error:
    record['errorType'] = type(error).__name__
    record['error'] = str(error)[:500]
    if isinstance(error, subprocess.CalledProcessError):
        record['diagnostic'] = error.stderr[-3000:]
finally:
    record['finishedAt'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    output.write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(record))
raise SystemExit(0 if record['status'] == 'passed-limited-sdk-probe' else 1)
