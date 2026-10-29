#!/usr/bin/env python3
"""Prove signature plus owned-process XPC admission without desktop APIs or grants."""
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


def run(argv, **kwargs):
    return subprocess.run(argv, check=True, capture_output=True, text=True, timeout=60, **kwargs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence', required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    output = Path(args.evidence)
    if output.exists():
        raise SystemExit('Evidence already exists')
    source = root / 'Experiments/XPCPeerProbe/OwnedWorkerPeer.swift'
    record = {'suite': 'owned-worker-xpc-peer', 'status': 'failed', 'cases': [],
              'startedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'sourceSHA256': hashlib.sha256(source.read_bytes()).hexdigest(),
              'runnerSHA256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'limitations': 'Development CDHash pins and owned-process admission only. Known metadata; no AX, native grants, TCC, production signing or companion integration.'}
    try:
        run(['swift', 'build'], cwd=root)
        build = Path(run(['swift', 'build', '--show-bin-path'], cwd=root).stdout.strip())
        objects = [p for module in ['ComputerUseIPC', 'ComputerUseCore', 'ComputerUseContracts']
                   for p in sorted((build / (module + '.build')).glob('*.swift.o'))]
        record['objects'] = {str(p.relative_to(build)): hashlib.sha256(p.read_bytes()).hexdigest() for p in objects}
        with tempfile.TemporaryDirectory(prefix='milyonus-owned-peer-') as folder_name:
            folder = Path(folder_name)
            binary = folder / 'OwnedWorkerPeer'
            run(['swiftc', '-swift-version', '6', '-package-name', 'milyonus_computer_use',
                 '-parse-as-library', '-I', str(build / 'Modules'), str(source),
                 *map(str, objects), '-o', str(binary)])
            run(['codesign', '--force', '--sign', '-', str(binary)])
            signature = run(['codesign', '-dv', '--verbose=4', str(binary)])
            match = re.search(r'^CDHash=([0-9a-f]{40})$', signature.stderr, re.M)
            if not match:
                raise RuntimeError('Missing development signature')
            pin = match.group(1)
            record['binarySHA256'] = hashlib.sha256(binary.read_bytes()).hexdigest()
            for mode in ['matching-owned-child', 'same-signature-sibling', 'wrong-client-signature',
                         'wrong-server-signature', 'wrong-server-pid']:
                case_folder = folder / mode
                case_folder.mkdir(mode=0o700)
                label = 'com.milyonus.computeruse.ownedpeer.' + uuid.uuid4().hex
                domain = 'gui/' + str(os.getuid())
                job = case_folder / 'job.plist'
                log = case_folder / 'server.stdout'
                job.write_bytes(plistlib.dumps({'Label': label,
                    'ProgramArguments': [str(binary), '--server', label, pin, mode, str(case_folder)],
                    'MachServices': {label: True}, 'RunAtLoad': True,
                    'StandardOutPath': str(log), 'StandardErrorPath': str(case_folder / 'server.stderr')}))
                loaded = False
                try:
                    run(['launchctl', 'bootstrap', domain, str(job)])
                    loaded = True
                    deadline = time.monotonic() + 20
                    result = None
                    while time.monotonic() < deadline:
                        if log.exists():
                            text = log.read_text()
                            if len(text.encode()) > 4096:
                                raise RuntimeError('Oversized probe result')
                            try:
                                result = json.loads(text)
                            except json.JSONDecodeError:
                                pass
                            else:
                                break
                        time.sleep(0.025)
                    if not isinstance(result, dict):
                        raise RuntimeError('No complete bounded probe result')
                finally:
                    if loaded:
                        run(['launchctl', 'bootout', domain + '/' + label])
                result.update(name=mode, temporaryJobRemoved=True)
                record['cases'].append(result)
                expected = mode in ['matching-owned-child', 'same-signature-sibling']
                if (result.get('outcome') != ('authenticated' if expected else 'authenticationFailed')
                    or result.get('authenticatedBeforeRequest') != expected
                    or result.get('metadataVerified') != expected
                    or result.get('postHandshakeInvocations') != int(expected)
                    or not result.get('ownedChildExited') or not result.get('ownerAdmissionRetired')
                    or (mode == 'same-signature-sibling' and not result.get('siblingRefused'))):
                    raise RuntimeError('Unexpected owned-peer result: ' + mode)
            record['status'] = 'passed-limited-owned-peer'
    except Exception as error:
        record['errorType'] = type(error).__name__
        record['error'] = str(error)[:250]
        if isinstance(error, subprocess.CalledProcessError):
            record['diagnostic'] = error.stderr[-3000:]
    finally:
        record['finishedAt'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        output.write_text(json.dumps(record, indent=2) + '\n')
        print(json.dumps(record))
    return 0 if record['status'] == 'passed-limited-owned-peer' else 1


if __name__ == '__main__':
    raise SystemExit(main())
