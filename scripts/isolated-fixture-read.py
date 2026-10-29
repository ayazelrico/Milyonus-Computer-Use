#!/usr/bin/env python3
"""Explicit GUI acceptance for the packaged read-only worker route; approval stays native."""
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


def run(argv, timeout=60):
    return subprocess.run(argv, check=True, capture_output=True, text=True, timeout=timeout)


def pin(path):
    result = run(['codesign', '-dv', '--verbose=4', str(path)])
    return re.search(r'^CDHash=([0-9a-f]{40})$', result.stderr, re.M).group(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence', required=True)
    parser.add_argument('--prepare-only', action='store_true', help='Verify package and compile the client without launching native apps')
    parser.add_argument('--approval', action='store_true', help='Wait for actual native approval and verify three observations')
    parser.add_argument("--ax-stall-stop", action="store_true", help="Verify Stop during an actual fixture AX stall; requires native approval")
    parser.add_argument("--permission-revoke", action="store_true", help="Measure real permission denial and restoration without changing system settings automatically")
    args = parser.parse_args()
    if args.ax_stall_stop and args.permission_revoke:
        parser.error("Choose one interruption mode")
    args.approval = args.approval or args.ax_stall_stop or args.permission_revoke
    root = Path(__file__).resolve().parent.parent
    output = Path(args.evidence)
    progress = output.with_suffix('.progress.json')
    if output.exists() or progress.exists():
        raise SystemExit('Evidence already exists')
    record = {'suite': 'packaged-isolated-fixture-read', 'status': 'failed',
        'startedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'limitations': 'GUI acceptance; native approval is never automated. Development signatures; no mutation, capture or distribution acceptance.'}
    fixture = None
    try:
        run(['python3', str(root / 'scripts/package-dev.py'), '--verify-receipt'])
        if not args.prepare_only and subprocess.run(['pgrep', '-x', 'MilyonusComputerUse'], capture_output=True).returncode == 0:
            raise RuntimeError('Existing companion; no launch attempted')
        if not args.prepare_only and args.approval and subprocess.run(['pgrep', '-x', 'ComputerUseFixture'], capture_output=True).returncode == 0:
            raise RuntimeError('Existing fixture; no launch attempted')
        build = root / '.build/debug'
        companion = root / 'build/MilyonusComputerUse.app/Contents/MacOS/MilyonusComputerUse'
        fixture_binary = root / 'build/ComputerUseFixture.app/Contents/MacOS/ComputerUseFixture'
        record['companionSHA256'] = hashlib.sha256(companion.read_bytes()).hexdigest()
        record['fixtureSHA256'] = hashlib.sha256(fixture_binary.read_bytes()).hexdigest()
        with tempfile.TemporaryDirectory(prefix='milyonus-isolated-read-') as directory:
            folder = Path(directory)
            client = folder / 'IsolatedReadClient'
            source = root / 'Experiments/XPCPeerProbe/IsolatedReadClient.swift'
            objects = [p for module in ['ComputerUseIPC', 'ComputerUseClient', 'ComputerUseContracts']
                       for p in sorted((build / (module + '.build')).glob('*.swift.o'))]
            run(['swiftc', '-swift-version', '6', '-parse-as-library', '-I', str(build / 'Modules'),
                 str(source), *map(str, objects), '-o', str(client)])
            run(['codesign', '--force', '--sign', '-', str(client)])
            record['clientSourceSHA256'] = hashlib.sha256(source.read_bytes()).hexdigest()
            if args.prepare_only:
                record['status'] = 'prepared-without-native-launch'
            else:
                if args.approval:
                    fixture_args = [str(fixture_binary)]
                    trace = folder / 'ax-stall.ndjson'
                    if args.ax_stall_stop:
                        fixture_args += ['--ax-stall-on-signal', '--ax-stall-trace', str(trace)]
                    fixture = subprocess.Popen(fixture_args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    record['fixturePID'] = fixture.pid
                    if args.ax_stall_stop:
                        deadline = time.monotonic() + 5
                        while not trace.exists():
                            if fixture.poll() is not None or time.monotonic() >= deadline:
                                raise RuntimeError('Fixture trace did not become ready')
                            time.sleep(0.02)
                        record['thresholds'] = {'stopAcknowledgementMs': 250, 'workerExitSeconds': 2, 'fixtureStallSeconds': 5}
                label = 'com.milyonus.computeruse.isolated.' + uuid.uuid4().hex
                worker_service = label + '.read'
                domain = 'gui/' + str(os.getuid())
                job = folder / 'job.plist'
                job.write_bytes(plistlib.dumps({'Label': label,
                    'ProgramArguments': [str(companion), '--broker-development', label, pin(client),
                                         '--isolated-fixture-reads', worker_service],
                    'MachServices': {label: True, worker_service: True}, 'RunAtLoad': True,
                    'StandardOutPath': str(folder / 'stdout'), 'StandardErrorPath': str(folder / 'stderr')}))
                run(['launchctl', 'bootstrap', domain, str(job)])
                try:
                    deadline = time.monotonic() + 10
                    broker_pid = None
                    while time.monotonic() < deadline:
                        state = run(['launchctl', 'print', domain + '/' + label]).stdout
                        match = re.search(r'^\s*pid = (\d+)\s*$', state, re.M)
                        if match:
                            broker_pid = int(match.group(1)); break
                        time.sleep(0.05)
                    if broker_pid is None:
                        raise RuntimeError('Broker did not start')
                    record['brokerPID'] = broker_pid
                    mode = 'permission-revoke' if args.permission_revoke else 'stall-stop' if args.ax_stall_stop else 'approval' if args.approval else 'unapproved'
                    extra = [str(trace)] if args.ax_stall_stop else []
                    result = subprocess.run([str(client), label, pin(companion), str(fixture.pid if fixture else 0),
                        mode, str(progress.resolve()), str(broker_pid), *extra], capture_output=True, text=True, timeout=390 if args.permission_revoke else 140 if args.approval else 30)
                    record['result'] = json.loads(result.stdout)
                    expected = 'passed-isolated-permission-interruption' if args.permission_revoke else 'passed-isolated-ax-stop' if args.ax_stall_stop else 'passed-isolated-read' if args.approval else 'passed-unapproved-isolated-read'
                    if result.returncode != 0 or record['result'].get('status') != expected:
                        raise RuntimeError('Isolated read acceptance did not pass')
                finally:
                    try:
                        if args.ax_stall_stop and trace.exists():
                            with trace.open('rb') as stream:
                                data = stream.read(4097)
                            if len(data) > 4096:
                                raise RuntimeError('AX trace exceeded bound')
                            lines = data.split(b'\n')[:-1]
                            record['fixtureAXEvents'] = [json.loads(line) for line in lines]
                    finally:
                        run(['launchctl', 'bootout', domain + '/' + label])
                        record['temporaryJobRemoved'] = True
                record['status'] = expected
    except Exception as error:
        record['errorType'] = type(error).__name__
        record['error'] = str(error)[:300]
        if isinstance(error, subprocess.CalledProcessError):
            record['diagnostic'] = error.stderr[-2000:]
    finally:
        if fixture is not None and fixture.poll() is None:
            fixture.terminate()
            try:
                fixture.wait(timeout=5)
            except subprocess.TimeoutExpired:
                fixture.kill(); fixture.wait(timeout=5)
        record['finishedAt'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        output.write_text(json.dumps(record, indent=2) + '\n')
        print(json.dumps(record))
    return 0 if record['status'].startswith('passed-') or record['status'] == 'prepared-without-native-launch' else 1


if __name__ == '__main__':
    raise SystemExit(main())
