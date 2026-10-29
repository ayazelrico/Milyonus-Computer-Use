#!/usr/bin/env python3
"""Prepare or run local fixture-only capture checks; never request permission or upload pixels."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence', required=True)
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--case', choices=['absent', 'marker', 'ambiguous'], default='absent')
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    output = Path(args.evidence)
    if output.exists():
        raise SystemExit('Evidence already exists')
    record = {'suite': 'local-fixture-capture', 'case': args.case, 'status': 'failed',
              'limitations': 'Development child attribution; not installed companion, hostile timing, other display or production acceptance.'}
    fixture = None
    try:
        subprocess.run(['python3', str(root / 'scripts/package-dev.py'), '--verify-receipt'], check=True, capture_output=True, timeout=30)
        if not args.prepare_only:
            for name in ['ComputerUseFixture', 'MilyonusComputerUse']:
                if subprocess.run(['pgrep', '-x', name], capture_output=True).returncode == 0:
                    raise RuntimeError('Conflicting native process: ' + name)
        source = root / 'Experiments/CaptureProbe/CaptureClient.swift'
        record['clientSourceSHA256'] = hashlib.sha256(source.read_bytes()).hexdigest()
        with tempfile.TemporaryDirectory(prefix='milyonus-capture-probe-') as directory:
            client = Path(directory) / 'CaptureClient'
            build = root / '.build/debug'
            objects = [str(p) for module in ['ComputerUseMacOS', 'ComputerUseCore', 'ComputerUseContracts']
                       for p in sorted((build / (module + '.build')).glob('*.swift.o'))]
            subprocess.run(['swiftc', '-swift-version', '6', '-parse-as-library', '-I', str(build / 'Modules'),
                str(source), *objects, '-o', str(client)], check=True, capture_output=True, text=True, timeout=60)
            subprocess.run(['codesign', '--force', '--sign', '-', str(client)], check=True, capture_output=True, timeout=10)
            if args.prepare_only:
                record['status'] = 'prepared-without-native-launch'
            else:
                if args.case != 'absent':
                    binary = root / 'build/ComputerUseFixture.app/Contents/MacOS/ComputerUseFixture'
                    record['fixtureSHA256'] = hashlib.sha256(binary.read_bytes()).hexdigest()
                    fixture = subprocess.Popen([str(binary), '--capture-duplicate' if args.case == 'ambiguous' else '--capture-marker'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    record['ownedFixturePID'] = fixture.pid
                    time.sleep(1)
                    if fixture.poll() is not None:
                        raise RuntimeError('Owned fixture exited')
                result = subprocess.run([str(client), args.case], capture_output=True, text=True, timeout=30)
                record['result'] = json.loads(result.stdout)
                if result.returncode != 0:
                    raise RuntimeError('Native capture case did not pass')
                record['status'] = record['result']['status']
    except Exception as error:
        record['errorType'] = type(error).__name__
        record['error'] = str(error)[:300]
        if isinstance(error, subprocess.CalledProcessError):
            diagnostic = error.stderr or ''
            if isinstance(diagnostic, bytes):
                diagnostic = diagnostic.decode(errors='replace')
            record['diagnostic'] = diagnostic[-2000:]
    finally:
        if fixture is not None:
            if fixture.poll() is None:
                fixture.terminate()
                try:
                    fixture.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    fixture.kill(); fixture.wait(timeout=5)
            record['ownedFixtureExited'] = fixture.poll() is not None
        output.write_text(json.dumps(record, indent=2) + '\n')
        print(json.dumps(record))
    return 0 if record['status'].startswith(('passed-', 'prepared-')) else 1


if __name__ == '__main__':
    raise SystemExit(main())
