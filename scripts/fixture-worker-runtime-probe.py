#!/usr/bin/env python3
"""Run the actual self-pinned worker role with negative non-fixture targets only."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import time
import uuid


def run(argv, **kwargs):
    return subprocess.run(argv, check=True, capture_output=True, text=True, timeout=90, **kwargs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence', required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    output = Path(args.evidence)
    if output.exists():
        raise SystemExit('Evidence already exists')
    sources = ['Sources/ComputerUseWorker/FixtureWorkerRuntime.swift',
               'Sources/ComputerUseWorker/FixtureWorkerHost.swift',
               'Sources/ComputerUseMacOS/FixtureReadWorker.swift',
               'Tests/CoreTests/FixtureWorkerRuntimeTests.swift', 'Tests/main.swift']
    record = {'suite': 'fixture-worker-runtime', 'status': 'failed',
        'startedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'sourceSHA256': {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in sources},
        'limitations': 'Actual signed child role and codec/collector refusals only. The probe target is hardcoded to its own non-fixture process. No AX tree read, native grant, TCC change, GUI or successful fixture observation.'}
    try:
        run(['swift', 'build'], cwd=root)
        build = Path(run(['swift', 'build', '--show-bin-path'], cwd=root).stdout.strip())
        with tempfile.TemporaryDirectory(prefix='milyonus-worker-runtime-') as directory:
            folder = Path(directory)
            binary = folder / 'WorkerRuntimeProbe'
            shutil.copy2(build / 'computer-use-selftest', binary)
            run(['codesign', '--force', '--sign', '-', str(binary)])
            record['binarySHA256'] = hashlib.sha256(binary.read_bytes()).hexdigest()
            label = 'com.milyonus.computeruse.workerprobe.' + uuid.uuid4().hex
            service = label + '.read'
            domain = 'gui/' + str(os.getuid())
            log = folder / 'stdout'
            job = folder / 'job.plist'
            job.write_bytes(plistlib.dumps({'Label': label,
                'ProgramArguments': [str(binary), '--fixture-worker-host-probe', service],
                'MachServices': {service: True}, 'RunAtLoad': True,
                'StandardOutPath': str(log), 'StandardErrorPath': str(folder / 'stderr')}))
            loaded = False
            try:
                run(['launchctl', 'bootstrap', domain, str(job)])
                loaded = True
                deadline = time.monotonic() + 40
                result = None
                while time.monotonic() < deadline:
                    if log.exists():
                        text = log.read_text()
                        if len(text.encode()) > 8192:
                            raise RuntimeError('Oversized probe result')
                        try:
                            result = json.loads(text)
                        except json.JSONDecodeError:
                            pass
                        else:
                            break
                    time.sleep(0.025)
                if not isinstance(result, dict):
                    raise RuntimeError('No complete worker runtime result')
                record['result'] = result
            finally:
                if loaded:
                    run(['launchctl', 'bootout', domain + '/' + label])
                    record['temporaryJobRemoved'] = True
            expected = {'non-fixture': 'POLICY_DENIED', 'changed-start': 'STALE_OBSERVATION',
                        'explicit-window': 'UNSUPPORTED_CAPABILITY'}
            cases = result.get('cases', [])
            if (result.get('status') != 'passed-negative-worker-runtime' or len(cases) != 3
                or {c['name']: c['error'] for c in cases} != expected
                or not all(c.get('helperExited') for c in cases)
                or any(result.get(k) is not False for k in ['nativeSessionOpened', 'nativeApprovalCreated', 'axTreeRead'])):
                raise RuntimeError('Unexpected runtime result')
            record['status'] = 'passed-negative-worker-runtime'
    except Exception as error:
        record['errorType'] = type(error).__name__
        record['error'] = str(error)[:300]
        if isinstance(error, subprocess.CalledProcessError):
            record['diagnostic'] = error.stderr[-3000:]
    finally:
        record['finishedAt'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        output.write_text(json.dumps(record, indent=2) + '\n')
        print(json.dumps(record))
    return 0 if record['status'] == 'passed-negative-worker-runtime' else 1


if __name__ == '__main__':
    raise SystemExit(main())
