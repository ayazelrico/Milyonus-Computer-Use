#!/usr/bin/env python3
"""Check the AX-stall trace admission without opening a window or installing signals."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import uuid


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence', required=True)
    parser.add_argument('--configuration', choices=['debug', 'release'], default='debug')
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    output = Path(args.evidence)
    if output.exists():
        raise SystemExit('Evidence already exists')
    record = {'suite': 'ax-stall-trace-admission', 'status': 'failed', 'cases': [],
              'configuration': args.configuration, 'startedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'limitations': 'File-admission probes only; no UI, AX call, signal, native grant or blocked-call Stop acceptance.'}
    try:
        subprocess.run(['swift', 'build', '-c', args.configuration], cwd=root, check=True, capture_output=True, timeout=120)
        build = Path(subprocess.check_output(['swift', 'build', '-c', args.configuration, '--show-bin-path'], cwd=root, text=True).strip())
        binary = build / 'ComputerUseFixture'
        record['binarySHA256'] = hashlib.sha256(binary.read_bytes()).hexdigest()

        def probe(name, path, expected):
            run = subprocess.run([str(binary), '--validate-ax-stall-trace', '--ax-stall-on-signal',
                '--ax-stall-trace', str(path)], capture_output=True, text=True, timeout=5)
            result = json.loads(run.stdout)
            passed = result.get('traceAvailable') is expected and result.get('uiLaunched') is False and run.returncode == (0 if expected else 1)
            record['cases'].append({'name': name, 'passed': passed, 'traceAvailable': result.get('traceAvailable'), 'uiLaunched': result.get('uiLaunched')})
            if not passed:
                raise RuntimeError('Unexpected trace admission: ' + name)

        with tempfile.TemporaryDirectory(prefix='milyonus-isolated-read-') as folder:
            parent = Path(folder)
            path = parent / 'ax-stall.ndjson'
            probe('valid-private-parent', path, True)
            original = path.read_bytes()
            events = [json.loads(line) for line in original.splitlines()]
            if (path.stat().st_mode & 0o777 != 0o600 or path.stat().st_uid != os.getuid()
                or len(events) != 1 or events[0].get('event') != 'ready'):
                raise RuntimeError('Invalid ready trace')
            probe('existing-leaf-refused', path, False)
            if path.read_bytes() != original:
                raise RuntimeError('Existing trace modified')
            probe('wrong-leaf-refused', parent / 'other.ndjson', False)
            if (parent / 'other.ndjson').exists():
                raise RuntimeError('Unexpected trace created')
            nested = parent / 'milyonus-isolated-read-nested'
            nested.mkdir(mode=0o700)
            probe('outside-immediate-temp-root-refused', nested / 'ax-stall.ndjson', False)
            alias = Path(tempfile.gettempdir()) / ('milyonus-isolated-read-' + uuid.uuid4().hex)
            alias.symlink_to(parent, target_is_directory=True)
            try:
                probe('symlink-parent-refused', alias / 'ax-stall.ndjson', False)
            finally:
                alias.unlink()
        with tempfile.TemporaryDirectory(prefix='milyonus-isolated-read-') as folder:
            parent = Path(folder)
            target = parent / 'untouched'
            target.write_text('synthetic-disposable-content')
            (parent / 'ax-stall.ndjson').symlink_to(target)
            probe('symlink-leaf-refused', parent / 'ax-stall.ndjson', False)
            if target.read_text() != 'synthetic-disposable-content':
                raise RuntimeError('Symlink target modified')
        with tempfile.TemporaryDirectory(prefix='milyonus-isolated-read-') as folder:
            parent = Path(folder)
            parent.chmod(0o755)
            probe('non-private-parent-refused', parent / 'ax-stall.ndjson', False)
            if (parent / 'ax-stall.ndjson').exists():
                raise RuntimeError('Trace created in non-private parent')
        record['status'] = 'passed-trace-admission'
    except Exception as error:
        record['errorType'] = type(error).__name__
        record['error'] = str(error)[:300]
        if isinstance(error, subprocess.CalledProcessError):
            record['diagnostic'] = (error.stderr or b'').decode(errors='replace')[-2000:] if isinstance(error.stderr, bytes) else (error.stderr or '')[-2000:]
    finally:
        record['finishedAt'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        output.write_text(json.dumps(record, indent=2) + '\n')
        print(json.dumps(record))
    return 0 if record['status'] == 'passed-trace-admission' else 1


if __name__ == '__main__':
    raise SystemExit(main())
